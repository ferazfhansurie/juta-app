import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:juta_app/screens/contact_detail.dart';
import 'package:juta_app/screens/video.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:fluttertoast/fluttertoast.dart' as fluttertoast;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:juta_app/screens/forward.dart';
import 'package:juta_app/utils/progress_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdfx/pdfx.dart';
import 'package:photo_view/photo_view.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';


class MessageScreen extends StatefulWidget {
  List<Map<String, dynamic>> messages;
  final Map<String, dynamic> conversation;
  String? botId;
  String? accessToken;
  String? workspaceId;
  String? integrationId;
  String? id;
  String? userId;
  String? companyId;
  List<dynamic>? labels;
  String? contactId;
  String? pipelineId;
  String? messageToken;
  Map<String,dynamic>? opportunity;
  String? botToken;
  String? chatId;
  String? whapi;
  String? name;
  String? phone;
  String? pic;
  String? location;
  String? userName;
    List<dynamic>? tags;
    int? phoneIndex;
  MessageScreen(
      {required this.messages,
      required this.conversation,
      this.botToken,
      this.phone,
      this.botId,
      this.accessToken,
      this.workspaceId,
      this.integrationId,
      this.phoneIndex,
      this.id,
      this.whapi,
      this.userId,
      this.tags,
      this.companyId,
      this.contactId,
      this.opportunity,
      this.pipelineId,
      this.location,
      this.userName,
this.messageToken,
this.chatId,
this.name,
this.pic,
      this.labels});

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  TextEditingController _messageController = TextEditingController();
  bool typing = false;
  bool expand = false;
  double height = 25;
  bool hasNewline = false;
  bool nowHasNewline = false;
  final String baseUrl = "https://api.botpress.cloud";
  bool stopBot = false;
  TextEditingController tagController = TextEditingController();
  int currentIndex = 0;
  TextEditingController searchController = TextEditingController();
  String filter = "";
  List<Map<String, dynamic>> conversations = [];
  final GlobalKey progressDialogKey = GlobalKey<State>();
  List<Map<String, dynamic>> users = [];
  String botId = '';
  String accessToken = '';
  String nextTokenConversation = '';
  String nextTokenUser = '';
  String workspaceId = '';
  String integrationId = '';
  User? user = FirebaseAuth.instance.currentUser;
  String email = '';
  String firstName = '';
  String company = '';
  String companyId = '';
  List<dynamic> allUsers = [];
  String nextMessageToken = '';
  String conversationId = "";
  UploadTask? uploadTask;
  final ScrollController _scrollController = ScrollController();
  final picker = ImagePicker();
  PlatformFile? pickedFile;
  VideoPlayerController? _controller;
  List<dynamic> pipelines = [];
  List<dynamic> opp = [];
 Map<String, dynamic> contactDetails = {};
List<dynamic> tags =[];
  Map<String, Uint8List?> _pdfCache = {};
    bool isDarkMode = false;
StreamSubscription<RemoteMessage>? _notificationSubscription;
  Map<String, dynamic>? replyToMessage;
  List<Map<String, dynamic>> quickReplies = [];
  bool showQuickReplies = false;
  OverlayEntry? _overlayEntry;
  bool showScrollToTop = false;
 final AudioPlayer _audioPlayer = AudioPlayer();
  // Cache for decoded images
  final Map<String, Uint8List> _imageCache = {};
bool _isPlaying = false;
Duration _duration = Duration.zero;
Duration _position = Duration.zero;


// Add this to your class state variables
String? highlightedMessageBody;
final GlobalKey _messageKey = GlobalKey();
final ItemScrollController _itemScrollController = ItemScrollController(); // For ScrollablePositionedList
final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
bool isManualScrollingToTop = false;

// Add these variables to your state

String selectedCategory = 'All';
String searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Sort messages by timestamp
    widget.messages.sort((a, b) {
      int timestampA = a['timestamp'] is int 
          ? a['timestamp'] 
          : (a['timestamp'] as Timestamp).millisecondsSinceEpoch ~/ 1000;
      int timestampB = b['timestamp'] is int 
          ? b['timestamp'] 
          : (b['timestamp'] as Timestamp).millisecondsSinceEpoch ~/ 1000;
      return timestampB.compareTo(timestampA); // For reverse chronological order
    });
     loadDarkModePreference();
    listenNotification();
      fetchCategories();
       if (widget.tags != null && widget.tags!.contains('stop bot')) {
  stopBot = true;
}
  // Replace old scroll listener with ItemPositionsListener
_itemPositionsListener.itemPositions.addListener(() {
  final positions = _itemPositionsListener.itemPositions.value;
  
  if (positions.isEmpty) return;

  // Get the last visible item index
  final lastIndex = positions.last.index;
  // Get the first visible item index
  final firstIndex = positions.first.index;
  
  // Only load more messages if we're not manually scrolling to top
  if (lastIndex >= widget.messages.length - 20 && !isManualScrollingToTop) {

    loadMoreMessages();
  }
  
  // Show/hide scroll to top button based on position
  setState(() {
    showScrollToTop = firstIndex > 3 && 
                     firstIndex < widget.messages.length - 2;
  });
});

    _messageController.addListener(() {
      String value = _messageController.text;
                        
      // Check for '/' trigger
      if (value.startsWith('/')) {
        _showQuickRepliesOverlay();
      } else if (showQuickReplies && !value.contains('/')) {
        _hideQuickRepliesOverlay();
      }

      // Your existing height calculation code
      List<String> lines = value.split('\n');
      int newHeight = 50 + (lines.length - 1) * 20;
      if (value.length > 29) {
        int additionalHeight = ((value.length - 1) ~/ 29) * 25;
        newHeight += additionalHeight;
      }
      setState(() {
        height = newHeight.clamp(0, 200).toDouble();
      });
    });
    fetchQuickReplies();
      _audioPlayer.durationStream.listen((Duration? duration) {
    if (duration != null) {
      setState(() {
        _duration = duration;
      });
    }
  });

  _audioPlayer.positionStream.listen((Duration position) {
    setState(() {
      _position = position;
    });
  });

  _audioPlayer.playerStateStream.listen((PlayerState state) {
    if (state.processingState == ProcessingState.completed) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    }
  });
  }

  Future<void> loadDarkModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }
  void _scrollListener() {
  if (_scrollController.offset >= _scrollController.position.maxScrollExtent &&
      !_scrollController.position.outOfRange) {
        showToast("Fetching more data...");
    loadMoreMessages();
  }
}
Future<void> listenNotification() async {
    _notificationSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      try {
        List<Map<String, dynamic>> messages = [];
        
        // Fetch messages from Firestore
        QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .collection('contacts')
            .doc(widget.contactId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(100) // Adjust the limit as needed
            .get();

        messages = messagesSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        
        // Update the state if the widget is still mounted
        if (mounted) {
          setState(() {
            widget.messages = messages; // Update the messages list
          });
        }
      } catch (e) {
         // Handle any errors
      }
    });
  }

void showToast(String message) {
  fluttertoast.Fluttertoast.showToast(
    msg: message,
    toastLength:  fluttertoast.Toast.LENGTH_SHORT,
    gravity:  fluttertoast.ToastGravity.BOTTOM,
    timeInSecForIosWeb: 1,
    backgroundColor: Colors.grey,
    textColor: Colors.white,
    fontSize: 16.0,
  );
}
Future<void> loadMoreMessages() async {
  try {
    List<Map<String, dynamic>> newMessages = [];
    int oldestTimestamp = widget.messages.last['timestamp'];
    
    // Fetch messages from Firebase
    QuerySnapshot messagesSnapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('contacts')
        .doc(widget.contactId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .where('timestamp', isLessThan: oldestTimestamp)
        .get();

    newMessages = messagesSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

    // Sort only the new messages before adding them
    newMessages.sort((a, b) {
      int timestampA = a['timestamp'] is int 
          ? a['timestamp'] 
          : (a['timestamp'] as Timestamp).millisecondsSinceEpoch ~/ 1000;
      int timestampB = b['timestamp'] is int 
          ? b['timestamp'] 
          : (b['timestamp'] as Timestamp).millisecondsSinceEpoch ~/ 1000;
      return timestampB.compareTo(timestampA);
    });

    if (mounted) {
      setState(() {
        // Simply add the new messages to the end since they're already sorted
        widget.messages.addAll(newMessages);
      });
    }
  } catch (e) {
    // Handle error
    print('Error loading more messages: $e');
  }
}

  
Future<dynamic> getContact(String number) async {
  // API endpoint
  var url = Uri.parse('https://services.leadconnectorhq.com/contacts/search/duplicate');

  // Request headers
  var headers = {
    'Authorization': 'Bearer ${widget.accessToken!}',
    'Version': '2021-07-28',
    'Accept': 'application/json',
  };

  // Request parameters
  var params = {
    'locationId': widget.location!,
    'number': number,
  };

  // Send GET request
  var response = await http.get(url.replace(queryParameters: params), headers: headers);
  // Handle response
  if (response.statusCode == 200) {
    // Success
    var data = jsonDecode(response.body);
        setState(() {
      tags = (data['contact'] != null)?data['contact']['tags']:[];
    });
    return data['contact'];
  } else {
    // Error
            return null;
  }
}
   void _showImageDialog() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media);
    if (result != null) {
      setState(() {
        pickedFile = result.files.first;
      if (pickedFile!.extension?.toLowerCase() == 'mp4' || pickedFile!.extension?.toLowerCase() == 'mov') {

          _controller?.dispose();
          _controller = VideoPlayerController.file(File(pickedFile!.path!))
            ..initialize().then((_) {
              setState(() {});
            });
        } else {
          _controller?.dispose();
          _controller = null;
        }
      });
    }
  }

Future<void> sendImageMessage(String to, PlatformFile imageFile, String caption) async {
  if (imageFile.path == null) {
    return;
  }
  // Fix: Use imageFile instead of pickedFile and add null safety checks
  String messageType = (imageFile.extension?.toLowerCase() == 'mov') ? 'video' : 'image';
  setState(() {
    pickedFile = null;
    _messageController.clear();
  });
  try {
    // Upload the image to Firebase Storage and get the URL
    String imageUrl = await uploadImageToFirebaseStorage(imageFile);
   // Convert image to base64 first
    final imageBytes = await File(imageFile.path!).readAsBytes();
    String base64Image = base64Encode(imageBytes);

    // Create and insert the new message object immediately
    Map<String, dynamic> newMessage = {
      'type': messageType,
      'from_me': true,
      messageType: {
        'data': base64Image,
      },
      'caption': caption,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'chat_id': widget.chatId,
      'direction': 'outgoing',
    };

    // Update UI immediately
    setState(() {
      widget.messages.insert(0, newMessage);
      pickedFile = null;
      _messageController.clear();
    });

    // Fetch the current user
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    // Fetch user document from Firestore
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('user')
        .doc(user.email)
        .get();

    if (!userSnapshot.exists) {
      return;
    }

    // Extract companyId from user data
    Map<String, dynamic> userData = userSnapshot.data() as Map<String, dynamic>;
    String companyId = userData['companyId'];

    // Fetch company document from Firestore
    DocumentSnapshot companySnapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .get();

    if (!companySnapshot.exists) {
      return;
    }

    // Extract apiUrl from company data
    Map<String, dynamic> companyData = companySnapshot.data() as Map<String, dynamic>;
    String baseUrl = companyData['apiUrl'] ?? 'https://mighty-dane-newly.ngrok-free.app';

    // Construct the request URL
    String url = '$baseUrl/api/v2/messages/image/${widget.companyId}/${widget.chatId}';
    var body = json.encode({
      'imageUrl': imageUrl,
      'caption': caption,
      'phoneIndex': widget.phoneIndex,
      'userName': widget.userName,
    });

    var response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      //final response2 = await http.get(Uri.parse(imageUrl));
    
    } else {
      // Handle error
    }
  } catch (e) {
    // Handle exception
  }
}
Future<void> sendDocumentMessage(String to, PlatformFile documentFile, String caption) async {
  if (documentFile.path == null) {
    return;
  }

  setState(() {
    pickedFile = null;
    _messageController.clear();
  });

  try {
    // Upload the document to Firebase Storage and get the URL
    String documentUrl = await uploadDocumentToFirebaseStorage(documentFile);
    // Convert document to base64
    final documentBytes = await File(documentFile.path!).readAsBytes();
    String base64Document = base64Encode(documentBytes);

    // Create and insert the new message object immediately
    Map<String, dynamic> newMessage = {
      'type': 'document',
      'from_me': true,
      'document': {
        'data': base64Document,
        'filename': documentFile.name,
        'fileSize': documentFile.size,
      },
      'caption': caption,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'chat_id': widget.chatId,
      'direction': 'outgoing',
    };

    // Update UI immediately
    setState(() {
      widget.messages.insert(0, newMessage);
      pickedFile = null;
      _messageController.clear();
    });

    // Fetch the current user
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch user document from Firestore
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('user')
        .doc(user.email)
        .get();

    if (!userSnapshot.exists) return;

    // Extract companyId from user data
    Map<String, dynamic> userData = userSnapshot.data() as Map<String, dynamic>;
    String companyId = userData['companyId'];

    // Fetch company document from Firestore
    DocumentSnapshot companySnapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .get();

    if (!companySnapshot.exists) return;

    // Extract apiUrl from company data
    Map<String, dynamic> companyData = companySnapshot.data() as Map<String, dynamic>;
    String baseUrl = companyData['apiUrl'] ?? 'https://mighty-dane-newly.ngrok-free.app';

    // Construct the request URL
    String url = '$baseUrl/api/v2/messages/document/${widget.companyId}/${widget.chatId}';
    var body = json.encode({
      'documentUrl': documentUrl,
      'filename': documentFile.name,
      'fileSize': documentFile.size,
      'caption': caption,
      'phoneIndex': widget.phoneIndex,
      'userName': widget.userName,
    });

    var response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      // Handle error
      print('Error sending document: ${response.statusCode}');
    }
  } catch (e) {
    print('Error sending document: $e');
  }
}

Future<String> uploadDocumentToFirebaseStorage(PlatformFile documentFile) async {
  try {
    // Create a reference to the location you want to upload to in Firebase Storage
    String fileName = DateTime.now().millisecondsSinceEpoch.toString() + '_' + documentFile.name;
    Reference ref = FirebaseStorage.instance.ref().child('chat_documents').child(fileName);

    // Upload the file to Firebase Storage
    UploadTask uploadTask = ref.putFile(File(documentFile.path!));

    // Wait for the upload to complete and get the download URL
    TaskSnapshot taskSnapshot = await uploadTask;
    String downloadUrl = await taskSnapshot.ref.getDownloadURL();

    return downloadUrl;
  } catch (e) {
    print('Error uploading document: $e');
    rethrow;
  }
}

Future<String> uploadImageToFirebaseStorage(PlatformFile imageFile) async {
  try {
    // Create a reference to the location you want to upload to in Firebase Storage
    String fileName = DateTime.now().millisecondsSinceEpoch.toString() + '_' + imageFile.name;
    Reference ref = FirebaseStorage.instance.ref().child('chat_images').child(fileName);

    // Upload the file to Firebase Storage
    UploadTask uploadTask = ref.putFile(File(imageFile.path!));

    // Wait for the upload to complete and get the download URL
    TaskSnapshot taskSnapshot = await uploadTask;
    String downloadUrl = await taskSnapshot.ref.getDownloadURL();

    return downloadUrl;
  } catch (e) {
        rethrow;
  }
}


  Future<void> updateStopBotStatus(String companyId, String contactId, bool stopBot) async {
    await FirebaseFirestore.instance
      .collection("companies")
      .doc(companyId)
      .collection("contacts")
      .doc(contactId)
      .get()
      .then((snapshot) {
        if (snapshot.exists) {
          List<dynamic> tags = snapshot.get("tags") ?? [];
          if (stopBot) {
            if (!tags.contains("stop bot")) {
              tags.add("stop bot");
            }
          } else {
            tags.remove("stop bot");
          }
          snapshot.reference.update({
            'tags': tags,
          }).then((_) {
                      }).catchError((error) {
                      });
        }
      }).catchError((error) {
              });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _notificationSubscription?.cancel(); // Cancel the subscription
    _audioPlayer.dispose();
    super.dispose();
  }
    Future<void> _openInGoogleMaps(String latitude, String longitude) async {
    final Uri googleMapsUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri);
    } else {
      throw 'Could not launch Google Maps.';
    }
  }
String getFormattedDate(DateTime messageDate) {
  DateTime now = DateTime.now();
  DateTime today = DateTime(now.year, now.month, now.day);
  DateTime yesterday = today.subtract(Duration(days: 1));

  DateTime messageDay = DateTime(messageDate.year, messageDate.month, messageDate.day);

   return DateFormat('MMM dd, yyyy').format(messageDate);
}
  @override
  Widget build(BuildContext context) {
    final colorScheme = isDarkMode
        ? ColorScheme.dark(
            primary: Color(0xFF101827),
            secondary: Colors.tealAccent,
            surface: Color(0xFF1F2937),
            background: Color(0xFF101827),
            onBackground: Colors.white,
          )
        : ColorScheme.light(
            primary: Color(0xFF2D3748),
            secondary: Color(0xFF2D3748),
            surface: Colors.white,
            background: Colors.white,
            onBackground: Color(0xFF2D3748),
          );

    return Theme(
       data: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: colorScheme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.background,
          foregroundColor: colorScheme.onBackground,
        ),
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: Colors.blue.withOpacity(0.5), // Change this to your desired color
          cursorColor: Colors.blue, // Change this to your desired cursor color
          selectionHandleColor: Colors.blue, // Change this to your desired handle color
        ),
      ),
      child: Scaffold(
         
        appBar: AppBar(
          backgroundColor:colorScheme.background,
          automaticallyImplyLeading: false,
          title: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: NeverScrollableScrollPhysics(),
            child: Row(
           
          
              children: [
                GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child:  Icon(CupertinoIcons.chevron_back,size: 35,
                        color: colorScheme.onBackground,)),
            
               
                if(true)//widget.conversation!['name'] != null)
                GestureDetector(
                  onTap: (){
                         //  _showConfirmDelete();
                         
                  },
                  child: Container(
                                             height: 35,
                                             width: 35,
                                              decoration: BoxDecoration(
                                              color: Color(0xFF2D3748),
                                              borderRadius: BorderRadius.circular(100),
                                            ),
                                            child: Center(child:(widget.pic == null || !widget.pic!.contains('.jpg'))?Icon((widget.phone != 'Group')?CupertinoIcons.person_fill:Icons.groups,size: 20,color: Colors.white,):ClipOval(
                                          child:Image.network(
              widget.pic!,
              fit: BoxFit.cover,
              width: 60,
              height: 60,
              errorBuilder: (context, error, stackTrace) {
                return Icon(CupertinoIcons.person_fill, size: 45, color: Colors.white);
              },
            ), 
            )),
                                          ),
                ),
                                    const SizedBox(
                  width: 5,
                ),
                 GestureDetector(
                  onTap: (){
                 
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ContactDetail(name: widget.name, phone: widget.phone, botToken: widget.botToken, labels: widget.tags,contactId: widget.contactId, pic: widget.pic,)));
                  },
                  child:  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 160,
                        child: Text(widget.name!,style: TextStyle(fontSize: 15),)),
                       if (tags.isNotEmpty)
                  Wrap(
                    spacing: 4.0,
                    runSpacing: 4.0,
                    children: tags.map<Widget>((tag) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: colorScheme.onBackground,
                            fontSize: 8,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                    ],
                  )
                ),
              
               
                
                GestureDetector(
                  onTap: (){
                  
                    _launchURL("tel:${widget.phone}");
                  },
                  child:  Icon(CupertinoIcons.phone_fill,size: 25,color:colorScheme.onBackground,)),
      
              Transform.scale(
                scale: 0.7,
                    child: Switch(
                      
                      activeColor: CupertinoColors.systemBlue ,
                      
                      value: !stopBot,
                     onChanged: (value){
                               
                     
                         if (mounted) {
                        
                           setState(() {
                               stopBot = !stopBot;
                           });
                             updateStopBotStatus(widget.companyId!,widget.contactId!,stopBot);
                         }
                    }),
                  ),
                    
              ],
            ),
          ),
      
        ),
        floatingActionButton: showScrollToTop
            ? Padding(
                padding: EdgeInsets.only(bottom: 80),
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.arrow_upward,
                      color: Colors.white),
                  onPressed: _scrollToTop,
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            setState(() {
              typing = false;
            });
          },
          child: Column(
            children: <Widget>[
              Expanded(
                child: Container(
  child: ScrollablePositionedList.builder(
    key: ValueKey<int>(widget.messages.length), // Preserve the key
    itemScrollController: _itemScrollController,
    itemPositionsListener: _itemPositionsListener,
    padding: const EdgeInsets.all(10),
    itemCount: widget.messages.length,
    reverse: true, // Display messages from the bottom
    itemBuilder: (context, index) {
      
      final message = widget.messages[index];
if(message['type'] == 'location'){
  print(message);
}
      bool showDateHeader = false;
     DateTime currentMessageDate;
  if (message['timestamp'] is int) {
    currentMessageDate = DateTime.fromMillisecondsSinceEpoch(message['timestamp'] * 1000).toLocal();
  } else if (message['timestamp'] is Timestamp) {
    currentMessageDate = (message['timestamp'] as Timestamp).toDate().toLocal();
  } else {
    currentMessageDate = DateTime.now().toLocal();
  }
 showDateHeader = false;
  if (index == widget.messages.length - 1) {
    showDateHeader = true;
  } else {
    DateTime nextMessageDate;
    if (widget.messages[index + 1]['timestamp'] is int) {
      nextMessageDate = DateTime.fromMillisecondsSinceEpoch(
        widget.messages[index + 1]['timestamp'] * 1000
      ).toLocal();
    } else if (widget.messages[index + 1]['timestamp'] is Timestamp) {
      nextMessageDate = (widget.messages[index + 1]['timestamp'] as Timestamp).toDate().toLocal();
    } else {
      nextMessageDate = DateTime.now().toLocal();
    }

    if (currentMessageDate.day != nextMessageDate.day ||
        currentMessageDate.month != nextMessageDate.month ||
        currentMessageDate.year != nextMessageDate.year) {
      showDateHeader = true;
    }
  }

      // Initialize a list to hold the widgets (date header + message)
      List<Widget> messageWidgets = [];

      // If a date header should be shown, add it first
     if (showDateHeader) {
        String formattedDate = getFormattedDate(currentMessageDate);
        messageWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Text(
                  formattedDate,
                  style: TextStyle(
                    color: (isDarkMode)?Colors.white:Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.0,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // Build the message widget based on its type
      if (message['chat_id'] != null) {
        final type = message['type'];
        final isSent = message['from_me'];
        DateTime parsedDateTime;

        if (message['timestamp'] is int) {
          parsedDateTime = DateTime.fromMillisecondsSinceEpoch(message['timestamp'] * 1000).toLocal();
        } else if (message['timestamp'] is Timestamp) {
          parsedDateTime = message['timestamp'].toDate().toLocal();
        } else {
          parsedDateTime = DateTime.now().toLocal();
        }

        String formattedTime = DateFormat('h:mm a').format(parsedDateTime);

        Widget messageWidget;

        switch (type) {

          case 'text':
            final messageText = message['text']['body'];
            messageWidget = Draggable<Map<String, dynamic>>(
              data: message,
              axis: Axis.horizontal,
              child: Align(
                alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
                child: _buildMessageBubble(isSent, messageText, [], formattedTime, colorScheme, message),
              ),
              feedback: Material(
                color: Colors.transparent,
                child: Opacity(
                  opacity: 0.7,
                  child: _buildMessageBubble(isSent, messageText, [], formattedTime, colorScheme, message),
                ),
              ),
              onDragEnd: (details) {
                if (details.offset.dx < -50 && isSent) { // Dragged left
                  setState(() {
                    replyToMessage = message;
                  });
                } else if (!isSent && details.offset.dx > 50) { // Dragged right
                  setState(() {
                    replyToMessage = message;
                  });
                }
              },
              childWhenDragging: Opacity(
                opacity: 0.0,
                child: _buildMessageBubble(isSent, messageText, [], formattedTime, colorScheme, message),
              ),
            );
            break;
case 'privateNote':
    final messageText = message['text']['body'];
    messageWidget = Draggable<Map<String, dynamic>>(
      data: message,
      axis: Axis.horizontal,
      child: Align(
        alignment: Alignment.centerRight,  // Center align for private notes
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          margin: EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.yellow[100],  // Light yellow background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.yellow[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.note, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    message['from'] ?? 'Private Note',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                messageText ?? '',
                style: TextStyle(color: Colors.grey[800]),
              ),
              SizedBox(height: 2),
              Text(
                formattedTime,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.7,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.yellow[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.yellow[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      message['from'] ?? 'Private Note',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  messageText ?? '',
                  style: TextStyle(color: Colors.grey[800]),
                ),
                SizedBox(height: 2),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      onDragEnd: (details) {
        if (details.offset.dx < -50) { // Dragged left
          setState(() {
            replyToMessage = message;
          });
        } else if (details.offset.dx > 50) { // Dragged right
          setState(() {
            replyToMessage = message;
          });
        }
      },
      childWhenDragging: Opacity(
        opacity: 0.0,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.yellow[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.yellow[300]!),
          ),
          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.note, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 4),
                  Text(
                    message['from'] ?? 'Private Note',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                messageText ?? '',
                style: TextStyle(color: Colors.grey[800]),
              ),
              SizedBox(height: 2),
              Text(
                formattedTime,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    break;
    
          case 'document':
           
              messageWidget = Stack(
                children: [
                  Container(
                    
                    child: GestureDetector(
                      onTap: () => _openDocument(context, message['document']),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                     color: isSent ? CupertinoColors.systemBlue : colorScheme.onBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.description, size: 40,color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message['document']['filename'] ?? 'Document',
                                    style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (message['document']['fileSize'] != null)
                                    Text(
                                      '${(message['document']['fileSize'] / 1024).toStringAsFixed(1)} KB',
                                      style: TextStyle(fontSize: 12, color: const Color.fromARGB(255, 255, 255, 255)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                        Positioned(
                            bottom:5,
                            right: 15,
                            child: Text(
                              formattedTime,
                              style: TextStyle(fontSize: 12, color: const Color.fromARGB(255, 255, 255, 255)),
                            ),
                          ),
                ],
              );
           
            break;

          case 'image':
            if (message['image']['data'] != null) {
              messageWidget = Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                      width: MediaQuery.of(context).size.width * 70 / 100,
                      padding: EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
         color: isSent ? CupertinoColors.systemBlue : colorScheme.onBackground,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: Builder(
                              builder: (context) {
                                try {
                                  final imageDataKey = message['image']['data'];

                                  // Check if the image is already cached
                                  if (!_imageCache.containsKey(imageDataKey)) {
                                    _imageCache[imageDataKey] = base64Decode(imageDataKey);
                                  }

                                  return GestureDetector(
                                    onTap: () => _openImageFullScreen(context, _imageCache[imageDataKey]!),
                                    child: Image.memory(
                                      _imageCache[imageDataKey]!,
                                      height: 250,
                                      width: 250,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(context, isSent),
                                    ),
                                  );
                                } catch (e) {
                                  return _buildErrorWidget(context, isSent);
                                }
                              },
                            ),
                          ),
if (message['image']['caption'] != null && message['image']['caption'].isNotEmpty)
  Padding(
    padding: EdgeInsets.only(top: 5, left: 8, right: 8, bottom: 20),
    child: Text(
      message['image']['caption'],
      style: TextStyle(
        color: Colors.white,
        fontSize: 15.0,
        fontFamily: 'SF',
      ),
    ),
  ),

// ... existing code ...
                        ],
                      ),
                      Positioned(
                        bottom: 5,
                        right: 15,
                        child: Text(
                          formattedTime,
                          style: TextStyle(fontSize: 12, color: const Color.fromARGB(255, 255, 255, 255)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (message['image']['link'] != null) {
              messageWidget = Padding(
                padding: const EdgeInsets.all(4),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isSent ? CupertinoColors.systemBlue : const Color.fromARGB(255, 224, 224, 224),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(4),
                                child: Builder(
                                  builder: (context) {
                                    return GestureDetector(
                                      onTap: () => _openImageFullScreen(context, null, message['image']['link']),
                                      child: CachedNetworkImage(
                                        imageUrl: message['image']['link'],
                                        height: 250,
                                        width: 250,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                                        errorWidget: (context, url, error) => _buildErrorWidget(context, isSent),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (message['caption'] != null && message['caption'].isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 5, left: 8, right: 8, bottom: 20),
                                  child: Text(message['caption']),
                                ),
                            ],
                          ),
                          Positioned(
                            bottom: 5,
                            right: 15,
                            child: Text(
                              formattedTime,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                          Positioned(
                            bottom:5,
                            right: 15,
                            child: Text(
                              formattedTime,
                              style: TextStyle(fontSize: 12, color: const Color.fromARGB(255, 255, 255, 255)),
                            ),
                          ),
                  ],
                ),
              );
            } else {
              messageWidget = SizedBox.shrink(); // Hide if image data is missing
            }
            break;

          case 'video':
            if (message['video'] != null && message['video']['link'] != null) {
              messageWidget = VideoMessageBubble(
                videoUrl: message['video']['link'],
                caption: message['video']['caption'],
                isSent: isSent,
                time: formattedTime,
              );
            } else {
              messageWidget = SizedBox.shrink(); // Hide if video link is missing
            }
            break;

case 'ptt':
  messageWidget = GestureDetector(
    onTap: () async {
      try {
        if (message['ptt']['data'] != null) {
          setState(() {
            _isPlaying = !_isPlaying;
          });
          
          if (_isPlaying) {
            final audioData = base64Decode(message['ptt']['data']);
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/temp_audio.mp3');
            
            await tempFile.writeAsBytes(audioData);
            
            // Use just_audio to play the file
            await _audioPlayer.setFilePath(tempFile.path);
            await _audioPlayer.play();
          } else {
            await _audioPlayer.pause();
          }
        }
      } catch (e) {
        print('Error playing audio: $e');
        showToast('Error playing audio message');
        setState(() {
          _isPlaying = false;
        });
      }
    },
    child: Stack(
      children: [
           
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
   
              alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: isSent ? CupertinoColors.systemBlue : colorScheme.onBackground,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 8.0),
              Container(
                width: 120,
                height: 25,
                child: CustomPaint(
                  painter: WaveformPainter(
                    progress: _duration.inMilliseconds > 0 
                      ? _position.inMilliseconds / _duration.inMilliseconds 
                      : 0,
                    waveColor: Colors.white.withOpacity(0.3),
                    progressColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 8.0),
              Text(
                _formatDuration(_position),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFamily: 'SF',
                ),
              ),
            
            ],
          ),
        ),
          Positioned(
                            bottom:5,
                            right: 15,
                            child: Text(
                              formattedTime,
                              style: TextStyle(fontSize: 12, color: const Color.fromARGB(255, 255, 255, 255)),
                            ),
                          ),
      ],
    ),
  );
  break;
          case 'poll':
            final messageText = message['poll']['title'];
            messageWidget = Align(
              alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
              child: _buildMessageBubble(
                isSent,
                messageText,
                message['poll']['options'],
                formattedTime,
                colorScheme,
                message,
              ),
            );
            break;
          case 'location':
            messageWidget = Align(
              alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(horizontal: 8.0),
                decoration: BoxDecoration(
                  color: isSent ? CupertinoColors.systemBlue : colorScheme.onBackground,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, color: CupertinoColors.systemRed),
                        SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Sent Location",
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 17,
                                fontFamily: 'SF',
                                fontWeight: FontWeight.bold
                              )
                            ),
                            Text(
                              'Tap to view in Google Maps',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 12,
                                fontFamily: 'SF',
                                fontWeight: FontWeight.bold
                              )
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 9.0,
                        color: isSent ? Colors.white : colorScheme.background,
                        fontFamily: 'SF',
                      ),
                    ),
                  ],
                ),
              ),
            );
            break;
            case 'call_log':
              messageWidget = Align(
                alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.all(8),
                  margin: const EdgeInsets.symmetric(horizontal: 8.0),
                  decoration: BoxDecoration(
                    color: isSent ? CupertinoColors.systemBlue : colorScheme.onBackground,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.call, color: CupertinoColors.systemRed),
                          SizedBox(width: 8),
                          Text(
                            "Called",
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 17,
                              fontFamily: 'SF',
                              fontWeight: FontWeight.bold
                            )
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 9.0,
                          color: isSent ? Colors.white : colorScheme.background,
                          fontFamily: 'SF',
                        ),
                      ),
                    ],
                  ),
                ),
              );
              break;

          default:
            // Handle unknown message types as text
            final messageText = message['body'] ?? message['text']?['body'] ?? '';
            messageWidget = Align(
              alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
              child: _buildMessageBubble(isSent, messageText, [], formattedTime, colorScheme, message),
            );
        }

        // Add the message widget to the list
        messageWidgets.add(messageWidget);
      }

      // Return a Column containing the date header (if any) and the message widget
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: messageWidgets,
      );
    },
  ),
),


              ),
         Container(
        child: Column(
      children: [
        if (pickedFile != null)
Stack(
  children: [
    ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 200,
        child: Builder(
          builder: (context) {
            if (pickedFile!.extension?.toLowerCase() == 'mp4' || 
                pickedFile!.extension?.toLowerCase() == 'mov') {
              return _controller != null
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  )
                : Center(child: CircularProgressIndicator());
            } else if (pickedFile!.extension?.toLowerCase() == 'pdf') {
              return Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.onBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description, size: 40, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            pickedFile!.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (pickedFile!.size != null)
                            Text(
                              '${(pickedFile!.size / 1024).toStringAsFixed(1)} KB',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return Image.file(
                File(pickedFile!.path!),
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(child: Text('Failed to load image'));
                },
              );
            }
          },
        ),
      ),
    ),
    GestureDetector(
      onTap: () {
        setState(() {
          pickedFile = null;
          _controller?.dispose();
          _controller = null;
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.onBackground,
            borderRadius: BorderRadius.circular(100),
          ),
          child: const Icon(Icons.close, color: Colors.white),
        ),
      ),
    )
  ],
),
        Container(
        child: Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        children: [
          if (replyToMessage != null)
              Container(
              
                             color: const Color.fromARGB(255, 57, 57, 57),
                child: Row(
                  children: [
                    Container(
                     width: 10,
                     height: 50,
                      decoration: BoxDecoration(
                        color: replyToMessage!['from_me']
                              ? const Color(0xFFDCF8C6) : colorScheme.onBackground,
                       
                      ),
                    ),
                    SizedBox(width: 5,),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(
                            replyToMessage!['from_me']
                              ?'You':widget.name!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: replyToMessage!['from_me']
                              ? const Color(0xFFDCF8C6) : colorScheme.onBackground,
                              fontSize: 15,
                              fontFamily: 'SF',
                            ),
                          ),
                          Text(
                            '${replyToMessage!['text']['body']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'SF',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          replyToMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
          Container(
           
            child: Row(
              children:[
              IconButton(
  icon: const Icon(Icons.quickreply),
  onPressed: () => _showQuickRepliesOverlay(), // or just _showQuickRepliesOverlay
  color: colorScheme.onBackground,
),
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _showImageDialog,
                  color: colorScheme.onBackground,
                ),
                 IconButton(
                  icon: const Icon(Icons.video_camera_back),
                  onPressed: _showImageDialog,
                  color: colorScheme.onBackground,
                ),
                Expanded(
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Color.fromARGB(255, 187, 194, 206)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: TextField(
                        
                        onSubmitted: (value) async {
                          if (pickedFile == null) {
                           // Create the new message object
  final newMessage = {
    'type': 'text',
    'from_me': true,
    'text': {'body':  _messageController.text},
    'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'chat_id': widget.chatId,
    'direction': 'outgoing',
  };

  // Update UI first (optimistic update)
  setState(() {
    widget.messages = [newMessage, ...widget.messages]; // Create new list reference
  
    replyToMessage = null;
  });

                            await sendTextMessage(
                                widget.chatId!, _messageController.text);
                              _messageController.clear();    
                          } else {
                          if (pickedFile!.extension?.toLowerCase() == 'pdf') {
                            print(pickedFile);
    await sendDocumentMessage(widget.conversation['id'], pickedFile!, _messageController.text);
  } else {
    await sendImageMessage(widget.conversation['id'], pickedFile!, _messageController.text);
  }
                          }
                        },
                        onTap: () {
                          setState(() {
                            typing = true;
                          });
                        },
                        onTapOutside: (event) {
                          setState(() {
                            typing = false;
                          });
                        },
                        maxLines: null,
                        expands: true,
                        cursorColor: Colors.black,
                        style:  TextStyle(
                          color: colorScheme.onBackground,
                          fontSize: 15,
                          fontFamily: 'SF',
                        ),
                        controller: _messageController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 5),
                Container(
                  height: 35,
                  width: 35,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: Color(0xFF2D3748),
                  ),
                  child: IconButton(
                    iconSize: 20,
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      if (pickedFile == null) {
                       var newMessage = {
    'type': 'text',
    'direction': 'outgoing',
    'text': {'body': _messageController.text},
    'dateAdded': DateTime.now().toUtc().toIso8601String(),
    'from_me': true, // Add this to match your message bubble logic
    'chat_id': widget.chatId, // Add this to match your message filtering
    'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000, // Add this for consistent timestamp handling
  };

  // Create a new list reference to ensure setState triggers properly
  setState(() {
    widget.messages = [newMessage, ...widget.messages];

    pickedFile = null;
  });
                        await sendTextMessage(
                            widget.chatId!, _messageController.text);
                      } else {
                          // Create a new message object
     if (pickedFile!.extension?.toLowerCase() == 'pdf') {
      print('pdf senttt');
          await sendDocumentMessage(
            widget.chatId!,
            pickedFile!,
            _messageController.text
          );
        }else{
                         // Update the UI
                        if (widget.chatId != null) {
                          await (
                              widget.chatId!,
                              pickedFile!,
                              _messageController.text);
                        }
                    
                                   await sendImageMessage(
                                widget.chatId!,
                                pickedFile!,
                                _messageController.text);
                    
                      }
                      }
                    },
                    color: Color.fromARGB(255, 255, 255, 255),
                  ),
                )
              ],
            ),
          ),
          SizedBox(height: 25,)
        ],
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
    );
  }


void _openDocument(BuildContext context, Map<String, dynamic> document) async {
  try {
    final String? base64Data = document['data'];
    final String filename = document['filename'] ?? 'document.pdf';
    
    if (base64Data == null) {
      throw 'Document data not found';
    }

    // Convert base64 to bytes
    final bytes = base64Decode(base64Data.trim());
    
    // Get temporary directory
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$filename';
    
    // Write to temporary file
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    
    // Navigate to PDF viewer screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(filename),
          ),
          body: PDFView(
            filePath: filePath,
            enableSwipe: true,
            swipeHorizontal: false,
            autoSpacing: true,
            pageFling: true,
            onError: (error) {
                          },
            onPageError: (page, error) {
                          },
          ),
        ),
      ),
    );
    
  } catch (e) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('Error'),
        content: Text('Error opening document: $e'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
Future<void> sendTextMessage(String to, String messageText) async {
  setState(() {
    _messageController.clear();  
  });
  try {
    // Fetch the current user
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    // Fetch user document from Firestore
    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('user')
        .doc(user.email)
        .get();

    if (!userSnapshot.exists) {
      return;
    }

    // Extract companyId from user data
    Map<String, dynamic> userData = userSnapshot.data() as Map<String, dynamic>;
    String companyId = userData['companyId'];

    // Fetch company document from Firestore
    DocumentSnapshot companySnapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .get();

    if (!companySnapshot.exists) {
      return;
    }

    // Extract apiUrl from company data
    Map<String, dynamic> companyData = companySnapshot.data() as Map<String, dynamic>;
    String baseUrl = companyData['apiUrl'] ?? 'https://mighty-dane-newly.ngrok-free.app';

    // Construct the request URL
    String url = '${baseUrl}/api/v2/messages/text/${widget.companyId}/${widget.chatId}';
    var body = json.encode({
      'message': messageText,
      'quotedMessageId': replyToMessage?['id'], // Add logic for reply if needed
      'phoneIndex': widget.phoneIndex,
      'userName': widget.userName,
    });

    var response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      // Message sent successfully
      setState(() {
        replyToMessage = null;
      });
    } else {
      // Handle error
    }
  } catch (e) {
    // Handle exception
  }
}

  _launchURL(String url) async {
    await launch(Uri.parse(url).toString());
  }

  void _launchWhatsapp(String number) async {
        String url = 'https://wa.me/$number';
    try {
      await launch(url);
    } catch (e) {
      throw 'Could not launch $url';
    }
  }
   _showOptions(String message) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
     
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
           
            Container(
                color: Colors.white,
                height: 200,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () async {
                             ProgressDialog.show(context, progressDialogKey);
                   
                            ProgressDialog.hide(progressDialogKey);
                            Navigator.of(context)
                              .push(CupertinoPageRoute(builder: (context) {
                            return ForwardScreen(opp: opp,message:message,whapi: widget.whapi!,);
                          }));
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Container(
                              width: 100,
                              child: Text(
                                'Forward',
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                    fontSize: 16,
                                           fontFamily: 'SF',
                                    fontWeight: FontWeight.bold,
                                    color:  Color(0xFF2D3748)),
                              ),
                            ),
                            Icon(Icons.forward,color: Color(0xFF2D3748)),
                          ],
                        ),
                      ),
                      Divider(
                        color: Color(0xFF2D3748),
                      ),
                      GestureDetector(
                        onTap: () {
                         Clipboard.setData(ClipboardData(text: message));
    Navigator.pop(context); // Close the modal
    showToast('Message copied to clipboard');
                        
                        },
                        child: Container(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Container(
                                width: 100,
                                child: Text(
                                  'Copy',
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                        color:  Color(0xFF2D3748)),
                                ),
                              ),
                              Icon(Icons.copy,    color: Color(0xFF2D3748)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        );
      },
    );
  }
  // Add this helper method
String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String minutes = twoDigits(duration.inMinutes.remainder(60));
  String seconds = twoDigits(duration.inSeconds.remainder(60));
  return "$minutes:$seconds";
}


  Widget _buildPdfMessageBubble(bool isSent, String pdfUrl, String formattedTime,ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: isSent ? const Color(0xFFDCF8C6) : Colors.white,
        borderRadius: BorderRadius.circular(8.0),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            height: 300,
            child: FutureBuilder<Uint8List?>(
              future: _downloadPdfFile(pdfUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return PdfView(
                      controller: PdfController(
                        document: PdfDocument.openData(snapshot.data!),
                      ),
                    );
                  } else {
                    return Center(child: Text('Failed to load PDF'));
                  }
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              formattedTime,
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _downloadPdfFile(String url) async {
    if (_pdfCache.containsKey(url)) {
      return _pdfCache[url];
    }
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final pdfData = response.bodyBytes;
      _pdfCache[url] = pdfData;
      return pdfData;
    } else {
      throw Exception('Failed to load PDF');
    }
  }
void _jumpToQuotedMessage(Map<String, dynamic>? quotedContext) {
  if (quotedContext == null) return;
  
  try {
    String? quotedBody = quotedContext['quoted_content']?['body']?.toString();
    if (quotedBody == null) return;

    // Find the message index by matching the quoted text with message bodies
    int index = widget.messages.indexWhere((message) {
      if (message['type'] == 'text' && message['text'] != null) {
        String? messageBody = message['text']['body']?.toString();
        return messageBody?.trim() == quotedBody.trim();
      }
      return false;
    });
    print(index);
    if (index != -1) {
      setState(() {
        highlightedMessageBody = quotedBody;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
    
          
          _itemScrollController.scrollTo(
            index: index,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.1, // Using your working alignment value
          );
          
          // Remove highlight after 2 seconds
          Future.delayed(Duration(milliseconds: 10000), () {
            if (mounted) {
              setState(() {
                highlightedMessageBody = null;
              });
            }
          });
        } catch (e) {
          print('Error during scroll: $e');
          showToast('Error scrolling to message');
        }
      });
    } else {
      showToast('Message not found');
    }
  } catch (e) {
    print('Error jumping to message: $e');
    showToast('Could not find the quoted message');
  }
}
Widget _buildMessageBubble(
    bool isSent, String message, List<dynamic>? options, String time,ColorScheme colorScheme,Map<String, dynamic> messageData) {
  return GestureDetector(
    onTap: () {
      print(messageData);
      if(messageData['text']['context']['quoted_content']['body'] != null){
                                        _jumpToQuotedMessage(messageData['text']['context']);

      }
    },
    onLongPress: () {
      _showOptions(message);
    },
    child: Container(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      width: MediaQuery.of(context).size.width * 70 / 100,
      child: Align(
        alignment: isSent ? Alignment.centerRight : Alignment.bottomLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5),
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: BoxDecoration(
                color: (highlightedMessageBody != message) ?  isSent ? CupertinoColors.systemBlue : colorScheme.onBackground : Color.fromARGB(255, 27, 195, 49),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        right: 50.0, top: 8.0, bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if(messageData['text']['context'] != null)
                         Container(
          
                         decoration: BoxDecoration(
                         color: const Color.fromARGB(255, 206, 206, 206),
                          borderRadius: BorderRadius.circular(8.0),
                         ),
                           child: Row(
                             children: [
                               Container(
                     width: 10,
                     height: 35,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.only(
      topLeft: Radius.circular(5),
      bottomLeft: Radius.circular(5),
    ),
                        color: messageData!['from_me']
                              ? const Color.fromARGB(255, 147, 147, 147) : colorScheme.background,
                       
                      ),
                    ),
                    SizedBox(width: 5,),
                               Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                            messageData!['text']['context']['quoted_author'] != widget.name
                              ?'You':widget.name!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSent
                              ? const  Color.fromARGB(255, 147, 147, 147) : colorScheme.background,
                              fontSize: 14,
                              fontFamily: 'SF',
                            ),
                          ),
                                   Container(
                                          width: MediaQuery.of(context).size.width * 40 / 100,
                                     child: Text(
                                      messageData['text']['context']['quoted_content']['body'],
                                      style:  TextStyle(
                                        fontSize: 12.0,
                                        color: isSent ? Color.fromARGB(255, 0, 0, 0) :colorScheme.background,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'SF',
                                      ),
                                        maxLines: 1,
                                                       overflow: TextOverflow.ellipsis,
                                                             ),
                                   ),
                                 ],
                               ),
                             ],
                           ),
                         ),
                        Text(
                          message,
                          style:  TextStyle(
                            fontSize: 15.0,
                            color: isSent ? Color.fromARGB(255, 255, 255, 255) :colorScheme.background,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'SF',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 5,
                    right: 5,
                    child: Text(
                      time,
                      style:  TextStyle(
                        fontSize: 9.0,
                        color:  isSent ? Color.fromARGB(255, 255, 255, 255) :colorScheme.background,
                        fontFamily: 'SF',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (options!.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  child: ListView.builder(
                    itemCount: options.length,
                    shrinkWrap: true,
                    scrollDirection: Axis.vertical,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4.0, horizontal: 8.0),
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(141, 124, 124, 124),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Center(
                          child: Text(
                            options[index]['label'].toString(),
                            style: const TextStyle(
                              fontSize: 16.0,
                              color: Color(0xFF0D85FF),
                              fontFamily: 'SF',
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            SizedBox(height: 10),
          ],
        ),
      ),
    ),
  );
}
Widget _buildErrorWidget(BuildContext context, bool isSent) {
  return Container(
    width: 200,
    height: 200,
    decoration: BoxDecoration(
      color: isSent ? const Color(0xFF0D85FF) : Color.fromARGB(141, 217, 0, 0),
      borderRadius: BorderRadius.circular(8.0),
    ),
    child: Center(
      child: Text(
        "Image failed to load",
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 16.0,
          color: Colors.white,
          fontFamily: 'SF',
        ),
      ),
    ),
  );
}

void _openImageFullScreen(BuildContext context, Uint8List? imageData, [String? imageUrl]) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (context) => Scaffold(
      appBar: AppBar(title: Text('Image Viewer')),
      body: Center(
        child: PhotoView(
          imageProvider: imageData != null
              ? MemoryImage(imageData)
              : NetworkImage(imageUrl!) as ImageProvider,
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
      ),
    ),
  ));
}

void _openPdfFullScreen(BuildContext context, String pdfUrl) async {
  // Download the PDF file
  final response = await http.get(Uri.parse(pdfUrl));
  final bytes = response.bodyBytes;

  // Get a temporary directory on the device
  final dir = await getTemporaryDirectory();
  
  // Create a temporary file
  final file = File('${dir.path}/temp.pdf');
  
  // Write the PDF to the temporary file
  await file.writeAsBytes(bytes);

  // Open the PDF viewer
  Navigator.of(context).push(MaterialPageRoute(
    builder: (context) => Scaffold(
      appBar: AppBar(title: Text('PDF Viewer')),
      body: PDFView(
        filePath: file.path,
        enableSwipe: true,
        swipeHorizontal: true,
        autoSpacing: false,
        pageFling: false,
      ),
    ),
  ));
}

Future<void> fetchQuickReplies() async {
  try {
    // Get the current user's email
    String? userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail == null) return;

    // Fetch company quick replies
    var companySnapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('quickReplies')
        .orderBy('createdAt', descending: true)
        .get();

    // Fetch user's personal quick replies
    var userSnapshot = await FirebaseFirestore.instance
        .collection('user')
        .doc(userEmail)
        .collection('quickReplies')
        .orderBy('createdAt', descending: true)
        .get();

    List<Map<String, dynamic>> replies = [
      ...companySnapshot.docs.map((doc) => {
            'id': doc.id,
            'keyword': doc.data()['keyword'] ?? '',
            'text': doc.data()['text'] ?? '',
            'type': 'all',
            'document': doc.data()['document'],
            'image': doc.data()['image'],
            'category': doc.data()['category'],
          }),
      ...userSnapshot.docs.map((doc) => {
            'id': doc.id,
            'keyword': doc.data()['keyword'] ?? '',
            'text': doc.data()['text'] ?? '',
            'type': 'self',
            'document': doc.data()['document'],
            'image': doc.data()['image'],
          }),
    ];

    setState(() {
      quickReplies = replies;
    });
  } catch (e) {
      }
}

// Add these to your state variables
List<String> categories = [];

bool isLoading = false;

// Add this method to fetch categories
Future<void> fetchCategories() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('categories')
        .get();
    
    setState(() {
      categories = ['All', ...snapshot.docs.map((doc) => doc.data()['name'] as String)];
    });
  } catch (e) {
    print('Error fetching categories: $e');
  }
}

void _showQuickRepliesOverlay() {
  _hideQuickRepliesOverlay();
  late void Function() rebuildOverlay;

  void _buildAndShowOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideQuickRepliesOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.black54,
              ),
            ),
          ),
          
          // Main Content
          Positioned(
            top: MediaQuery.of(context).viewPadding.top + 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 10,
            right: 10,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? Color(0xFF1F2937) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Text(
                            'Quick Replies',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(Icons.close),
                            onPressed: _hideQuickRepliesOverlay,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ],
                      ),
                    ),

                    // Search Bar
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (value) {
                          searchQuery = value;
                          rebuildOverlay();
                        },
                        decoration: InputDecoration(
                          hintText: 'Search quick replies...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        ),
                      ),
                    ),

                    // Categories
                    Container(
                      height: 50,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = category == selectedCategory;
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: FilterChip(
                              selected: isSelected,
                              label: Text(category),
                              onSelected: (selected) {
                                selectedCategory = category;
                                rebuildOverlay();
                              },
                              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                              selectedColor: Colors.blue,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Quick Replies List
                    Expanded(
                      child: ListView.builder(
                        itemCount: getFilteredQuickReplies().length,
                        itemBuilder: (context, index) {
                          final reply = getFilteredQuickReplies()[index];
                          return QuickReplyTile(
                            reply: reply,
                            isDarkMode: isDarkMode,
                            onTap: () => _handleQuickReplySelection(reply),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  rebuildOverlay = () {
    _overlayEntry?.remove();
    _buildAndShowOverlay();
  };

  // Initial build of the overlay
  _buildAndShowOverlay();
}

// Helper method to get filtered quick replies
List<Map<String, dynamic>> getFilteredQuickReplies() {
  return quickReplies.where((reply) {
    final matchesSearch = searchQuery.isEmpty ||
        reply['keyword'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
        reply['text'].toString().toLowerCase().contains(searchQuery.toLowerCase());
    
    final matchesCategory = selectedCategory == 'All' ||
        reply['category'] == selectedCategory;
    
    return matchesSearch && matchesCategory;
  }).toList();
}

void _hideQuickRepliesOverlay() {
  _overlayEntry?.remove();
  _overlayEntry = null;
}

void _handleQuickReplySelection(Map<String, dynamic> reply) async {
  print(reply);
  if (reply['image'] != null) {
    // Handle image quick reply
    try {
      final response = await http.get(Uri.parse(reply['image']));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/temp_image.jpg');
        await file.writeAsBytes(response.bodyBytes);

        setState(() {
          pickedFile = PlatformFile(
            name: 'temp_image.jpg',
            path: file.path,
            size: response.bodyBytes.length,
            bytes: response.bodyBytes,
          );
        });
      }
    } catch (e) {
      print('Error downloading image: $e');
    }
  } else if (reply['document'] != null) {
    // Handle document quick reply
    try {
      final response = await http.get(Uri.parse(reply['document']));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/temp_document.pdf');
        await file.writeAsBytes(response.bodyBytes);

        setState(() {
          pickedFile = PlatformFile(
            name: 'document.pdf',
            path: file.path,
            size: response.bodyBytes.length,
            bytes: response.bodyBytes,
          );
        });
      }
    } catch (e) {
      print('Error downloading document: $e');
    }
  }

  setState(() {
    _messageController.text = reply['text'] ?? '';
  });

  _hideQuickRepliesOverlay();
}
void _scrollToTop() {
  setState(() {
    isManualScrollingToTop = true;
  });

  int topIndex = widget.messages.length - 1;
  _itemScrollController.scrollTo(
    index: topIndex,
    duration: Duration(milliseconds: 500),
    curve: Curves.easeInOut,
  ).then((_) {
  
  });
}
}

class WaveformPainter extends CustomPainter {
  final double progress;
  final Color waveColor;
  final Color progressColor;

  WaveformPainter({
    required this.progress,
    required this.waveColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final progressWidth = size.width * progress;
    final barWidth = 2.0;
    final spaceWidth = 1.0;
    final bars = (size.width / (barWidth + spaceWidth)).floor();

    for (var i = 0; i < bars; i++) {
      final x = i * (barWidth + spaceWidth);
      // Create a more uniform waveform pattern
      final normalizedHeight = 0.3 + (0.7 * (i % 3) / 2); // Creates a repeating pattern
      final height = size.height * normalizedHeight;
      final top = (size.height - height) / 2;

      paint.color = x < progressWidth ? progressColor : waveColor;
      
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
class QuickReplyTile extends StatelessWidget {
  final Map<String, dynamic> reply;
  final bool isDarkMode;
  final VoidCallback onTap;

  const QuickReplyTile({
    required this.reply,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reply['keyword'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  if (reply['images']?.isNotEmpty ?? false)
                    Icon(Icons.image, size: 20, color: Colors.blue),
                  if (reply['documents']?.isNotEmpty ?? false)
                    Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.description, size: 20, color: Colors.orange),
                    ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                reply['text'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                'Category: ${reply['category'] ?? 'Uncategorized'}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}