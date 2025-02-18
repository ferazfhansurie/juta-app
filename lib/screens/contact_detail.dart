// ignore_for_file: sized_box_for_whitespace, use_build_context_synchronously

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:juta_app/utils/toast.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactDetail extends StatefulWidget {
   ContactDetail({super.key, this.labels, this.name,
    this.phone, this.botToken,
    this.pic,
    this.accessToken, this.contactId,
    this.conversation, this.integrationId,
    this.botId, this.pipelineId,
this.opportunity});

  String? accessToken;
  String? botId;
  String? contactId;
  String? conversation;
  String? integrationId;
  String? botToken;
  String? pic;
  List<dynamic>? labels ;
  String? name;
  Map<String, dynamic>? opportunity;
  String? phone;
  String? pipelineId;

  @override
  State<ContactDetail> createState() => _ContactDetailState();
}

class _ContactDetailState extends State<ContactDetail> {
     String companyId = "";
  List<String> dropdownItems = [];
     String email = "";
   TextEditingController nameController = TextEditingController();
    TextEditingController phoneController = TextEditingController();
     int selectedValue = 0; // Store the selected value index
     bool typing = false;
      User? user = FirebaseAuth.instance.currentUser;

     @override
  void initState() {
    // TODO: implement initState
    nameController.text = widget.name!;
    phoneController.text = widget.phone!;
     email = user!.email!;
    getCompany();
    super.initState();
  }

  Future<void> updateOpportunityWithTags(
  String apiKey,
  String pipelineId,
  String opportunityId,
  Map<String, dynamic> opportunityData,
  List<dynamic> tags,
) async {
  final String baseUrl =
      'https://rest.gohighlevel.com/v1/pipelines/$pipelineId/opportunities/$opportunityId';

  try {
    // Add tags to the opportunity data
    opportunityData['title'] = opportunityData['name'];
    opportunityData['tags'] = tags;

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(opportunityData),
    );
print(response.body);
    if (response.statusCode == 200) {
      // Opportunity updated successfully
      print('Opportunity updated with tags');
    } else {
      // Request failed with a non-200 status code
      print('Failed to update opportunity: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  } catch (error) {
    // Handle any errors that occur during the request
    print('Error: $error');
  }
}

Future<void> getCompany() async {
  try {
    await FirebaseFirestore.instance
        .collection("user")
        .doc(email)
        .get()
        .then((snapshot) {
      if (snapshot.exists) {
        setState(() {
          companyId = snapshot.get("companyId");
        });
      } else {
        print("Snapshot not found");
      }
    });

    final companySnapshot = await FirebaseFirestore.instance
        .collection("companies")
        .doc(companyId)
        .collection("employee")
        .get();

    if (companySnapshot.docs.isNotEmpty) {
      // Clear the notifications list before adding data from documents
      dropdownItems.clear();

      for (final doc in companySnapshot.docs) {
    
        final data = doc.data();
      dropdownItems.add(data['name']);
      print(data.toString());
        setState(() {
          
        });
      }

    
    } else {
      print("No documents found in Employee subcollection");
    }
  } catch (e) {
    print("Error: $e");
  }
}

    Future<void> addTagsToContact( List<dynamic> tags) async {
  final String baseUrl = 'https://rest.gohighlevel.com/v1/contacts/${widget.contactId}/tags/';
  final String apiKey = widget.accessToken!; // Replace 'YOUR_API_KEY' with your actual API key

  // Create the request body
  Map<String, dynamic> requestBody = {
    "tags": tags,
  };

  // Convert the request body to JSON
  String jsonBody = json.encode(requestBody);

  // Set up the headers
  Map<String, String> headers = {
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };

  try {
    // Send POST request to add tags to the contact
    http.Response response = await http.post(
      Uri.parse(baseUrl),
      headers: headers,
      body: jsonBody,
    );
    if (response.statusCode == 200) {
    //  await _handleRefresh();
      Navigator.pop(context);
      Toast.show(context,'success','Tag Added');
   
      print('Tags added to contact successfully');
    } else {
      // Handle the error
          Toast.show(context,'danger','Failed to add tags');
      print('Failed to add tags. Status code: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  } catch (error) {
    // Handle any potential exceptions
    print('Error adding tags: $error');
  }



}Future<void> sendAssignmentNotification(String assignedEmployeeName) async {
  try {
    // Get company data
    DocumentSnapshot companyDoc = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .get();
    Map<String, dynamic> companyData = companyDoc.data() as Map<String, dynamic>;

    // Get assigned employee data
    QuerySnapshot employeeSnapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('employee')
        .where('name', isEqualTo: assignedEmployeeName)
        .get();

    if (employeeSnapshot.docs.isEmpty) {
      Toast.show(context, "error", "Employee not found");
      return;
    }

    Map<String, dynamic> assignedEmployee = 
        employeeSnapshot.docs.first.data() as Map<String, dynamic>;

    // Send WhatsApp messages
    String baseUrl = companyData['apiUrl'] ?? 'https://mighty-dane-newly.ngrok-free.app';
    
    // Send to assigned employee
    if (assignedEmployee['phoneNumber'] != null) {
      String employeeMessage = '''Hello ${assignedEmployee['name']}, a new contact has been assigned to you:

Name: ${widget.name}
Phone: ${widget.phone}

Kindly login to https://web.jutasoftware.co/login

Thank you.

Juta Teknologi''';

     sendWhatsAppMessage(
        assignedEmployee['phoneNumber'], 
        employeeMessage,
        companyData,
        baseUrl
      );
    }

    Toast.show(context, "success", "Assignment notification sent successfully!");
  } catch (e) {
    print("Error sending notifications: $e");
    Toast.show(context, "error", "Failed to send notifications");
  }
}
Future<void> sendWhatsAppMessage(
  String phoneNumber, 
  String message,
  Map<String, dynamic> companyData,
  String baseUrl
) async {
  String chatId = "${phoneNumber.replaceAll(RegExp(r'[^\d]'), '')}@c.us";
  
  String url;
  Map<String, dynamic> requestBody;
  
  if (companyData['v2'] == true) {
    url = "$baseUrl/api/v2/messages/text/$companyId/$chatId";
    requestBody = {
      'message': message,
      'phoneIndex': 0,  // You might want to adjust this
      'userName': user?.email ?? ''
    };
  } else {
    url = "$baseUrl/api/messages/text/$chatId/${companyData['whapiToken']}";
    requestBody = {'message': message};
  }

  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(requestBody),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to send WhatsApp message: ${response.body}');
  }
}
  Future<void> deleteConversation(String conversationId) async {
  String url = 'https://api.botpress.cloud/v1/chat/conversations/$conversationId';

  http.Response response = await http.delete(
    Uri.parse(url),
    headers: {
      'Content-type': 'application/json',
      'Authorization': 'Bearer ${widget.botToken}',
      'x-bot-id': widget.botId!,
      'x-integration-id': widget.integrationId!,
    },
  );
  print(response.body);
  if (response.statusCode == 200) {
    Navigator.pop(context);
     Navigator.pop(context);
    // Optionally, navigate away or update the UI
  } else {
    // Handle error
  }
}

 Future<bool> deleteContact(String pipelineId, String opportunityId, String token) async {
    final url = Uri.parse('https://rest.gohighlevel.com/v1/pipelines/$pipelineId/opportunities/$opportunityId');
    final response = await http.delete(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      // Assuming a successful deletion doesn't return a body, or change as needed
      Toast.show(context, "success", "Contact Deleted");
      Navigator.pop(context);
      return true;
    } else if (response.statusCode == 401) {
      throw Exception('Unauthorized request. Check the access token.');
    } else {
      throw Exception('Failed to delete opportunity. Status code: ${response.statusCode}');
    }
  }
      Widget _buildCupertinoPicker() {
    return Column(
      children: [
        Text(
                                                 "Assigned Salesman",
                                                 style: TextStyle(fontSize: 16.0, color: Color(0xFF2D3748),
                                               fontFamily: 'SF',),
                               ),
        Container(
          height: 100.0,
          color: Colors.white,
          child: CupertinoPicker(
            
            itemExtent: 32.0,
            onSelectedItemChanged: (int index) {
              setState(() {
                selectedValue = index;
              });
            },
            children: List<Widget>.generate(dropdownItems.length, (int index) {
              return Center(
                child: Text(
                  dropdownItems[index],
                  style: TextStyle(fontSize: 20.0),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(
        fontFamily: 'SF',
      ),
      child: Center(
        child: Scaffold(
          floatingActionButton: Container(
            height: 65,
            width: 65,
decoration:BoxDecoration(
  borderRadius: BorderRadius.circular(100),
  color: Color(0xFF2D3748),
),
            child:   GestureDetector(
              onTap: (){
          
                _launchWhatsapp(widget.phone!);
              },
               child: Image.asset(
                                        'assets/images/whatsapp.png',
                                        fit: BoxFit.contain,
                                        scale: 9,
                                      ),
             ),
          ),
       appBar: AppBar(
        backgroundColor:Color.fromARGB(255, 255, 255, 255),
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child:Text( 'Cancel',style: TextStyle( color: Color(0xFF2D3748),fontSize: 16),
                     )),
          
              
            
               GestureDetector(
               
                child: Container(
                
                  child: Text(widget.name!,style: const TextStyle(color: Color(0xFF2D3748),fontSize: 18),)),
              ),
          
              
            
          
          
              
              GestureDetector(
                 onTap: () async {
  try {
    print(dropdownItems[selectedValue]);
    print(widget.contactId);
    // Get current document to access existing tags
    DocumentSnapshot doc = await FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .collection('contacts')
      .doc(widget.contactId)
      .get();

    // Get current tags
Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    List<String> currentTags = List<String>.from(data['tags'] ?? []);
    
    // Remove old assignment tag (tags that match the pattern of dropdown items)
      // Remove old assignment tag (case-insensitive comparison)
    currentTags.removeWhere((tag) => 
      dropdownItems.any((item) => item.toLowerCase() == tag.toLowerCase())
    );
    
    
    // Add new tag
    currentTags.add(dropdownItems[selectedValue].toLowerCase());

    // Update tags in Firestore
    await FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .collection('contacts')
      .doc(widget.contactId)
      .update({'tags': currentTags});

    Toast.show(context, "success", "Tags Updated Successfully");
    Navigator.pop(context);
      sendAssignmentNotification(dropdownItems[selectedValue]);
  } catch (e) {
    Toast.show(context, "error", "Failed to update tags");
    print("Error updating tags: $e");
  }
},
                  child:Text( 'Save',style: TextStyle( color: Color.fromARGB(255, 59, 123, 233),fontSize: 16),
                     )),
                 
                         
               
                  
            ],
          ),
        ),

      ),
          body:  Builder(builder: (context) {
                  return Container(
                
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top,
                        left: 20,
                        right: 20
                      ),
                      child: Column(
                       
                        children: [
                        Center(
  child: Container(
    height: 100,
    width: 100,
    decoration: BoxDecoration(
      color: Color(0xFF2D3748),
      borderRadius: BorderRadius.circular(100),
      image: widget.pic != null
          ? DecorationImage(
              image: NetworkImage(widget.pic!),
              fit: BoxFit.cover,
            )
          : null,
    ),
    child: widget.pic == null
        ? Center(
            child: Text(
              widget.name!.substring(0, 1).toUpperCase(),
              style: TextStyle(color: Colors.white, fontSize: 40),
            ),
          )
        : null,
  ),
),
                       SizedBox(height: 10,),
                                 _buildCupertinoPicker(),
                                         Divider(),
                          SizedBox(height: 20,),
                       
                         SizedBox(height: 20,),
                            // ... existing code ...
Container(
  decoration: BoxDecoration(
    color: Color.fromARGB(255, 182, 183, 187),
    borderRadius: BorderRadius.circular(8)
  ),
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: phoneController.text));
        Toast.show(context, "success", "Phone number copied to clipboard");
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: TextField(
          controller: phoneController,
          enabled: false, // Make it read-only
          decoration: InputDecoration(
            hintText: 'Phone',
            hintStyle: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'SF',
              fontWeight: FontWeight.w400,
            ),
            disabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: const Color.fromARGB(0, 122, 122, 122),
                width: 0,
              ),
            ),
          ),
          style: TextStyle(
            color: Color(0xFF2D3748),
            fontSize: 16,
            fontFamily: 'SF',
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    ),
  ),
),

                        Divider(),
                        if(widget.labels != null)
                          Container(
                                      height: 40,
                                     
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          shrinkWrap: true,
                                          itemCount: widget.labels!.length,
                                          itemBuilder: ((context, index) {
                                          return   Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 5),
                                            child: Card(
                                             color: Color(0xFF2D3748),
                                              child: Container(
                                               
                                              
                                                child: Padding(
                                                  padding: const EdgeInsets.all(5),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      
                                                      Text(
                                                                                               widget.labels![index],
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                         fontFamily: 'SF',
                                                       
                                                      fontSize: 18
                                                                                              
                                                      ),
                                                                                              ),
                                                                                          
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        })),
                                      ),
                                      SizedBox(height: 20,),
                   
               Divider(),
           
                   
                        ],
                      ),
                    ),
                  );
                }),
            
        ),
      ),
    );
    
  }
    void _launchWhatsapp(String number) async {
    String url = 'https://wa.me/$number';
    try {
      await launch(url);
    } catch (e) {
      throw 'Could not launch $url';
    }
  }
} 