import 'package:flutter/material.dart';
import 'screens/home/home_screen.dart';
import 'screens/wants/wants_screen.dart';
import 'screens/chats/chats_screen.dart';
import 'screens/post/post_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/verification_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/settings/security_screen.dart';
import 'screens/settings/notifications_settings_screen.dart';
import 'screens/auth/two_factor_method_screen.dart';
import 'screens/settings/location_settings_screen.dart';
import 'screens/settings/connected_devices_screen.dart';
import 'screens/activity/activity_center_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/chat_filter_service.dart';
import 'package:provider/provider.dart';
import 'package:overlay_support/overlay_support.dart';
import 'services/call_manager.dart';
import 'widgets/circular_reveal_animation.dart';
import 'widgets/boost_prompt.dart';
import 'dart:async';
import 'services/local_notification_service.dart';
import 'services/boost_service.dart';
import 'services/deep_link_service.dart';
import 'screens/post/boost_configuration_screen.dart';
import 'services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class App extends StatelessWidget {
  const App({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatFilterService()),
        ChangeNotifierProvider(create: (_) => BoostService()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, lang, child) {
          return OverlaySupport.global(
            child: MaterialApp(
              navigatorKey: navigatorKey,
              title: 'CONNECT',
              debugShowCheckedModeBanner: false,
              locale: lang.currentLocale,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                useMaterial3: true,
                fontFamily: 'Poppins',
                scaffoldBackgroundColor: Colors.white,
                navigationBarTheme: NavigationBarThemeData(
                  height: 48,
                  indicatorColor: Colors.transparent,
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return TextStyle(
                      fontSize: 12,
                      color: selected ? const Color(0xFF1E88E5) : Colors.black54,
                    );
                  }),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    final selected = states.contains(WidgetState.selected);
                    return IconThemeData(
                      size: 26,
                      color: selected ? const Color(0xFF1E88E5) : Colors.black54,
                    );
                  }),
                  backgroundColor: const Color(0xFFF6F6F6),
                ),
              ),
              home: const AuthGate(),
              routes: {
                '/login': (context) => const LoginScreen(),
                '/register': (context) => const RegisterScreen(),
                '/search': (context) => const SearchScreen(),
                '/edit_profile': (context) => const EditProfileScreen(),
                '/security': (context) => const SecurityScreen(),
                '/notifications_settings': (context) =>
                    const NotificationsSettingsScreen(),
                '/location_settings': (context) => const LocationSettingsScreen(),
                '/connected_devices': (context) => const ConnectedDevicesScreen(),
                '/activity': (context) => const ActivityCenterScreen(),
              },
            ),
          );
        },
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  final bool initial2faVerified;
  const AuthGate({super.key, this.initial2faVerified = false});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late bool _is2faVerified;

  @override
  void initState() {
    super.initState();
    _is2faVerified = widget.initial2faVerified;
  }

  Future<bool> _isLocallyVerified(String uid) async {
    if (_is2faVerified) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('2fa_verified_$uid') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          final user = snapshot.data!;
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
                final data = userSnapshot.data!.data() as Map<String, dynamic>;
                final is2faEnabled = data['twoFactorEnabled'] == true;

                if (is2faEnabled && !_is2faVerified) {
                  return FutureBuilder<bool>(
                    future: _isLocallyVerified(user.uid),
                    builder: (context, localSnap) {
                      if (localSnap.connectionState == ConnectionState.waiting) {
                        return const Scaffold(
                          backgroundColor: Colors.black,
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (localSnap.data == true) {
                        // Ya verificado localmente
                        return const AppShell();
                      }
                      return TwoFactorMethodScreen(user: user);
                    },
                  );
                }
              }

              final uid = user.uid;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Provider.of<ChatFilterService>(context, listen: false).init(uid);
              });
              return const AppShell();
            },
          );
        }
        
        if (_is2faVerified) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _is2faVerified = false);
          });
        }
        return const LoginScreen();
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  bool showPublishPanel = false;
  bool _isVerified = false;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _userSubscription;
  final DateTime _startTime = DateTime.now();

  final List<GlobalKey<NavigatorState>> _navKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    _setupNotificationListener();
    _listenToUserVerification();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CallManager().init(context);
      DeepLinkService().init(context);
    });
    pages = [
      _TabNavigator(root: const HomeScreen(), navKey: _navKeys[0]),
      _TabNavigator(root: const WantsScreen(), navKey: _navKeys[1]),
      const SizedBox.shrink(),
      _TabNavigator(root: const ChatsScreen(), navKey: _navKeys[3]),
      _TabNavigator(root: const ProfileScreen(), navKey: _navKeys[4]),
    ];
  }

  void _listenToUserVerification() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data() as Map<String, dynamic>;
              if (mounted) {
                setState(() {
                  _isVerified = data['isVerified'] == true;
                });
              }
            }
          });
    }
  }

  void _setupNotificationListener() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _notificationSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots()
          .listen((snapshot) {
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final data = change.doc.data() as Map<String, dynamic>;
                final createdAt = data['createdAt'] as Timestamp?;
                // Only notify for items created AFTER app start to avoid spam
                if (createdAt != null &&
                    createdAt.toDate().isAfter(_startTime)) {
                  LocalNotificationService.showNotification(
                    title: data['title'] ?? 'Nueva notificación',
                    body: data['body'] ?? 'Tienes un nuevo mensaje',
                  );
                }
              }
            }
          });
    }
  }

  void _showUnverifiedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cuenta no verificada'),
        content: const Text(
          'Para acceder a esta función, necesitas verificar tu cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthGate()),
                (route) => false,
              );
            },
            child: const Text(
              'CERRAR SESIÓN',
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VerificationScreen()),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text(
              'IR A VERIFICAR',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _userSubscription?.cancel();
    CallManager().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context);
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: index, children: pages),
          if (showPublishPanel) ...[
            // Full screen overlay including navigation bar
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => showPublishPanel = false),
                child: Container(
                  color: Colors.black.withOpacity(0.6), // Slightly darker
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: 12,
                ), // Fixed above nav bar
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutQuart,
                  builder: (context, fraction, child) {
                    return ClipPath(
                      clipper: CircularRevealClipper(
                        fraction: fraction,
                        center: null, // Defaults to bottom center
                      ),
                      child: child,
                    );
                  },
                  child: PublicationPanel(
                    onSuccess: (imageUrl, postId) {
                      setState(() => showPublishPanel = false);
                      if (imageUrl != null && postId != null) {
                        Provider.of<BoostService>(
                          context,
                          listen: false,
                        ).show(imageUrl: imageUrl, postId: postId);
                        index = 0; // Go to Home
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
          Consumer<BoostService>(
            builder: (context, boost, _) {
              if (!boost.showPrompt || boost.imageUrl == null) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: 0,
                right: 0,
                bottom: 80,
                child: BoostPrompt(
                  imageUrl: boost.imageUrl!,
                  onBoost: () {
                    final pId = boost.postId ?? 'placeholder_id';
                    final iUrl = boost.imageUrl!;
                    boost.hide();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BoostConfigurationScreen(
                          imageUrl: iUrl,
                          postId: pId,
                        ),
                      ),
                    );
                  },
                  onClose: () => boost.hide(),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: [
          NavigationDestination(
            icon: const _NavImage('imgenes/inicio.png', size: 44),
            label: lang.translate('inicio'),
          ),
          NavigationDestination(
            icon: const _NavImage('imgenes/lo tienes.png', size: 48),
            label: lang.translate('lo_tienes'),
          ),
          NavigationDestination(
            icon: const _NavImage('imgenes/publicar.png', size: 48),
            label: lang.translate('publicar'),
          ),
          NavigationDestination(
            icon: const _NavImage('imgenes/chats.png', size: 38),
            label: lang.translate('chats'),
          ),
          NavigationDestination(icon: const _ProfileNavIcon(size: 28), label: lang.translate('perfil')),
        ],
        onDestinationSelected: (i) {
          if (i == 2 || i == 4) {
            if (!_isVerified) {
              _showUnverifiedDialog();
              return;
            }
          }
          if (i == 2) {
            setState(() => showPublishPanel = true);
            return;
          }
          if (index == i) {
            _navKeys[i].currentState?.popUntil((r) => r.isFirst);
          } else {
            setState(() => index = i);
          }
        },
      ),
    );
  }
}

class _NavImage extends StatelessWidget {
  final String path;
  final double size;
  const _NavImage(this.path, {this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Image.asset(path, width: size, height: size, fit: BoxFit.contain);
  }
}

class _ProfileNavIcon extends StatelessWidget {
  final double size;
  const _ProfileNavIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return SizedBox(width: size, height: size);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snap) {
        String? url;
        if (snap.hasError) {
          debugPrint(
            'DEBUG: Firestore Auth Error for ${user.uid}: ${snap.error}',
          );
        }
        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data() as Map<String, dynamic>;
          url =
              data['photoURL'] ??
              data['photoUrl'] ??
              data['image'] ??
              data['avatar'] ??
              data['profilePic'] ??
              data['imageUrl'] ??
              data['photo'] ??
              data['foto'];
          debugPrint('DEBUG: URL from Firestore for ${user.uid}: $url');
        }
        url ??= user.photoURL;
        if (url != null) debugPrint('DEBUG: Final URL for NavIcon: $url');

        return ClipOval(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: (url != null && url.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: url,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Icon(
                      Icons.person,
                      size: size * 0.8,
                      color: Colors.grey,
                    ),
                    placeholder: (context, url) => Container(
                      width: size,
                      height: size,
                      color: Colors.grey[200],
                    ),
                  )
                : Icon(Icons.person, size: size * 0.8, color: Colors.grey),
          ),
        );
      },
    );
  }
}

class _TabNavigator extends StatelessWidget {
  final Widget root;
  final GlobalKey<NavigatorState> navKey;
  const _TabNavigator({required this.root, required this.navKey});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey,
      onGenerateRoute: (settings) =>
          MaterialPageRoute(builder: (_) => root, settings: settings),
    );
  }
}
