import 'package:flutter/material.dart';
import 'connect_title.dart';
import '../screens/search/search_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/home/favorites_screen.dart';
import 'circular_reveal_animation.dart';

class ConnectAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showSearch;
  final bool showSettings;
  final bool showLeading;
  final bool showBack;
  final String? title;
  final VoidCallback? onSync;
  const ConnectAppBar({
    super.key,
    this.showSearch = true,
    this.showSettings = false,
    this.showLeading = true,
    this.showBack = false,
    this.title,
    this.onSync,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFF6F6F6),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: const Color(0xFFF6F6F6),
      iconTheme: const IconThemeData(color: Colors.black, size: 24),
      title: title != null
          ? Text(
              title!,
              style: const TextStyle(
                fontFamily: 'ArchivoBlack',
                fontSize: 16,
                letterSpacing: -0.5,
                color: Colors.black,
              ),
            )
          : const ConnectTitle(),
      centerTitle: true,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            )
          : showLeading
          ? Padding(
              padding: const EdgeInsets.only(left: 16),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const FavoritesScreen(),
                    ),
                  );
                },
                child: const Icon(
                  Icons.favorite,
                  color: Colors.black,
                  size: 28,
                ),
              ),
            )
          : null,
      actions: [
        if (onSync != null)
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.black),
            onPressed: onSync,
          ),
        if (showSearch)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                final screenWidth = MediaQuery.of(context).size.width;
                Navigator.of(context).push(
                  CircularRevealPageRoute(
                    page: const SearchScreen(),
                    center: Offset(screenWidth - 36, 40),
                  ),
                );
              },
              child: Image.asset('imgenes/BUSCAR.png', width: 36, height: 36),
            ),
          ),
        if (showSettings)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              child: const Icon(Icons.settings, color: Colors.black, size: 28),
            ),
          ),
      ],
    );
  }
}
