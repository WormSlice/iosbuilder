import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../services/signaling_service.dart';

class CallScreen extends StatefulWidget {
  final String channelId;
  final String peerName;
  final String? peerAvatar;
  final String? callId;
  final bool isVideoCall;

  const CallScreen({
    super.key,
    required this.channelId,
    required this.peerName,
    this.peerAvatar,
    this.callId,
    this.isVideoCall = true,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final SignalingService _signaling = SignalingService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isVideoOn = false;
  bool _isRemoteConnected = false;

  StreamSubscription? _statusSubscription;
  Timer? _durationTimer;
  Timer? _ringbackTimer;
  int _secondsElapsed = 0;

  bool _isRecordingCall = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentRecordingPath;

  // Diagnostic
  String _statusMessage = "Iniciando WebRTC...";

  bool _isMinimizing = true; // Por defecto si se retrocede es minimizar.

  @override
  void initState() {
    super.initState();
    if (_signaling.isCallActive && _signaling.activeCallId == widget.callId) {
      // Restore state
      _isVideoOn = _signaling.isVideoOn;
      _isSpeaker = _signaling.isSpeaker;
      _isMuted = _signaling.isMuted;
      _isRemoteConnected = _signaling.isRemoteConnected;
      _secondsElapsed = _signaling.secondsElapsed;
      _statusMessage = _signaling.statusMessage;

      if (_isRemoteConnected) {
        _startDurationTimer();
      }
    } else {
      // New call
      _signaling.reset();
      _signaling.localRenderer = _localRenderer;
      _signaling.remoteRenderer = _remoteRenderer;
      _signaling.isCallActive = true;
      _signaling.activeCallId = widget.callId;

      _initRenderers();
      _startCall();
    }
    _listenToCallStatus();
  }

  @override
  void dispose() {
    if (!_isMinimizing) {
      _localRenderer.dispose();
      _remoteRenderer.dispose();
      _signaling.hangUp(_localRenderer);
      _signaling.reset();
    } else {
      // Save state
      _signaling.isVideoOn = _isVideoOn;
      _signaling.isSpeaker = _isSpeaker;
      _signaling.isMuted = _isMuted;
      _signaling.isRemoteConnected = _isRemoteConnected;
      _signaling.secondsElapsed = _secondsElapsed;
      _signaling.statusMessage = _statusMessage;
    }

    _statusSubscription?.cancel();
    _durationTimer?.cancel();
    _ringbackTimer?.cancel();
    _stopSounds();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  void _startCall() async {
    try {
      await [Permission.microphone, Permission.camera].request();

      final callDoc = await FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.callId)
          .get();

      if (!callDoc.exists) return;
      final data = callDoc.data()!;

      bool isVideoCallData = data['isVideoCall'] ?? widget.isVideoCall;

      if (mounted) {
        setState(() {
          _isVideoOn = isVideoCallData;
          _isSpeaker = isVideoCallData;
        });
      }

      final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      await _signaling.openUserMedia(
        _localRenderer,
        _remoteRenderer,
        isVideoCall: isVideoCallData,
      );

      // Removed explicit _playCallingSounds here as the listener handles it for both parties

      if (data['callerId'] == currentUid) {
        setState(() => _statusMessage = "Creando sala...");
        await _signaling.createRoom(_remoteRenderer, widget.callId!);
        setState(() => _statusMessage = "Llamando...");
      } else {
        setState(() => _statusMessage = "Uniéndose...");
        await _signaling.joinRoom(widget.callId!, _remoteRenderer);
      }

      // Detect connection
      _signaling.peerConnection?.onConnectionState = (state) {
        print('DEBUG: [CallScreen] WebRTC Connection State: ${state.name}');
        setState(() => _statusMessage = "Conexión: ${state.name}");
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _onConnected();
        }
      };

      // Many mobile clients stay in "Connecting" state for the parent connection
      // but the ICE connection indeed becomes connected. Let's rely on it as well.
      _signaling.peerConnection?.onIceConnectionState = (state) {
        print('DEBUG: [CallScreen] WebRTC ICE Connection State: ${state.name}');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          _onConnected();
        }
      };
    } catch (e) {
      setState(() => _statusMessage = "Error: $e");
    }
  }

  void _onConnected() {
    if (mounted) {
      setState(() {
        _isRemoteConnected = true;
        _startDurationTimer();
        _statusMessage = "En llamada";
      });
      _stopSounds();
      _updateCallStatus('in_call');

      // Force the speakerphone configuration correctly based on the call type!
      Helper.setSpeakerphoneOn(_isSpeaker);
    }
  }

  void _listenToCallStatus() {
    print('DEBUG: [CallScreen] Listening to call status for ${widget.callId}');
    _statusSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((doc) async {
          if (!doc.exists) {
            print('DEBUG: [CallScreen] Call document deleted, finishing call');
            _endCallLocally();
            return;
          }
          final data = doc.data()!;
          final status = data['status'];
          print('DEBUG: [CallScreen] Status Change: $status');

          switch (status) {
            case 'calling':
            case 'ringing':
              _playCallingSounds(
                data['callerId'] == FirebaseAuth.instance.currentUser?.uid,
              );
              break;
            case 'accepted':
              _stopSounds();
              setState(() => _statusMessage = "Aceptada, conectando...");
              // If receiver, join room is already called in _startCall,
              // but we can ensure it here if it hasn't started.
              break;
            case 'in_call':
              if (!_isRemoteConnected) {
                _onConnected();
              }
              break;
            case 'declined':
            case 'finished':
            case 'ended':
            case 'rejected':
              _endCallLocally();
              break;
          }
        });
  }

  void _endCallLocally() async {
    if (mounted) {
      if (_isRecordingCall) {
        await _audioRecorder.stop();
        _isRecordingCall = false;
      }
      _isMinimizing = false;
      _stopSounds();
      Navigator.pop(context);
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  String _formatDuration(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _playCallingSounds(bool isCaller) {
    _stopSounds(); // Ensure no double sounds
    if (isCaller) {
      print('DEBUG: [CallScreen] Playing dial tone (caller)');
      // Simular un ringback tone (tono de marcado) que suena una vez cada X segundos, no en bucle infinito
      FlutterRingtonePlayer().play(
        android: AndroidSounds.notification,
        ios: IosSounds.glass,
      );
      _ringbackTimer?.cancel();
      _ringbackTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        FlutterRingtonePlayer().play(
          android: AndroidSounds.notification,
          ios: IosSounds.glass,
        );
      });
    } else {
      // For receiver, the ringtone is already handled by CallManager,
      print(
        'DEBUG: [CallScreen] Ringtone for receiver should be playing via CallManager',
      );
    }
  }

  void _stopSounds() {
    _ringbackTimer?.cancel();
    FlutterRingtonePlayer().stop();
  }

  void _updateCallStatus(String status) async {
    await FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .update({'status': status});
  }

  // CONTROLS
  void _toggleMute() {
    _isMuted = !_isMuted;
    _signaling.localStream?.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });
    setState(() {});
  }

  void _toggleVideo() {
    _isVideoOn = !_isVideoOn;
    _signaling.localStream?.getVideoTracks().forEach((track) {
      track.enabled = _isVideoOn;
    });
    setState(() {});
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeaker = !_isSpeaker;
    });
    print('DEBUG: [CallScreen] Setting speakerphone: $_isSpeaker');
    Helper.setSpeakerphoneOn(_isSpeaker);
  }

  void _switchCamera() async {
    final track = _signaling.localStream?.getVideoTracks().first;
    if (track != null) {
      bool result = await Helper.switchCamera(track);
      print('DEBUG: [CallScreen] Switched camera: $result');
    }
  }

  Future<void> _toggleRecordCall() async {
    if (_isRecordingCall) {
      final path = await _audioRecorder.stop();
      setState(() => _isRecordingCall = false);
      if (path != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Guardado en el panel del chat (Audios locales).'),
            ),
          );
        }
      }
    } else {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) return;

      try {
        final dir = await getApplicationDocumentsDirectory();
        final chatDir = Directory(
          '${dir.path}/connect_calls/${widget.channelId}',
        );
        if (!await chatDir.exists()) {
          await chatDir.create(recursive: true);
        }

        final fileName = 'Llamada_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _currentRecordingPath = '${chatDir.path}/$fileName';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _currentRecordingPath!,
        );

        setState(() => _isRecordingCall = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Grabando llamada interna...')),
          );
        }
      } catch (e) {
        print('Error grabando llamada: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote Video (if any) or Avatar
          Center(
            child: _isVideoOn
                ? RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : _buildStaticUI(),
          ),

          // Local Preview (small)
          if (_isVideoOn)
            Positioned(
              right: 20,
              top: 50,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: RTCVideoView(_localRenderer, mirror: true),
              ),
            ),

          // Botón Minimizar arriba a la izquierda
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () {
                _isMinimizing = true;
                Navigator.pop(context);
              },
            ),
          ),

          // Diagnostic
          Positioned(
            top: 45,
            left: 50,
            child: Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ),

          // Bottom Controls
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildStaticUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 60,
          backgroundImage:
              (widget.peerAvatar != null && widget.peerAvatar!.isNotEmpty)
              ? CachedNetworkImageProvider(widget.peerAvatar!)
              : null,
          child: (widget.peerAvatar == null || widget.peerAvatar!.isEmpty)
              ? const Icon(Icons.person, size: 60, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 20),
        Text(
          widget.peerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isRemoteConnected ? _formatDuration(_secondsElapsed) : "Marcando...",
          style: TextStyle(
            color: _isRemoteConnected ? Colors.greenAccent : Colors.white54,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.only(bottom: 40, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row of secondary controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _controlBtn(Icons.mic_off, _isMuted, _toggleMute),
                _controlBtn(Icons.videocam, _isVideoOn, _toggleVideo),
                _controlBtn(Icons.flip_camera_ios, false, _switchCamera),
                _controlBtn(Icons.volume_up, _isSpeaker, _toggleSpeaker),
                _controlBtn(
                  Icons.fiber_manual_record,
                  _isRecordingCall,
                  _toggleRecordCall,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 30),
            // End call button
            GestureDetector(
              onTap: () async {
                await _signaling.updateCallStatus(widget.callId!, 'ended');
                _endCallLocally();
              },
              child: Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.call_end,
                  color: Colors.white,
                  size: 35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlBtn(
    IconData icon,
    bool active,
    VoidCallback onTap, {
    Color? color,
  }) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: active ? (color ?? Colors.blue) : Colors.white10,
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onTap,
          ),
        ),
      ],
    );
  }
}
