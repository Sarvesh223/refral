import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  String _selectedTimeRange = 'All Time';

  // Dashboard data
  int _totalUsers = 0;
  int _totalReferrals = 0;
  int _pendingVerifications = 0;
  int _activeReferralCodes = 0;
  List<Map<String, dynamic>> _topReferrers = [];
  List<Map<String, dynamic>> _recentUsers = [];
  List<Map<String, dynamic>> _referralCodes = [];

  // For search functionality
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredReferralCodes = [];

  // For verification modal
  final TextEditingController _verificationNoteController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _verificationNoteController.dispose();
    super.dispose();
  }

  // Load all dashboard data
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _fetchTotalUsers(),
        _fetchReferralStats(),
        _fetchTopReferrers(),
        _fetchRecentUsers(),
        _fetchReferralCodes(),
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      _showSnackBar(
        'Error loading dashboard data. Please try again.',
        Colors.red,
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fetch total number of users
  Future<void> _fetchTotalUsers() async {
    final QuerySnapshot usersSnapshot =
        await _firestore.collection('users').get();
    setState(() {
      _totalUsers = usersSnapshot.docs.length;
    });
  }

  // Fetch referral statistics
  Future<void> _fetchReferralStats() async {
    final QuerySnapshot referralCodesSnapshot =
        await _firestore.collection('referralCodes').get();

    // Count total referrals (sum of usageCount across all codes)
    int totalReferrals = 0;
    int activeReferralCodes = 0;

    for (var doc in referralCodesSnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      totalReferrals += (data['usageCount'] ?? 0) as int;
      if (data['isActive'] == true) {
        activeReferralCodes++;
      }
    }

    // Count pending verifications
    final QuerySnapshot pendingVerifications =
        await _firestore
            .collection('users')
            .where('followVerified', isEqualTo: false)
            .get();

    setState(() {
      _totalReferrals = totalReferrals;
      _pendingVerifications = pendingVerifications.docs.length;
      _activeReferralCodes = activeReferralCodes;
    });
  }

  // Fetch top referrers
  Future<void> _fetchTopReferrers() async {
    final QuerySnapshot referralCodesSnapshot =
        await _firestore
            .collection('referralCodes')
            .orderBy('usageCount', descending: true)
            .limit(5)
            .get();

    List<Map<String, dynamic>> topReferrers = [];

    for (var doc in referralCodesSnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      topReferrers.add({
        'id': doc.id,
        'userName': data['userName'] ?? 'Unknown',
        'userInstagram': data['userInstagram'] ?? 'N/A',
        'usageCount': data['usageCount'] ?? 0,
      });
    }

    setState(() {
      _topReferrers = topReferrers;
    });
  }

  // Fetch recent users
  Future<void> _fetchRecentUsers() async {
    final QuerySnapshot recentUsersSnapshot =
        await _firestore
            .collection('users')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();

    List<Map<String, dynamic>> recentUsers = [];

    for (var doc in recentUsersSnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // Convert Firestore timestamp to DateTime
      DateTime createdAt = DateTime.now();
      if (data['createdAt'] != null) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      }

      recentUsers.add({
        'id': doc.id,
        'name': data['name'] ?? 'Unknown',
        'phone': data['phone'] ?? 'N/A',
        'instagram': data['instagram'] ?? 'N/A',
        'followVerified': data['followVerified'] ?? false,
        'referralCode': data['referralCode'],
        'createdAt': createdAt,
      });
    }

    setState(() {
      _recentUsers = recentUsers;
    });
  }

  // Fetch all referral codes
  Future<void> _fetchReferralCodes() async {
    final QuerySnapshot referralCodesSnapshot =
        await _firestore
            .collection('referralCodes')
            .orderBy('createdAt', descending: true)
            .get();

    List<Map<String, dynamic>> referralCodes = [];

    for (var doc in referralCodesSnapshot.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // Convert Firestore timestamp to DateTime
      DateTime createdAt = DateTime.now();
      if (data['createdAt'] != null) {
        createdAt = (data['createdAt'] as Timestamp).toDate();
      }

      referralCodes.add({
        'id': doc.id,
        'code': doc.id,
        'userName': data['userName'] ?? 'Unknown',
        'userPhone': data['userPhone'] ?? 'N/A',
        'userInstagram': data['userInstagram'] ?? 'N/A',
        'usageCount': data['usageCount'] ?? 0,
        'isActive': data['isActive'] ?? true,
        'createdAt': createdAt,
        'usedBy': data['usedBy'] ?? [],
      });
    }

    setState(() {
      _referralCodes = referralCodes;
      _filteredReferralCodes = referralCodes;
    });
  }

  // Filter referral codes based on search query
  void _filterReferralCodes(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredReferralCodes = _referralCodes;
      });
      return;
    }

    final List<Map<String, dynamic>> filteredCodes =
        _referralCodes.where((code) {
          return code['code'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              code['userName'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              code['userPhone'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              code['userInstagram'].toString().toLowerCase().contains(
                query.toLowerCase(),
              );
        }).toList();

    setState(() {
      _filteredReferralCodes = filteredCodes;
    });
  }

  // Update referral code status (active/inactive)
  Future<void> _updateReferralCodeStatus(String codeId, bool isActive) async {
    try {
      await _firestore.collection('referralCodes').doc(codeId).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local state
      setState(() {
        for (int i = 0; i < _referralCodes.length; i++) {
          if (_referralCodes[i]['code'] == codeId) {
            _referralCodes[i]['isActive'] = isActive;
            break;
          }
        }

        for (int i = 0; i < _filteredReferralCodes.length; i++) {
          if (_filteredReferralCodes[i]['code'] == codeId) {
            _filteredReferralCodes[i]['isActive'] = isActive;
            break;
          }
        }
      });

      _showSnackBar(
        'Referral code ${isActive ? 'activated' : 'deactivated'} successfully',
        Colors.green,
      );
    } catch (e) {
      _showSnackBar('Error updating referral code: $e', Colors.red);
    }
  }

  // Verify user's Instagram follow
  Future<void> _verifyUserFollow(String userId, String note) async {
    try {
      // First, get the user document to check if they already have a referral code
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() as Map<String, dynamic>;

      if (userData['followVerified'] == true) {
        _showSnackBar('User is already verified', Colors.orange);
        return;
      }

      // Generate a unique referral code if not already generated
      String referralCode = userData['referralCode'];
      if (referralCode == null || referralCode.isEmpty) {
        // Generate code logic (simplified for this example)
        referralCode =
            'ADMIN${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      }

      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'followVerified': true,
        'referralCode': referralCode,
        'followVerifiedAt': FieldValue.serverTimestamp(),
        'verificationNote': note,
        'verifiedByAdmin': true,
      });

      // Check if referral code document exists, create if not
      final referralDoc =
          await _firestore.collection('referralCodes').doc(referralCode).get();

      if (!referralDoc.exists) {
        await _firestore.collection('referralCodes').doc(referralCode).set({
          'userId': userId,
          'userName': userData['name'] ?? 'Unknown',
          'userPhone': userData['phone'] ?? 'N/A',
          'userInstagram': userData['instagram'] ?? 'N/A',
          'createdAt': FieldValue.serverTimestamp(),
          'usedBy': [],
          'usageCount': 0,
          'isActive': true,
          'generatedByAdmin': true,
          'adminNote': note,
        });
      }

      _showSnackBar('User verified successfully', Colors.green);

      // Refresh dashboard data
      _loadDashboardData();
    } catch (e) {
      _showSnackBar('Error verifying user: $e', Colors.red);
    }
  }

  void _showVerificationModal(BuildContext context, Map<String, dynamic> user) {
    _verificationNoteController.text = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Verify ${user['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User: ${user['name']}'),
              Text('Phone: ${user['phone']}'),
              Text('Instagram: ${user['instagram']}'),
              SizedBox(height: 16),
              TextField(
                controller: _verificationNoteController,
                decoration: InputDecoration(
                  labelText: 'Verification Note (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _verifyUserFollow(user['id'], _verificationNoteController.text);
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.teal,
              ),
              child: Text('Verify User'),
            ),
          ],
        );
      },
    );
  }

  // Show user details modal
  void _showUserDetailsModal(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal.withOpacity(0.2),
                      radius: 25,
                      child: Icon(Icons.person, color: Colors.teal, size: 28),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Details',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user['name'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey[600],
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Divider(),
                SizedBox(height: 10),
                _buildInfoCard(
                  icon: Icons.phone_outlined,
                  title: 'Phone',
                  value: user['phone'] ?? 'N/A',
                ),
                _buildInfoCard(
                  icon: Icons.alternate_email,
                  title: 'Instagram',
                  value: user['instagram'] ?? 'N/A',
                ),
                _buildInfoCard(
                  icon:
                      user['followVerified']
                          ? Icons.verified
                          : Icons.pending_outlined,
                  title: 'Status',
                  value: user['followVerified'] ? 'Verified' : 'Not Verified',
                  valueColor:
                      user['followVerified'] ? Colors.green : Colors.orange,
                ),
                _buildInfoCard(
                  icon: Icons.code,
                  title: 'Referral Code',
                  value: user['referralCode'] ?? 'Not Generated',
                ),
                _buildInfoCard(
                  icon: Icons.calendar_today_outlined,
                  title: 'Joined On',
                  value: DateFormat('MMM dd, yyyy').format(user['createdAt']),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!user['followVerified'])
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Text('Cancel'),
                      ),
                    SizedBox(width: 10),
                    if (!user['followVerified'])
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showVerificationModal(context, user);
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Text('Verify User'),
                      ),
                    if (user['followVerified'])
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 12,
                          ),
                        ),
                        child: Text('Close'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.teal, size: 20),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReferralCodeDetailsModal(
    BuildContext context,
    Map<String, dynamic> code,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            width: double.maxFinite,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.teal.withOpacity(0.2),
                        radius: 25,
                        child: Icon(
                          Icons.card_giftcard,
                          color: Colors.teal,
                          size: 28,
                        ),
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Referral Code',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              code['isActive'] ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 16,
                                color:
                                    code['isActive']
                                        ? Colors.green
                                        : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.teal.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          code['code'],
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Colors.teal[700],
                          ),
                        ),
                        SizedBox(width: 10),
                        Icon(
                          code['isActive'] ? Icons.check_circle : Icons.cancel,
                          color: code['isActive'] ? Colors.green : Colors.red,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  Divider(),
                  SizedBox(height: 10),
                  _buildInfoCard(
                    icon: Icons.person_outline,
                    title: 'Generated By',
                    value: code['userName'] ?? 'N/A',
                  ),
                  _buildInfoCard(
                    icon: Icons.phone_outlined,
                    title: 'Phone',
                    value: code['userPhone'] ?? 'N/A',
                  ),
                  _buildInfoCard(
                    icon: Icons.alternate_email,
                    title: 'Instagram',
                    value: code['userInstagram'] ?? 'N/A',
                  ),
                  _buildInfoCard(
                    icon: Icons.people_outline,
                    title: 'Uses',
                    value: code['usageCount'].toString(),
                  ),
                  _buildInfoCard(
                    icon: Icons.calendar_today_outlined,
                    title: 'Generated On',
                    value: DateFormat('MMM dd, yyyy').format(code['createdAt']),
                  ),
                  if ((code['usedBy'] as List).isNotEmpty) ...[
                    SizedBox(height: 10),
                    Divider(),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.groups_outlined, color: Colors.teal),
                        SizedBox(width: 10),
                        Text(
                          'Used By',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    ...List.generate(
                      (code['usedBy'] as List).length,
                      (index) => Container(
                        margin: EdgeInsets.only(bottom: 10),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.teal,
                              child: Text(
                                (index + 1).toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    code['usedBy'][index]['name'] ??
                                        'Unknown User',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    code['usedBy'][index]['phone'] ?? 'N/A',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
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
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Text('Cancel'),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _updateReferralCodeStatus(
                            code['code'],
                            !code['isActive'],
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor:
                              code['isActive'] ? Colors.red : Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          code['isActive'] ? 'Deactivate' : 'Activate',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                builder: (context, constraints) {
                  return _buildDashboard(constraints);
                },
              ),
    );
  }

  Widget _buildDashboard(BoxConstraints constraints) {
    // Determine layout based on screen width
    final bool isLargeScreen = constraints.maxWidth > 1200;
    final bool isMediumScreen =
        constraints.maxWidth > 800 && constraints.maxWidth <= 1200;

    if (isLargeScreen) {
      return _buildLargeScreenDashboard();
    } else if (isMediumScreen) {
      return _buildMediumScreenDashboard();
    } else {
      return _buildSmallScreenDashboard();
    }
  }

  Widget _buildLargeScreenDashboard() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Monitor your referral program performance',
            style: TextStyle(fontSize: 16, color: Colors.blueGrey.shade600),
          ),
          SizedBox(height: 32),
          _buildStatsCardRow(),
          SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildTopReferrersCard()),
              SizedBox(width: 24),
              Expanded(flex: 3, child: _buildRecentUsersCard()),
            ],
          ),
          SizedBox(height: 32),
          _buildReferralCodesTable(),
        ],
      ),
    );
  }

  Widget _buildMediumScreenDashboard() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Monitor your referral program performance',
            style: TextStyle(fontSize: 16, color: Colors.blueGrey.shade600),
          ),
          SizedBox(height: 32),
          _buildStatsCardRow(),
          SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTopReferrersCard()),
              SizedBox(width: 24),
              Expanded(child: _buildRecentUsersCard()),
            ],
          ),
          SizedBox(height: 32),
          _buildReferralCodesTable(),
        ],
      ),
    );
  }

  Widget _buildSmallScreenDashboard() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Monitor your referral program performance',
            style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade600),
          ),
          SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: _buildStatsCardRow(),
          ),
          SizedBox(height: 24),
          _buildTopReferrersCard(),
          SizedBox(height: 24),
          _buildRecentUsersCard(),
          SizedBox(height: 24),
          _buildReferralCodesTable(),
        ],
      ),
    );
  }

  Widget _buildStatsCardRow() {
    return Row(
      children: [
        _buildStatCard(
          'Total Users',
          _totalUsers.toString(),
          Icons.people_alt_rounded,
          LinearGradient(
            colors: [Color(0xFF5B86E5), Color(0xFF36D1DC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        SizedBox(width: 20),
        _buildStatCard(
          'Total Referrals',
          _totalReferrals.toString(),
          Icons.share_rounded,
          LinearGradient(
            colors: [Color(0xFF00B09B), Color(0xFF96C93D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        SizedBox(width: 20),
        _buildStatCard(
          'Pending Verifications',
          _pendingVerifications.toString(),
          Icons.pending_actions_rounded,
          LinearGradient(
            colors: [Color(0xFFF2994A), Color(0xFFF2C94C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        SizedBox(width: 20),
        _buildStatCard(
          'Active Codes',
          _activeReferralCodes.toString(),
          Icons.qr_code_rounded,
          LinearGradient(
            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    LinearGradient gradient,
  ) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
          color: Colors.white,
        ),
        padding: EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: gradient,
              ),
              child: Center(child: Icon(icon, color: Colors.white, size: 28)),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopReferrersCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Top Referrers',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _topReferrers.isEmpty
              ? Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No referrals yet',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'When users start referring others, they\'ll appear here',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
              : ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: min(_topReferrers.length, 5),
                separatorBuilder:
                    (context, index) => Divider(
                      height: 32,
                      thickness: 1,
                      color: Colors.grey.shade100,
                    ),
                itemBuilder: (context, index) {
                  final user = _topReferrers[index];
                  return Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors:
                                index == 0
                                    ? [Color(0xFFFFD700), Color(0xFFFFC400)]
                                    : index == 1
                                    ? [Color(0xFFC0C0C0), Color(0xFFE0E0E0)]
                                    : index == 2
                                    ? [Color(0xFFCD7F32), Color(0xFFDEA47E)]
                                    : [
                                      Colors.blueGrey.shade200,
                                      Colors.blueGrey.shade300,
                                    ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['userName'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blueGrey.shade800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '@${user['userInstagram']}',
                              style: TextStyle(
                                color: Colors.blueGrey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          '${user['usageCount']} referrals',
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _buildRecentUsersCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Users',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          _recentUsers.isEmpty
              ? Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No users yet',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'New users will appear here when they join',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
              : ListView.separated(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: min(_recentUsers.length, 5),
                separatorBuilder:
                    (context, index) => Divider(
                      height: 24,
                      thickness: 1,
                      color: Colors.grey.shade100,
                    ),
                itemBuilder: (context, index) {
                  final user = _recentUsers[index];
                  return InkWell(
                    onTap: () => _showUserDetailsModal(context, user),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue.withOpacity(0.1),
                            ),
                            child: Center(
                              child: Text(
                                user['name'].substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blueGrey.shade800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Joined ${DateFormat('MMM dd, yyyy').format(user['createdAt'])}',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  user['followVerified']
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              user['followVerified'] ? 'Verified' : 'Pending',
                              style: TextStyle(
                                color:
                                    user['followVerified']
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _buildReferralCodesTable() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'All Referral Codes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              
            ],
          ),
          SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blueGrey.shade200),
              color: Colors.grey.shade50,
            ),
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by code, name, phone or Instagram...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.blueGrey.shade400),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: _filterReferralCodes,
            ),
          ),
          SizedBox(height: 20),
          _filteredReferralCodes.isEmpty
              ? Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.qr_code_scanner_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No referral codes found',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Try adjusting your search terms',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
              : Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 480,
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.grey.shade100),
                      child: DataTable2(
                        columnSpacing: 16,
                        horizontalMargin: 16,
                        minWidth: 600,
                        headingRowColor: MaterialStateProperty.all(
                          Colors.grey.shade50,
                        ),
                        columns: [
                          DataColumn2(
                            label: Text(
                              'Code',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                            size: ColumnSize.M,
                          ),
                          DataColumn2(
                            label: Text(
                              'User',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                            size: ColumnSize.L,
                          ),
                          DataColumn2(
                            label: Text(
                              'Instagram',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                            size: ColumnSize.M,
                          ),
                          DataColumn2(
                            label: Text(
                              'Uses',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                            size: ColumnSize.S,
                            numeric: true,
                          ),
                          DataColumn2(
                            label: Text(
                              'Status',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                            size: ColumnSize.S,
                          ),
                          DataColumn2(
                            label: Text(
                              'Actions',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade700,
                              ),
                            ),
                            size: ColumnSize.S,
                          ),
                        ],
                        rows: List<DataRow>.generate(
                          _filteredReferralCodes.length,
                          (index) {
                            final code = _filteredReferralCodes[index];
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    code['code'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueGrey.shade800,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    code['userName'],
                                    style: TextStyle(
                                      color: Colors.blueGrey.shade700,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '@${code['userInstagram']}',
                                    style: TextStyle(
                                      color: Colors.blueGrey.shade700,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${code['usageCount']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          code['isActive']
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      code['isActive'] ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        color:
                                            code['isActive']
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.info_outline_rounded,
                                          size: 20,
                                        ),
                                        color: Colors.blue.shade600,
                                        onPressed:
                                            () => _showReferralCodeDetailsModal(
                                              context,
                                              code,
                                            ),
                                        tooltip: 'View Details',
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          code['isActive']
                                              ? Icons.block_rounded
                                              : Icons
                                                  .check_circle_outline_rounded,
                                          size: 20,
                                        ),
                                        color:
                                            code['isActive']
                                                ? Colors.red.shade600
                                                : Colors.green.shade600,
                                        onPressed:
                                            () => _updateReferralCodeStatus(
                                              code['code'],
                                              !code['isActive'],
                                            ),
                                        tooltip:
                                            code['isActive']
                                                ? 'Deactivate'
                                                : 'Activate',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
