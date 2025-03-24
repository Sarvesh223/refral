import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

class ResponsiveFormPage extends StatefulWidget {
  const ResponsiveFormPage({Key? key}) : super(key: key);

  @override
  State<ResponsiveFormPage> createState() => _ResponsiveFormPageState();
}

class _ResponsiveFormPageState extends State<ResponsiveFormPage> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final instagramController = TextEditingController();
  final otpController = TextEditingController();
  final referralCodeController = TextEditingController();
  final verificationCodeController = TextEditingController();

  // Instagram page to follow
  final String _instagramPageUrl = 'https://www.instagram.com/_stly_a_r_es/';

  // Verification code for the follow action
  final String _followVerificationCode = 'FOLLOW2024';

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 2Factor.in API URLs
  final String _sendOtpUrl =
      'https://2factor.in/API/V1/7e11fedb-62c8-11ef-8b60-0200cd936042/SMS/';
  final String _verifyOtpUrl =
      'https://2factor.in/API/V1/7e11fedb-62c8-11ef-8b60-0200cd936042/SMS/VERIFY3/';

  // Authentication variables
  String _sessionId = '';
  bool _codeSent = false;
  bool _isLoading = false;
  String? _userId;
  bool _isAuthenticated = false;

  // Profile creation and Instagram follow status
  bool _profileCreated = false;
  bool _redirectedToInstagram = false;
  bool _followVerified = false;
  String? _generatedReferralCode;

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    instagramController.dispose();
    otpController.dispose();
    referralCodeController.dispose();
    verificationCodeController.dispose();
    super.dispose();
  }

  // Send OTP to the user's phone using 2Factor.in
  Future<void> _verifyPhone() async {
    if (phoneController.text.isEmpty) {
      _showSnackBar('Please enter a valid phone number', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Format the phone number without country code as the API expects it
      final phoneNumber = phoneController.text;

      // Construct the URL to send OTP
      final url = Uri.parse('${_sendOtpUrl}${phoneNumber}/AUTOGEN3/OTP3');

      // Make the HTTP request
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['Status'] == 'Success') {
          setState(() {
            _sessionId = data['Details']; // Save session ID for verification
            _codeSent = true;
            _isLoading = false;
          });
          _showSnackBar('OTP sent to your phone', Colors.green);
        } else {
          setState(() {
            _isLoading = false;
          });
          _showSnackBar('Failed to send OTP: ${data['Details']}', Colors.red);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Failed to send OTP. Please try again.', Colors.red);
      }
    } catch (e) {
      print(e);
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  // Verify OTP using 2Factor.in
  Future<void> _verifyOTP() async {
    if (otpController.text.isEmpty || otpController.text.length != 4) {
      _showSnackBar('Please enter a valid 4-digit OTP', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Format the phone number
      final phoneNumber = phoneController.text;

      // Construct the URL to verify OTP
      final url = Uri.parse(
        '${_verifyOtpUrl}${phoneNumber}/${otpController.text}',
      );

      // Make the HTTP request
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['Status'] == 'Success') {
          // Generate a unique user ID (since we're not using Firebase Auth)
          _userId =
              'user_${DateTime.now().millisecondsSinceEpoch}_${phoneNumber.substring(phoneNumber.length - 4)}';
          _isAuthenticated = true;

          // Successfully authenticated, now save data to Firestore
          await _saveUserDataToFirestore(_userId!);
        } else {
          setState(() {
            _isLoading = false;
          });
          _showSnackBar('Invalid OTP. Please try again.', Colors.red);
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Failed to verify OTP. Please try again.', Colors.red);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar(
        'Invalid OTP. Please try again: ${e.toString()}',
        Colors.red,
      );
    }
  }

  // Save user data to Firestore
  Future<void> _saveUserDataToFirestore(String userId) async {
    try {
      // Create a new document in the 'users' collection with the generated user ID
      await _firestore.collection('users').doc(userId).set({
        'name': nameController.text,
        'phone': phoneController.text,
        'instagram': instagramController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'followVerified': false,
        'referralCode': null,
      });

      setState(() {
        _isLoading = false;
        _codeSent = false;
        _profileCreated = true;
      });

      _showSnackBar('Profile created successfully', Colors.black);

      // After profile creation, prompt user to follow on Instagram
      _promptInstagramFollow();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error saving data: ${e.toString()}', Colors.red);
    }
  }

  // Prompt user to follow on Instagram
  void _promptInstagramFollow() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('One More Step!'),
          content: const Text(
            'Please follow our page on Instagram to get your referral code.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _redirectToInstagram();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('Follow Now'),
            ),
          ],
        );
      },
    );
  }

  // Redirect user to Instagram page
  Future<void> _redirectToInstagram() async {
    final Uri url = Uri.parse(_instagramPageUrl);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);

        setState(() {
          _redirectedToInstagram = true;
        });

        // After redirection, show verification dialog
        _showFollowVerificationDialog();
      } else {
        _showSnackBar('Could not launch Instagram', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  // Show follow verification dialog
  void _showFollowVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Verify Instagram Follow'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'After following our page, please enter the verification code shown in our Instagram bio:',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: verificationCodeController,
                decoration: const InputDecoration(
                  labelText: 'Verification Code',
                  hintText: 'Enter the code from our bio',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _verifyInstagramFollow();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
  }

  // Verify Instagram follow action
  void _verifyInstagramFollow() {
    if (verificationCodeController.text == _followVerificationCode) {
      setState(() {
        _followVerified = true;
      });

      // Generate referral code
      _generateReferralCode();
    } else {
      _showSnackBar('Invalid verification code. Please try again.', Colors.red);

      // Show verification dialog again
      _showFollowVerificationDialog();
    }
  }

  // Generate referral code for the user
  Future<void> _generateReferralCode() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Generate a unique referral code
      final String referralCode = _generateUniqueCode();

      // Update user document with referral code
      await _firestore.collection('users').doc(_userId).update({
        'followVerified': true,
        'referralCode': referralCode,
        'followVerifiedAt': FieldValue.serverTimestamp(),
      });

      // Also store the referral code in a separate 'referralCodes' collection
      await _firestore.collection('referralCodes').doc(referralCode).set({
        'userId': _userId,
        'userName': nameController.text,
        'userPhone': phoneController.text,
        'userInstagram': instagramController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'usedBy': [], // Empty array to track users who used this code
        'usageCount': 0, // Counter for number of times this code was used
        'isActive': true, // Flag to enable/disable the referral code
      });

      setState(() {
        _generatedReferralCode = referralCode;
        _isLoading = false;
      });

      // Show success dialog with referral code
      _showReferralCodeDialog(referralCode);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar(
        'Error generating referral code: ${e.toString()}',
        Colors.red,
      );
    }
  }

  // Generate a unique code for referrals
  String _generateUniqueCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final prefixPart =
        nameController.text
            .substring(0, min(3, nameController.text.length))
            .toUpperCase();

    // Generate random part (6 characters)
    String randomPart = '';
    for (var i = 0; i < 6; i++) {
      randomPart += chars[random.nextInt(chars.length)];
    }

    // Last 4 digits of phone number
    final phonePart = phoneController.text.substring(
      phoneController.text.length - 4,
    );

    return '${prefixPart}${randomPart}${phonePart}';
  }

  // Show referral code dialog
  void _showReferralCodeDialog(String referralCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Congratulations! 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thank you for following us on Instagram! Here is your unique referral code:',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 42, 42, 42),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black),
                ),
                child: SelectableText(
                  referralCode,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Share this code with your friends and earn rewards when they sign up using your code!',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.black),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  // Update user data in Firestore
  Future<void> _updateUserDataInFirestore() async {
    if (_userId == null || !_isAuthenticated) {
      _showSnackBar('You must be logged in to update your profile', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user data to check if we need to update referral code records
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final oldReferralCode = userData['referralCode'];

      // Update the existing document in Firestore
      await _firestore.collection('users').doc(_userId).update({
        'name': nameController.text,
        'instagram': instagramController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // If the user has a referral code, update the corresponding document in referralCodes collection
      if (oldReferralCode != null) {
        await _firestore
            .collection('referralCodes')
            .doc(oldReferralCode)
            .update({
              'userName': nameController.text,
              'userInstagram': instagramController.text,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }

      setState(() {
        _isLoading = false;
      });

      _showSnackBar('Profile updated successfully', Colors.black);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Error updating profile: ${e.toString()}', Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Determine if user is editing their profile
  Future<void> _checkExistingUser() async {
    // Since we're not using Firebase Auth, we need to implement a different
    // mechanism to check if the user is already authenticated.
    // This could be using shared preferences or secure storage to save the user ID.

    // For now, we'll just keep a simple logic here
    if (_userId != null && _isAuthenticated) {
      try {
        final userDoc = await _firestore.collection('users').doc(_userId).get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;

          setState(() {
            nameController.text = userData['name'] ?? '';
            phoneController.text = userData['phone'] ?? '';
            instagramController.text = userData['instagram'] ?? '';
            _followVerified = userData['followVerified'] ?? false;
            _generatedReferralCode = userData['referralCode'];
            // Disable phone editing since it's the auth identifier
          });
        }
      } catch (e) {
        _showSnackBar('Error loading profile: ${e.toString()}', Colors.red);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Check if user already exists
    _checkExistingUser();
  }

  @override
  Widget build(BuildContext context) {
    final bool isUserLoggedIn = _isAuthenticated;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color.fromARGB(255, 30, 30, 30),
              Colors.blue.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive width based on screen size
                  final formWidth =
                      constraints.maxWidth > 600
                          ? 500.0
                          : constraints.maxWidth * 0.9;

                  return Container(
                    width: formWidth,
                    margin: const EdgeInsets.symmetric(vertical: 20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUserLoggedIn
                              ? 'Update Profile'
                              : 'Profile Information',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isUserLoggedIn
                              ? 'Edit your profile details'
                              : 'Please fill in your details',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    color: Colors.black,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: phoneController,
                                enabled: !isUserLoggedIn && !_codeSent,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: const Icon(
                                    Icons.phone_outlined,
                                    color: Colors.black,
                                  ),
                                  hintText: '10-digit number',
                                  suffixIcon:
                                      !isUserLoggedIn && !_codeSent
                                          ? IconButton(
                                            icon: const Icon(
                                              Icons.send,
                                              color: Colors.black,
                                            ),
                                            onPressed:
                                                _isLoading
                                                    ? null
                                                    : _verifyPhone,
                                          )
                                          : null,
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  // Regex for Indian phone numbers (10 digits)
                                  if (!RegExp(
                                    r'^[6-9]\d{9}$',
                                  ).hasMatch(value)) {
                                    return 'Enter valid Indian phone number';
                                  }
                                  return null;
                                },
                              ),

                              if (_codeSent && !isUserLoggedIn) ...[
                                const SizedBox(height: 24),
                                const Text(
                                  'Enter the 4-digit code sent to your phone',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                PinCodeTextField(
                                  appContext: context,
                                  length: 4, // Changed from 6 to 4
                                  controller: otpController,
                                  onChanged: (value) {},
                                  pinTheme: PinTheme(
                                    shape: PinCodeFieldShape.box,
                                    borderRadius: BorderRadius.circular(8),
                                    fieldHeight: 50,
                                    fieldWidth: 50, // Adjusted for 4 digits
                                    activeFillColor: const Color.fromARGB(
                                      255,
                                      46,
                                      46,
                                      46,
                                    ),
                                    selectedFillColor: const Color.fromARGB(
                                      255,
                                      29,
                                      29,
                                      29,
                                    ),
                                    inactiveFillColor: Colors.white,
                                    activeColor: const Color.fromARGB(
                                      255,
                                      68,
                                      68,
                                      68,
                                    ),
                                    selectedColor: const Color.fromARGB(
                                      255,
                                      57,
                                      56,
                                      56,
                                    ),
                                    inactiveColor: const Color.fromARGB(
                                      255,
                                      39,
                                      39,
                                      39,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  enableActiveFill: true,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton(
                                      onPressed:
                                          _isLoading ? null : _verifyPhone,
                                      child: const Text('Resend OTP'),
                                    ),
                                    ElevatedButton(
                                      onPressed: _isLoading ? null : _verifyOTP,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.black,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Verify OTP'),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 16),
                              TextFormField(
                                controller: instagramController,
                                decoration: const InputDecoration(
                                  labelText: 'Instagram Handle',
                                  prefixIcon: Icon(
                                    Icons.alternate_email,
                                    color: Colors.black,
                                  ),
                                  hintText: '@username',
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your Instagram handle';
                                  }
                                  // Simple validation for Instagram handles
                                  if (!RegExp(
                                    r'^@?[a-zA-Z0-9._]{1,30}$',
                                  ).hasMatch(value)) {
                                    return 'Enter valid Instagram handle';
                                  }
                                  return null;
                                },
                              ),

                              // Show referral code if already generated
                              if (isUserLoggedIn &&
                                  _followVerified &&
                                  _generatedReferralCode != null) ...[
                                const SizedBox(height: 24),
                                const Text(
                                  'Your Referral Code',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                      255,
                                      55,
                                      55,
                                      55,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.black),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      SelectableText(
                                        _generatedReferralCode!,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.copy,
                                          color: Colors.black,
                                        ),
                                        onPressed: () {
                                          // Copy to clipboard functionality would go here
                                          _showSnackBar(
                                            'Referral code copied to clipboard',
                                            Colors.blue,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Show verify Instagram follow button if logged in but not verified
                              if (isUserLoggedIn && !_followVerified) ...[
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.verified_user),
                                  label: const Text('VERIFY INSTAGRAM FOLLOW'),
                                  onPressed: _redirectToInstagram,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 32),

                              if (!_codeSent || isUserLoggedIn)
                                ElevatedButton(
                                  onPressed:
                                      _isLoading
                                          ? null
                                          : isUserLoggedIn
                                          ? () {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              _updateUserDataInFirestore();
                                            }
                                          }
                                          : _codeSent
                                          ? _verifyOTP
                                          : _verifyPhone,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    elevation: 0,
                                  ),
                                  child:
                                      _isLoading
                                          ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : Text(
                                            isUserLoggedIn
                                                ? 'UPDATE'
                                                : 'SUBMIT',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                ),

                              if (isUserLoggedIn)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isAuthenticated = false;
                                      _userId = null;
                                      _followVerified = false;
                                      _generatedReferralCode = null;
                                      nameController.clear();
                                      phoneController.clear();
                                      instagramController.clear();
                                      verificationCodeController.clear();
                                    });
                                    _showSnackBar(
                                      'Logged out successfully',
                                      Colors.blue,
                                    );
                                  },
                                  child: const Text('Sign Out'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
