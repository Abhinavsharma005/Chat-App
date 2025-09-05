import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_screen.dart';
import 'sign_in.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        toolbarHeight: 70,
        title: const Align(
          alignment: Alignment.centerLeft,
          child: Text("Chat App"),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == "Profile") {
                Navigator.pushNamed(context, "/profile");
              } else if (value == "Logout") {
                await _logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: "Profile", child: Text("Profile")),
              PopupMenuItem(value: "Logout", child: Text("Logout")),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Find people by their phone no.",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.trim();
                });
              },
            ),
          ),

          // chats
          Expanded(
            child: (currentUser == null)
                ? const Center(child: Text("Not logged in"))
                : searchQuery.isNotEmpty
                ? _buildSearchResults(currentUser.uid)
                : _buildRecentChats(currentUser.uid),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .set({
          "isOnline": false,
          "lastSeen": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Sign out
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignIn()),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Logout failed: $e")),
      );
    }
  }

  /// Search logic
  Widget _buildSearchResults(String currentUser) {
    final isPhoneSearch = RegExp(r'^[0-9+]+$').hasMatch(searchQuery);

    if (isPhoneSearch) {
      // Search by phone
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .where("phone", isEqualTo: searchQuery)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final users =
          snapshot.data!.docs.where((u) => u.id != currentUser).toList();

          if (users.isEmpty) {
            return const Center(child: Text("No user found with this phone."));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              var user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user["image_url"] != null &&
                      user["image_url"].toString().isNotEmpty
                      ? NetworkImage(user["image_url"])
                      : null,
                  child: (user["image_url"] == null ||
                      user["image_url"].toString().isEmpty)
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(user["name"] ?? "Unknown"),
                subtitle: Text(user["phone"] ?? ""),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        receiverId: user.id,
                        receiverName: user["name"] ?? "Unknown",
                        receiverImage: user["image_url"] ?? "",
                        isOnline: user["isOnline"] ?? false,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    } else {
      // Search by name → filter from recent chats
      return _buildRecentChats(currentUser,
          filterName: searchQuery.toLowerCase());
    }
  }

  /// Recent chats
  Widget _buildRecentChats(String currentUser, {String? filterName}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("chats")
          .where("participants", arrayContains: currentUser)
          .orderBy("lastMessageTime", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading chats"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data!.docs;

        if (chats.isEmpty) {
          return const Center(child: Text("No recent chats yet."));
        }

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            var chat = chats[index];
            var participants = List<String>.from(chat["participants"]);
            var otherUserId =
            participants.firstWhere((id) => id != currentUser);

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection("users")
                  .doc(otherUserId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox.shrink();
                }
                var user = userSnapshot.data!;
                if (!user.exists) return const SizedBox.shrink();

                // Filter by name (if searching)
                if (filterName != null &&
                    !user["name"]
                        .toString()
                        .toLowerCase()
                        .contains(filterName)) {
                  return const SizedBox.shrink();
                }

                String lastMessage = chat["lastMessage"] ?? "";
                String timeText = "";
                if (chat["lastMessageTime"] != null) {
                  final dt =
                  (chat["lastMessageTime"] as Timestamp).toDate();
                  timeText =
                  "${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}";
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user["image_url"] != null &&
                        user["image_url"].toString().isNotEmpty
                        ? NetworkImage(user["image_url"])
                        : null,
                    child: (user["image_url"] == null ||
                        user["image_url"].toString().isEmpty)
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(user["name"] ?? "Unknown"),
                  subtitle: Text(lastMessage),
                  trailing: timeText.isNotEmpty ? Text(timeText) : null,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          receiverId: user.id,
                          receiverName: user["name"] ?? "Unknown",
                          receiverImage: user["image_url"] ?? "",
                          isOnline: user["isOnline"] ?? false,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}



