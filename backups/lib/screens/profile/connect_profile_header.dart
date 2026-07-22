import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'join_date.dart';
import 'stat_item.dart';
import 'social_icon_box.dart';
import 'widgets/profile_action_buttons.dart';
import '../../services/firestore_service.dart';
import '../chats/chat_room_screen.dart';
import 'user_list_screen.dart';

class ConnectProfileHeader extends StatelessWidget {
  final String? userId;
  const ConnectProfileHeader({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    // If userId is null or same as current, it's OWN profile
    final targetId = userId ?? currentUid;
    final isOwnProfile = (currentUid != null && targetId == currentUid);

    return StreamBuilder<DocumentSnapshot>(
      stream: targetId != null
          ? FirebaseFirestore.instance
                .collection('users')
                .doc(targetId)
                .snapshots()
          : null,
      builder: (context, snapshot) {
        String? photo;
        String name = '';
        int followersCount = 0;
        int followingCount = 0;
        DateTime? createdAt;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          photo =
              data['photoURL'] ??
              data['photoUrl'] ??
              data['image'] ??
              data['avatar'] ??
              data['profilePic'] ??
              data['imageUrl'] ??
              data['photo'] ??
              data['foto'];
          name = data['displayName'] ?? data['name'] ?? data['username'] ?? '';

          followersCount = data['followersCount'] ?? data['followers'] ?? 0;
          followingCount = data['followingCount'] ?? data['following'] ?? 0;

          final ts = data['createdAt'];
          if (ts is Timestamp) createdAt = ts.toDate();
        }

        if (photo == null || photo.isEmpty) {
          final user = FirebaseAuth.instance.currentUser;
          if (isOwnProfile || (snapshot.hasError && targetId == user?.uid)) {
            photo = user?.photoURL;
            name = (name.isEmpty) ? (user?.displayName ?? '') : name;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 10),
                  // Left Column: Avatar & Join Date
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 108,
                        height: 108,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF0094FF),
                            width: 1.5,
                          ),
                          color: Colors.white,
                        ),
                        child: ClipOval(
                          child: photo == null || photo.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey,
                                )
                              : CachedNetworkImage(
                                  imageUrl: photo,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: Colors.grey[100]),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Right Column: Info & Stats
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: const TextStyle(
                                  fontFamily: 'MontserratArabic',
                                  fontSize: 17, // Slightly larger
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirestoreService().reviewsStream(
                            targetId ?? '',
                          ),
                          builder: (context, revSnap) {
                            double avg = 0;
                            if (revSnap.hasData &&
                                revSnap.data!.docs.isNotEmpty) {
                              final docs = revSnap.requireData.docs;
                              final total = docs.fold<double>(
                                0,
                                (prev, doc) =>
                                    prev + (doc.data()['rating'] ?? 0),
                              );
                              avg = total / docs.length;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Row(
                                children: [
                                  ...List.generate(5, (index) {
                                    final starValue = index + 1;
                                    IconData icon = Icons.star;
                                    Color color = Colors.grey.shade300;

                                    if (avg >= starValue) {
                                      color = Colors.blue.shade400;
                                    } else if (avg >= starValue - 0.5) {
                                      icon = Icons.star_half;
                                      color = Colors.blue.shade400;
                                    }

                                    return Icon(icon, color: color, size: 15);
                                  }),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5E5E5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Verificado',
                                      style: TextStyle(
                                        fontFamily: 'MontserratArabic',
                                        color: Color(0xFF0094FF),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .where('userId', isEqualTo: targetId)
                              .snapshots(),
                          builder: (context, postSnapshot) {
                            final postCount = postSnapshot.hasData
                                ? postSnapshot.data!.docs.length
                                : 0;

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: StatItem(
                                    title: 'Publicaciones',
                                    value: postCount,
                                  ),
                                ),
                                Expanded(
                                  child: StatItem(
                                    title: 'Seguidores',
                                    value: followersCount,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => UserListScreen(
                                            userId: targetId!,
                                            title: 'Seguidores',
                                            stream: FirestoreService()
                                                .followersStream(targetId),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: StatItem(
                                    title: 'Seguidos',
                                    value: followingCount,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => UserListScreen(
                                            userId: targetId!,
                                            title: 'Seguidos',
                                            stream: FirestoreService()
                                                .followingStream(targetId),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isOwnProfile) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: JoinDate(date: createdAt, isOwnProfile: true),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 108, // Shortened slightly on right
                        child: _EditButton(),
                      ),
                      const SizedBox(width: 2), // Even closer to Editar
                      const _UploadButton(),
                      const SizedBox(width: 8),
                      const SocialIconBox(asset: 'assets/iconos/instagram.png'),
                      const SizedBox(width: 4),
                      const SocialIconBox(asset: 'assets/iconos/facebook.png'),
                      const SizedBox(width: 4),
                      const SocialIconBox(asset: 'assets/iconos/whatsapp.png'),
                      const SizedBox(width: 4),
                      const SocialIconBox(asset: 'assets/iconos/tik-tok.png'),
                      const Spacer(flex: 15), // Pushed further right
                    ],
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column: Join Date & Follow Button
                      Expanded(
                        flex: 100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 22,
                              child: Center(
                                child: JoinDate(
                                  date: createdAt,
                                  isOwnProfile: false,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            StreamBuilder<bool>(
                              stream: FirestoreService().isFollowingStream(
                                currentUid ?? '',
                                targetId!,
                              ),
                              builder: (context, followSnap) {
                                final isFollowing =
                                    followSnap.hasData &&
                                    followSnap.data == true;
                                return FollowButton(
                                  isFollowing: isFollowing,
                                  onTap: () async {
                                    if (currentUid == null) {
                                      return;
                                    }
                                    await FirestoreService().toggleFollow(
                                      currentUid,
                                      targetId,
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Right Column: Social Icons & Message Button
                      Expanded(
                        flex: 100,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(
                              height: 22,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SocialIconBox(
                                    asset: 'assets/iconos/instagram.png',
                                  ),
                                  SizedBox(width: 4),
                                  SocialIconBox(
                                    asset: 'assets/iconos/facebook.png',
                                  ),
                                  SizedBox(width: 4),
                                  SocialIconBox(
                                    asset: 'assets/iconos/whatsapp.png',
                                  ),
                                  SizedBox(width: 4),
                                  SocialIconBox(
                                    asset: 'assets/iconos/tik-tok.png',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            MessageButton(
                              onTap: () async {
                                if (currentUid == null) {
                                  return;
                                }
                                final chatId = await FirestoreService()
                                    .getOrCreateChat(currentUid, targetId);

                                if (context.mounted) {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChatRoomScreen(
                                        chatId: chatId,
                                        peerId: targetId,
                                        collectionPath: 'chats',
                                        initialData: {
                                          'peerName': name,
                                          'peerAvatar': photo,
                                        },
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EditButton extends StatelessWidget {
  const _EditButton();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 30, // Thinner
        decoration: BoxDecoration(
          color: const Color(0xFFE4E4E4),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Editar',
          style: TextStyle(
            fontFamily: 'MontserratArabic',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            letterSpacing: 0.2,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  const _UploadButton();
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 30, // Thinner
        width: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFE4E4E4),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(7),
        child: Image.asset('assets/iconos/cargar.png', fit: BoxFit.contain),
      ),
    );
  }
}
