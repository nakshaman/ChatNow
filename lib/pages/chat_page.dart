// ignore_for_file: unnecessary_string_escapes

import 'dart:io';

import 'package:chats/services/database.dart';
import 'package:chats/services/shared_preferances.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:random_string/random_string.dart';

class ChatPage extends StatefulWidget {
  String name, profileUrl, username;
  ChatPage({
    required this.name,
    required this.profileUrl,
    required this.username,
    super.key,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  Stream? messagesStream;
  String? myUserName, myName, myEmail, myPicture, chatRoomId, messageId;
  TextEditingController messageController = TextEditingController();
  File? selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool showEmojiPicker = false;
  FocusNode inputFocusNode = FocusNode();
  getSharedPrefData() async {
    myUserName = await SharedPreferancesData().getUserName();
    myName = await SharedPreferancesData().getUserDisplayName();
    myEmail = await SharedPreferancesData().getUserEmail();
    myPicture = await SharedPreferancesData().getUserPicture();
    chatRoomId = getChatRoomIdByUsername(myUserName!, widget.username);
    setState(() {});
  }

  bool _isRecording = false;
  String? _filePath;
  FlutterSoundRecorder? _recorder = FlutterSoundRecorder();
  Future<void> _initialize() async {
    await _recorder?.openRecorder();
    await _requestPermission();
    var tempDir = await getTemporaryDirectory();
    _filePath = '${tempDir.path}/audio.aac';
  }

  Future<void> _requestPermission() async {
    var status = await Permission.microphone.request();
    if (!status.isGranted) await Permission.microphone.request();
  }

  Future<void> _startRecording() async {
    await _recorder?.startRecorder(toFile: _filePath);
    setState(() {
      _isRecording = true;
      Navigator.pop(context);
      openRecording();
    });
  }

  Future<void> _stopRecording() async {
    await _recorder?.stopRecorder();
    setState(() {
      _isRecording = false;
      Navigator.pop(context);
      openRecording();
    });
  }

  Future<void> openRecording() async {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            content: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    'Add Voice Note',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 20.0),
                  ElevatedButton(
                    onPressed: () async {
                      if (_isRecording) {
                        await _stopRecording();
                      } else {
                        await _startRecording();
                      }
                      setStateDialog(() {});
                    },
                    child: Text(
                      _isRecording ? 'Stop Recording' : 'Start Recording',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.0),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      if (_isRecording == false && _filePath != null) {
                        await _uploadFile();
                      }
                    },
                    child: Text(
                      'Upload Audio',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  onLoad() async {
    await getSharedPrefData();
    await getAndSetMessages();
    setState(() {});
  }

  @override
  void initState() {
    onLoad();
    _initialize();
    super.initState();
  }

  Future<void> _uploadFile() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red[300],
        content: Text(
          "Uploading Audio Please wait... ",
          style: TextStyle(fontSize: 20.0),
        ),
      ),
    );
    File file = File(_filePath!);
    try {
      TaskSnapshot snapshot = await FirebaseStorage.instance
          .ref('uploads/audio.aac')
          .putFile(file);
      String downloadUrl = await snapshot.ref.getDownloadURL();
      String formattedDate = DateFormat('h:mma').format(DateTime.now());
      Map<String, dynamic> messageInfoMap = {
        "Data": "Audio",
        "message": downloadUrl,
        "sendBy": myUserName,
        "formattedTime": formattedDate,
        "time": FieldValue.serverTimestamp(),
        "imgUrl": myPicture,
      };
      messageId = randomAlphaNumeric(10);
      await DatabaseMethods()
          .addMessage(chatRoomId!, messageId!, messageInfoMap)
          .then((value) {
            Map<String, dynamic> lastMessageInfo = {
              "lastMessage": "Audio",
              "lastMessageSendTs": formattedDate,
              "time": FieldValue.serverTimestamp(),
              "lastMessageSendBy": myUserName,
            };
            DatabaseMethods().updateLastMessageSend(
              chatRoomId!,
              lastMessageInfo,
            );
          });
    } catch (e) {
      debugPrint("Error uploading file: $e");
    }
  }

  Widget chatMessageTile(String message, bool isSendByMe) {
    return Row(
      mainAxisAlignment: isSendByMe
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            padding: EdgeInsets.all(16.0),
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
                bottomRight: isSendByMe
                    ? Radius.circular(0)
                    : Radius.circular(30),
                bottomLeft: isSendByMe
                    ? Radius.circular(30)
                    : Radius.circular(0),
              ),
              color: isSendByMe ? Colors.black45 : Colors.blueAccent,
            ),
            child: Text(
              message,
              softWrap: true,
              maxLines: null,
              overflow: TextOverflow.visible,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.0,
                fontWeight: FontWeight.normal,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _uploadImage() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red[300],
        content: Text(
          'Your image is uploading Please wait...',
          style: TextStyle(fontSize: 20.0),
        ),
      ),
    );
    try {
      String addId = randomAlphaNumeric(10);
      Reference firebaseStorageRef = FirebaseStorage.instance
          .ref()
          .child("blobImage")
          .child(addId);
      final UploadTask task = firebaseStorageRef.putFile(selectedImage!);
      var downloadUrl1 = await (await task).ref.getDownloadURL();
      String formattedDate = DateFormat('h:mma').format(DateTime.now());
      Map<String, dynamic> messageInfoMap = {
        "Data": "Image",
        "message": downloadUrl1,
        "sendBy": myUserName,
        "formattedTime": formattedDate,
        "time": FieldValue.serverTimestamp(),
        "imgUrl": myPicture,
      };
      messageId = randomAlphaNumeric(10);
      await DatabaseMethods()
          .addMessage(chatRoomId!, messageId!, messageInfoMap)
          .then((value) {
            Map<String, dynamic> lastMessageInfo = {
              "lastMessage": "Image",
              "lastMessageSendTs": formattedDate,
              "time": FieldValue.serverTimestamp(),
              "lastMessageSendBy": myUserName,
            };
            DatabaseMethods().updateLastMessageSend(
              chatRoomId!,
              lastMessageInfo,
            );
          });
    } catch (e) {
      debugPrint("Error uploading image: $e");
    }
  }

  Future<void> getImage() async {
    var image = await _picker.pickImage(source: ImageSource.gallery);
    selectedImage = File(image!.path);
    _uploadImage();
    setState(() {});
  }

  getAndSetMessages() async {
    messagesStream = DatabaseMethods().getChatRoomMessages(chatRoomId!);
    setState(() {});
  }

  Widget chatMessages() {
    return StreamBuilder(
      stream: messagesStream,
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.data.docs.isEmpty) {
          return Center(
            child: Text(
              'No messages yet. Start the conversation !',
              style: TextStyle(fontSize: 16.0, color: Colors.grey),
            ),
          );
        }
        return ListView.builder(
          itemCount: snapshot.data.docs.length,
          reverse: true,
          itemBuilder: (context, index) {
            DocumentSnapshot ds = snapshot.data.docs[index];
            return chatMessageTile(ds["message"], ds["sendBy"] == myUserName);
          },
        );
      },
    );
  }

  String getChatRoomIdByUsername(String a, String b) {
    a = a.toLowerCase().trim();
    b = b.toLowerCase().trim();

    if (a.compareTo(b) < 0) {
      return "${a}_$b";
    } else {
      return "${b}_$a";
    }
  }

  addMessage(bool sendClicked) async {
    if (messageController.text != "") {
      String message = messageController.text;
      messageController.text = "";

      DateTime now = DateTime.now();
      String formatDate = DateFormat('h:mma').format(now);
      Map<String, dynamic> messageInfoMap = {
        "Data": "Message",
        "message": message,
        "sendBy": myUserName,
        "formattedTime": formatDate,
        "time": FieldValue.serverTimestamp(),
        "imgUrl": myPicture,
      };
      messageId = randomAlphaNumeric(10);
      await DatabaseMethods()
          .addMessage(chatRoomId!, messageId!, messageInfoMap)
          .then((value) {
            Map<String, dynamic> lastMessageInfo = {
              "lastMessage": message,
              "lastMessageSendTs": formatDate,
              "time": FieldValue.serverTimestamp(),
              "lastMessageSendBy": myUserName,
            };
            DatabaseMethods().updateLastMessageSend(
              chatRoomId!,
              lastMessageInfo,
            );
            if (sendClicked) message = "";
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff703eff),
      body: Container(
        margin: EdgeInsets.only(top: 60.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width / 4.7),
                  Text(
                    widget.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 30.0),
            Expanded(
              child: Container(
                padding: EdgeInsets.only(left: 15, right: 10),
                width: MediaQuery.of(context).size.width,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height / 1.35,
                      child: chatMessages(),
                    ),
                    SizedBox(
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              openRecording();
                            },
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xff703eff),
                                borderRadius: BorderRadius.circular(60),
                              ),
                              child: Icon(
                                Icons.mic,
                                color: Colors.white,
                                size: 28.0,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          // GestureDetector(
                          //   onTap: () {
                          //     FocusScope.of(context).unfocus();
                          //     setState(() {
                          //       showEmojiPicker = !showEmojiPicker;
                          //     });
                          //   },
                          //   child: Container(
                          //     padding: EdgeInsets.all(6),
                          //     child: Icon(
                          //       Icons.emoji_emotions_outlined,
                          //       color: Colors.grey[700],
                          //       size: 28,
                          //     ),
                          //   ),
                          // ),
                          SizedBox(width: 8.0),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFFececf8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: messageController,
                                focusNode: inputFocusNode,
                                maxLines: null,
                                onTap: () {
                                  if (showEmojiPicker) {
                                    setState(() {
                                      showEmojiPicker = false;
                                    });
                                  }
                                },
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Write a message..",
                                  // contentPadding: EdgeInsets.only(
                                  //   top: 16.0,
                                  //   left: 8.0,
                                  //   right: 8.0,
                                  //   bottom: 10.0,
                                  // ),
                                  // hintStyle: TextStyle(fontSize: 15.0),
                                  suffixIcon: GestureDetector(
                                    onTap: () {
                                      getImage();
                                    },
                                    child: Icon(Icons.attach_file),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          GestureDetector(
                            onTap: () {
                              addMessage(true);
                            },
                            child: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Color(0xff703eff),
                                borderRadius: BorderRadius.circular(60),
                              ),
                              child: Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 26.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
