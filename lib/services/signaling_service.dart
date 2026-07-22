import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef StreamStateCallback = void Function(MediaStream stream);

class SignalingService {
  static final SignalingService _instance = SignalingService._internal();

  factory SignalingService() {
    return _instance;
  }

  SignalingService._internal();

  Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ],
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? roomId;
  String? currentUserId;
  bool isCallActive = false;
  String? activeCallId;

  RTCVideoRenderer? localRenderer;
  RTCVideoRenderer? remoteRenderer;

  bool isMuted = false;
  bool isSpeaker = false;
  bool isVideoOn = false;
  bool isRemoteConnected = false;
  int secondsElapsed = 0;
  String statusMessage = "Iniciando WebRTC...";

  // Buffer for remote ICE candidates that arrive before RemoteDescription is set
  final List<RTCIceCandidate> _remoteIceBuffer = [];
  bool _isRemoteDescriptionSet = false;

  Future<String> createRoom(
    RTCVideoRenderer remoteRenderer,
    String callId,
  ) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('calls').doc(callId);

    print('Create PeerConnection with configuration: $configuration');

    peerConnection = await createPeerConnection(configuration);

    registerPeerConnectionListeners();

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });

    // Code for collecting ICE candidates below
    var callerCandidatesCollection = roomRef.collection('callerCandidates');

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      print('Got candidate: ${candidate.toMap()}');
      callerCandidatesCollection.add(candidate.toMap());
    };
    // Finish Code for collecting ICE candidates

    // Add code for creating a room
    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);
    print('Created offer: $offer');

    Map<String, dynamic> roomWithOffer = {'offer': offer.toMap()};

    await roomRef.set(roomWithOffer, SetOptions(merge: true));
    roomId = roomRef.id;
    print(
      'DEBUG: [SignalingService] New room created with SDK offer. Room ID: $roomId',
    );
    // Finished creating a room

    peerConnection?.onTrack = (RTCTrackEvent event) {
      print('Got remote track: ${event.streams[0]}');
      event.streams[0].getTracks().forEach((track) {
        print('Add a track to the remoteStream: $track');
        remoteStream?.addTrack(track);
      });
      remoteRenderer.srcObject = event.streams[0];
    };

    // Listening for remote session description below
    roomRef.snapshots().listen((snapshot) async {
      print('DEBUG: [WebRTC] Room snapshot received');
      if (!snapshot.exists || snapshot.data() == null) {
        print('DEBUG: [WebRTC] Room does not exist or data is null');
        return;
      }

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      // BUG FIX: getRemoteDescription() returns a Future, so comparing it to null is always false!
      // Therefore, the caller NEVER processed the answer!
      if (!_isRemoteDescriptionSet && data['answer'] != null) {
        var answer = RTCSessionDescription(
          data['answer']['sdp'],
          data['answer']['type'],
        );

        print("DEBUG: [WebRTC] Updating remote description with answer.");
        await peerConnection?.setRemoteDescription(answer);
        _isRemoteDescriptionSet = true;
        _processIceBuffer();
      }
    });
    // Finished listening for remote session description

    // Listen for remote Ice candidates below
    roomRef.collection('receiverCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          Map<String, dynamic> data = change.doc.data() as Map<String, dynamic>;
          print(
            'DEBUG: [WebRTC] Got new receiver ICE candidate: ${json.encode(data)}',
          );
          var candidate = RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          );

          if (_isRemoteDescriptionSet) {
            peerConnection!.addCandidate(candidate);
          } else {
            print('DEBUG: [WebRTC] Buffering receiver ICE candidate');
            _remoteIceBuffer.add(candidate);
          }
        }
      }
    });
    // Finished listening for remote ICE candidates

    return roomId!;
  }

  Future<void> updateCallStatus(String callId, String status) async {
    print('DEBUG: [SignalingService] Updating status for $callId to $status');
    await FirebaseFirestore.instance.collection('calls').doc(callId).update({
      'status': status,
    });
  }

  Future<void> joinRoom(String callId, RTCVideoRenderer remoteRenderer) async {
    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentReference roomRef = db.collection('calls').doc(callId);
    var roomSnapshot = await roomRef.get();
    print('Got room ${roomSnapshot.exists}');

    if (roomSnapshot.exists) {
      print('Create PeerConnection with configuration: $configuration');
      peerConnection = await createPeerConnection(configuration);

      registerPeerConnectionListeners();

      localStream?.getTracks().forEach((track) {
        peerConnection?.addTrack(track, localStream!);
      });

      // Code for collecting ICE candidates below
      var receiverCandidatesCollection = roomRef.collection(
        'receiverCandidates',
      );
      peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
        print(
          'DEBUG: [SignalingService] Got receiver candidate: ${candidate.toMap()}',
        );
        receiverCandidatesCollection.add(candidate.toMap());
      };
      // Finished collecting ICE candidates

      peerConnection?.onTrack = (RTCTrackEvent event) {
        print('Got remote track: ${event.streams[0]}');
        event.streams[0].getTracks().forEach((track) {
          print('Add a track to the remoteStream: $track');
          remoteStream?.addTrack(track);
        });
        remoteRenderer.srcObject = event.streams[0];
      };

      // Code for creating SDP answer below
      var data = roomSnapshot.data() as Map<String, dynamic>;
      print('Got offer $data');
      var offer = data['offer'];
      await peerConnection?.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );
      var answer = await peerConnection!.createAnswer();
      print('Created Answer $answer');

      await peerConnection!.setLocalDescription(answer);

      Map<String, dynamic> roomWithAnswer = {'answer': answer.toMap()};

      await roomRef.update(roomWithAnswer);
      _isRemoteDescriptionSet = true;
      _processIceBuffer();
      // Finished creating SDP answer

      // Listening for remote ICE candidates below
      roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            var data = change.doc.data() as Map<String, dynamic>;
            print('DEBUG: [WebRTC] Got new caller ICE candidate: $data');
            var candidate = RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            );

            if (_isRemoteDescriptionSet) {
              peerConnection!.addCandidate(candidate);
            } else {
              print('DEBUG: [WebRTC] Buffering caller ICE candidate');
              _remoteIceBuffer.add(candidate);
            }
          }
        }
      });
    }
  }

  Future<void> openUserMedia(
    RTCVideoRenderer localVideo,
    RTCVideoRenderer remoteVideo, {
    bool isVideoCall = true,
  }) async {
    var stream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'googHighpassFilter': false, // Reduces processing filtering delay
        'googTypingNoiseDetection': false,
      },
      'video': isVideoCall,
    });

    localVideo.srcObject = stream;
    localStream = stream;

    remoteVideo.srcObject = await createLocalMediaStream('key');
  }

  void _processIceBuffer() {
    if (_remoteIceBuffer.isNotEmpty) {
      print(
        'DEBUG: [WebRTC] Processing buffered ICE candidates: ${_remoteIceBuffer.length}',
      );
      for (var candidate in _remoteIceBuffer) {
        peerConnection?.addCandidate(candidate);
      }
      _remoteIceBuffer.clear();
    }
  }

  Future<void> hangUp(RTCVideoRenderer localVideo) async {
    List<MediaStreamTrack> tracks = localVideo.srcObject?.getTracks() ?? [];
    for (var track in tracks) {
      track.stop();
    }

    if (remoteStream != null) {
      remoteStream!.getTracks().forEach((track) => track.stop());
    }
    if (peerConnection != null) {
      peerConnection!.close();
    }

    if (roomId != null) {
      var db = FirebaseFirestore.instance;
      var roomRef = db.collection('calls').doc(roomId);
      var calleeCandidates = await roomRef.collection('calleeCandidates').get();
      for (var document in calleeCandidates.docs) {
        document.reference.delete();
      }

      var callerCandidates = await roomRef.collection('callerCandidates').get();
      for (var document in callerCandidates.docs) {
        document.reference.delete();
      }

      await roomRef.delete();
    }

    localStream?.dispose();
    remoteStream?.dispose();
    peerConnection?.dispose();

    reset();
  }

  void reset() {
    peerConnection = null;
    localStream = null;
    remoteStream = null;
    roomId = null;
    currentUserId = null;
    _remoteIceBuffer.clear();
    _isRemoteDescriptionSet = false;
    isCallActive = false;
    activeCallId = null;
    localRenderer = null;
    remoteRenderer = null;
    isMuted = false;
    isSpeaker = false;
    isVideoOn = false;
    isRemoteConnected = false;
    secondsElapsed = 0;
    statusMessage = "Iniciando WebRTC...";
  }

  void registerPeerConnectionListeners() {
    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      print('ICE gathering state changed: $state');
    };

    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      print('Connection state changed: $state');
    };

    peerConnection?.onSignalingState = (RTCSignalingState state) {
      print('Signaling state changed: $state');
    };

    peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      print('ICE connection state changed: $state');
    };

    peerConnection?.onAddStream = (MediaStream stream) {
      print("Add remote stream");
      remoteStream = stream;
    };
  }
}
