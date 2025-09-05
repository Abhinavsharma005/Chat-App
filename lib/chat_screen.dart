import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:video_player/video_player.dart';
import 'package:giphy_get/giphy_get.dart';
import 'dart:io';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverImage;
  final bool isOnline;

  const ChatScreen({
    Key? key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverImage,
    required this.isOnline,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  final ImagePicker _picker = ImagePicker();

  // Cloudinary
  final cloudinary =
  CloudinaryPublic("dyjfbhbzk", "to_do_cloudinary", cache: false);

  //Giphy
  final String giphyApiKey = "Or1lSyG0ChMOzfZP6UqKSKoG6zHkiaaB";

  void sendMessage(String type, String content) async {
    if (content.trim().isEmpty) return;

    String chatId = currentUid.hashCode <= widget.receiverId.hashCode
        ? '$currentUid-${widget.receiverId}'
        : '${widget.receiverId}-$currentUid';

    DocumentReference chatDoc =
    FirebaseFirestore.instance.collection('chats').doc(chatId);

    chatDoc.set({
      'participants': [currentUid, widget.receiverId],
      'lastMessage': type == "text"
          ? content
          : (type == "gif" ? "🖼 GIF" : "📎 Media"),
      'lastMessageTime': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    chatDoc.collection('messages').add({
      'senderId': currentUid,
      'type': type,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _msgController.clear();
  }

  Future<void> _pickMedia() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text("Image"),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image =
                await _picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  try {
                    CloudinaryResponse response = await cloudinary.uploadFile(
                      CloudinaryFile.fromFile(image.path,
                          resourceType: CloudinaryResourceType.Image),
                    );
                    sendMessage("image", response.secureUrl);
                  } catch (e) {
                    print("Image upload failed: $e");
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text("Video"),
              onTap: () async {
                Navigator.pop(context);
                final XFile? video =
                await _picker.pickVideo(source: ImageSource.gallery);
                if (video != null) {
                  try {
                    CloudinaryResponse response = await cloudinary.uploadFile(
                      CloudinaryFile.fromFile(video.path,
                          resourceType: CloudinaryResourceType.Video),
                    );
                    sendMessage("video", response.secureUrl);
                  } catch (e) {
                    print("Video upload failed: $e");
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text("File"),
              onTap: () async {
                Navigator.pop(context);
                FilePickerResult? result =
                await FilePicker.platform.pickFiles();
                if (result != null && result.files.single.path != null) {
                  try {
                    CloudinaryResponse response = await cloudinary.uploadFile(
                      CloudinaryFile.fromFile(result.files.single.path!,
                          resourceType: CloudinaryResourceType.Raw),
                    );
                    sendMessage("file", response.secureUrl);
                  } catch (e) {
                    print("File upload failed: $e");
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickGif() async {
    GiphyGif? gif = await GiphyGet.getGif(
      context: context,
      apiKey: giphyApiKey,
      lang: GiphyLanguage.english,
    );

    if (gif != null && gif.images?.original != null) {
      sendMessage("gif", gif.images!.original!.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    String chatId = currentUid.hashCode <= widget.receiverId.hashCode
        ? '$currentUid-${widget.receiverId}'
        : '${widget.receiverId}-$currentUid';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Theme.of(context).primaryColor,
        toolbarHeight: 64,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.receiverImage),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.receiverName,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  widget.isOnline ? "Online" : "Offline",
                  style: const TextStyle(fontSize: 12, color: Colors.black),
                ),
              ],
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msg = messages[index];
                    bool isMe = msg['senderId'] == currentUid;

                    String formattedTime = "";
                    if (msg['timestamp'] != null) {
                      Timestamp ts = msg['timestamp'] as Timestamp;
                      DateTime dt = ts.toDate();
                      formattedTime = DateFormat('hh:mm a').format(dt);
                    }

                    Widget messageWidget;
                    switch (msg['type']) {
                      case "image":
                        messageWidget = Column(
                          children: [
                            Image.network(msg['content'],
                                width: 200, height: 200, fit: BoxFit.cover),
                            Text(formattedTime,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[700])),
                          ],
                        );
                        break;
                      case "gif":
                        messageWidget = Column(
                          children: [
                            Image.network(msg['content'],
                                width: 200, height: 200, fit: BoxFit.cover),
                            Text(formattedTime,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[700])),
                          ],
                        );
                        break;
                      case "video":
                        VideoPlayerController videoController =
                        VideoPlayerController.network(msg['content']);

                        messageWidget = FutureBuilder(
                          future: videoController.initialize(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
                              return AspectRatio(
                                aspectRatio: videoController.value.aspectRatio,
                                child: Stack(
                                  children: [
                                    VideoPlayer(videoController),
                                    Align(
                                      alignment: Alignment.center,
                                      child: IconButton(
                                        icon: Icon(
                                          videoController.value.isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          size: 40,
                                          color: Colors.white,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            videoController.value.isPlaying
                                                ? videoController.pause()
                                                : videoController.play();
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                          },
                        );
                        break;
                      case "file":
                        messageWidget = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.insert_drive_file),
                                SizedBox(width: 5),
                                Text("File (tap to open)"),
                              ],
                            ),
                            Text(formattedTime,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[700])),
                          ],
                        );
                        break;
                      default:
                        messageWidget = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(msg['content'],
                                style: const TextStyle(fontSize: 16)),
                            Text(formattedTime,
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[700])),
                          ],
                        );
                    }

                    return Align(
                      alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFFA3EAFD) //0xFF80EFCA
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: messageWidget,
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ✅ Message Input Row
          SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _pickMedia,
                ),
                IconButton(
                  icon: const Icon(Icons.gif, color: Colors.black, size: 38,),
                  onPressed: _pickGif,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: InputBorder.none),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () => sendMessage("text", _msgController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}




