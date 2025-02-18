import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for Clipboard
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:juta_app/utils/toast.dart';
import 'package:country_code_picker/country_code_picker.dart'; // Import the package

class PairWhatsAppPage extends StatefulWidget {
  @override
  _PairWhatsAppPageState createState() => _PairWhatsAppPageState();
}

class _PairWhatsAppPageState extends State<PairWhatsAppPage> {
  TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  bool isDarkMode = false;
  String baseUrl = 'https://default-url.com'; // Default base URL
  String phoneCount = "1"; // Default to 1 phone
  int selectedPhoneIndex = 0; // Default selected phone index
  String companyId = ''; // To store companyId
  String? pairingCode; // To store the pairing code
  String selectedCountryCode = '60'; // Default country code for Malaysia without '+'

  @override
  void initState() {
    super.initState();
    loadDarkModePreference();
    fetchBaseUrlAndPhoneCount();
  }

  Future<void> loadDarkModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  Future<void> fetchBaseUrlAndPhoneCount() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('user')
        .doc(user.email)
        .get();

    if (!userSnapshot.exists) {
      return;
    }

    Map<String, dynamic> userData = userSnapshot.data() as Map<String, dynamic>;
    companyId = userData['companyId'];

    DocumentSnapshot companySnapshot = await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .get();

    if (!companySnapshot.exists) {
      return;
    }

    Map<String, dynamic> companyData = companySnapshot.data() as Map<String, dynamic>;
    setState(() {
      baseUrl = companyData['apiUrl'] ?? 'https://mighty-dane-newly.ngrok-free.app';
      phoneCount = companyData['phoneCount'] ?? "1";
    });
  }

  Future<void> pairNumberToWhatsApp(String phoneNumber) async {
    setState(() {
      _isLoading = true;
    });

    try {
      String url = '$baseUrl/api/request-pairing-code/$companyId';
      print(phoneNumber);
      var response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'phoneNumber': phoneNumber,
          'phoneIndex': selectedPhoneIndex,
        }),
      );

      if (response.statusCode == 200) {
        var responseData = json.decode(response.body);
        setState(() {
          pairingCode = responseData['pairingCode'];
        });
        Toast.show(context, 'success', 'Pairing code: $pairingCode');
      } else {
        var errorData = json.decode(response.body);
        Toast.show(context, 'error', errorData['error'] ?? 'Failed to pair number');
      }
    } catch (e) {
      Toast.show(context, 'error', 'An error occurred');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    Toast.show(context, 'success', 'Copied to clipboard');
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
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Pair WhatsApp Number', style: TextStyle(color: colorScheme.onBackground)),
        ),
        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus(); // Hide the keyboard
          },
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CountryCodePicker(
                        onChanged: (countryCode) {
                          setState(() {
                            selectedCountryCode = countryCode.dialCode?.replaceAll('+', '') ?? '60';
                          });
                        },
                        initialSelection: 'MY',
                        favorite: ['+60', 'MY'],
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                      ),
                      Expanded(
                        child: CupertinoTextField(
                          controller: _phoneController,
                          placeholder: 'Enter phone number',
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: colorScheme.onBackground),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorScheme.onBackground.withOpacity(0.1)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  DropdownButton<int>(
                    value: selectedPhoneIndex,
                    items: List.generate(int.parse(phoneCount), (index) {
                      return DropdownMenuItem(
                        value: index,
                        child: Text('Phone ${index + 1}'),
                      );
                    }),
                    onChanged: (value) {
                      setState(() {
                        selectedPhoneIndex = value!;
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  CupertinoButton(
                    color: Colors.black,
                    child: _isLoading
                        ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : Text('Get Pairing Code', style: TextStyle(color: Colors.white)),
                    onPressed: _isLoading
                        ? null
                        : () {
                            String phoneNumber = _phoneController.text.trim();
                            if (phoneNumber.isNotEmpty) {
                              pairNumberToWhatsApp(selectedCountryCode + phoneNumber);
                            } else {
                              Toast.show(context, 'error', 'Please enter a valid phone number');
                            }
                          },
                  ),
                  if (pairingCode != null) ...[
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pairing Code: $pairingCode',
                            style: TextStyle(color: colorScheme.onBackground),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.copy, color: colorScheme.onBackground),
                          onPressed: () => copyToClipboard(pairingCode!),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 20),
                  Text(
                    'How to link your device:',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onBackground),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '1. Enter phone number with country code.\n'
                    '2. Press Get Pairing Code.\n'
                    '3. Wait for a notification from WhatsApp or alternatively:\n'
                    '   - Android: Open WhatsApp, tap more options > Linked devices > Link a device > Link with phone number instead.\n'
                    '   - iPhone: Open WhatsApp, go to Settings > Linked devices > Link device > Link with phone number instead.\n'
                    '4. Enter the code given by Juta.\n'
                    '5. Wait until loading is done and save the name as Juta.',
                    style: TextStyle(color: colorScheme.onBackground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 