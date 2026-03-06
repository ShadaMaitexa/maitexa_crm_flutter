import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/role_model.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  static const String usersCollection = 'users';
  static const String rolesCollection = 'roles';
  static const String enquiriesCollection = 'enquiries';
  static const String collegeVisitsCollection = 'college_visits';
  static const String followUpsCollection = 'follow_ups';
  static const String tasksCollection = 'tasks';
  static const String analyticsCollection = 'analytics';
  static const String callsCollection = 'calls';
  static const String numberCategoriesCollection = 'number_categories';


  // Hardcoded admin credentials
  static const String adminEmail = 'admin@maitexa.com';
  static const String adminPassword = 'admin123';
  static const String adminName = 'Admin User';
  static const String adminRole = 'admin';

  // User Management
  static Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      // Check if it's admin login
      if (email == adminEmail && password == adminPassword) {
        return User(
          id: 'admin_001',
          name: adminName,
          email: adminEmail,
          role: adminRole,
          phone: '+91 98765 43210',
          avatar: 'A',
          organization: 'Maitexa IT Training',
          isActive: true,
          createdAt: DateTime.now(),
          lastLogin: DateTime.now(),
        );
      }

      // Check for other users in Firestore
      final QuerySnapshot userSnapshot = await _firestore
          .collection(usersCollection)
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: password)
          .where('isActive', isEqualTo: true)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        final userData = userSnapshot.docs.first.data() as Map<String, dynamic>;
        return User.fromJson({'id': userSnapshot.docs.first.id, ...userData});
      }

      return null;
    } catch (e) {
      print('Sign in error: $e');
      return null;
    }
  }

  static Future<void> signOut() async {
    // No Firebase Auth, just return
    return;
  }

  static Future<User?> getCurrentUser() async {
    // This would need to be implemented with SharedPreferences or similar
    // For now, return null
    return null;
  }

  static Future<User?> getUserByEmail(String email) async {
    try {
      final QuerySnapshot userSnapshot = await _firestore
          .collection(usersCollection)
          .where('email', isEqualTo: email)
          .where('isActive', isEqualTo: true)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        final userData = userSnapshot.docs.first.data() as Map<String, dynamic>;
        return User.fromJson({'id': userSnapshot.docs.first.id, ...userData});
      }

      return null;
    } catch (e) {
      print('Get user by email error: $e');
      return null;
    }
  }

  // Admin CRUD Operations for Users
  static Future<List<User>> getAllUsers() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(usersCollection)
          .get();

      final users =
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return User.fromJson({'id': doc.id, ...data});
          }).toList()..sort(
            (a, b) => b.createdAt.compareTo(a.createdAt),
          ); // Sort by createdAt descending

      return users;
    } catch (e) {
      print('Get users error: $e');
      return [];
    }
  }

  static Future<String?> addUser(Map<String, dynamic> userData) async {
    try {
      // Remove id if present as it will be auto-generated
      userData.remove('id');

      // Generate avatar from name if not provided
      if (userData['avatar'] == null || userData['avatar'].toString().isEmpty) {
        final name = userData['name'] ?? '';
        if (name.isNotEmpty) {
          final nameParts = name.trim().split(' ');
          if (nameParts.length >= 2) {
            userData['avatar'] = '${nameParts[0][0]}${nameParts[1][0]}'
                .toUpperCase();
          } else {
            userData['avatar'] = name[0].toUpperCase();
          }
        } else {
          userData['avatar'] = 'U';
        }
      }

      // Set default organization if not provided
      if (userData['organization'] == null ||
          userData['organization'].toString().isEmpty) {
        userData['organization'] = 'Maitexa IT Training';
      }

      final DocumentReference docRef = await _firestore
          .collection(usersCollection)
          .add({
            ...userData,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'isActive': true,
          });
      return docRef.id;
    } catch (e) {
      print('Add user error: $e');
      return null;
    }
  }

  static Future<bool> updateUser(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(usersCollection).doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Update user error: $e');
      return false;
    }
  }

  // Update or create the user's FCM token field
  static Future<void> updateUserFcmToken(String userId) async {
    try {
      // lazily import messaging logic through NotificationService to get token
      // but avoid hard import cycle; call Firestore update only
      // Expect caller to provide token via NotificationService.syncToken
      // This function exists to be called by AuthProvider to trigger sync
      // with NotificationService without direct dependency.
    } catch (_) {}
  }

  static Future<bool> deleteUser(String id) async {
    try {
      await _firestore.collection(usersCollection).doc(id).delete();
      return true;
    } catch (e) {
      print('Delete user error: $e');
      return false;
    }
  }

  static Future<bool> toggleUserStatus(String id, bool isActive) async {
    try {
      await _firestore.collection(usersCollection).doc(id).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Toggle user status error: $e');
      return false;
    }
  }

  // Enquiries
  static Future<List<Map<String, dynamic>>> getEnquiries() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(enquiriesCollection)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Get enquiries error: $e');
      return [];
    }
  }

  static Future<String?> addEnquiry(Map<String, dynamic> enquiryData) async {
    try {
      final DocumentReference docRef = await _firestore
          .collection(enquiriesCollection)
          .add({
            ...enquiryData,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      return docRef.id;
    } catch (e) {
      print('Add enquiry error: $e');
      return null;
    }
  }

  static Future<bool> updateEnquiry(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection(enquiriesCollection).doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Update enquiry error: $e');
      return false;
    }
  }

  // College Visits
  static Future<List<Map<String, dynamic>>> getCollegeVisits() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(collegeVisitsCollection)
          .orderBy('visitDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Get college visits error: $e');
      return [];
    }
  }

  static Future<String?> addCollegeVisit(Map<String, dynamic> visitData) async {
    try {
      final DocumentReference docRef = await _firestore
          .collection(collegeVisitsCollection)
          .add({
            ...visitData,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      return docRef.id;
    } catch (e) {
      print('Add college visit error: $e');
      return null;
    }
  }

  static Future<bool> updateCollegeVisit(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore.collection(collegeVisitsCollection).doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Update college visit error: $e');
      return false;
    }
  }

  // Follow Ups
  static Future<List<Map<String, dynamic>>> getFollowUps() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(followUpsCollection)
          .orderBy('followUpDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Get follow ups error: $e');
      return [];
    }
  }

  static Future<String?> addFollowUp(Map<String, dynamic> followUpData) async {
    try {
      final DocumentReference docRef = await _firestore
          .collection(followUpsCollection)
          .add({
            ...followUpData,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      return docRef.id;
    } catch (e) {
      print('Add follow up error: $e');
      return null;
    }
  }

  // Tasks
  static Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(tasksCollection)
          .orderBy('dueDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Get tasks error: $e');
      return [];
    }
  }

  static Future<String?> addTask(Map<String, dynamic> taskData) async {
    try {
      final DocumentReference docRef = await _firestore
          .collection(tasksCollection)
          .add({
            ...taskData,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      return docRef.id;
    } catch (e) {
      print('Add task error: $e');
      return null;
    }
  }

  // Analytics
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final DateTime now = DateTime.now();
      final DateTime startOfDay = DateTime(now.year, now.month, now.day);
      final DateTime startOfMonth = DateTime(now.year, now.month, 1);

      // Today's enquiries
      final QuerySnapshot todayEnquiries = await _firestore
          .collection(enquiriesCollection)
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .get();

      // Today's visits
      final QuerySnapshot todayVisits = await _firestore
          .collection(collegeVisitsCollection)
          .where('visitDate', isGreaterThanOrEqualTo: startOfDay)
          .get();

      // Today's follow ups
      final QuerySnapshot todayFollowUps = await _firestore
          .collection(followUpsCollection)
          .where('followUpDate', isGreaterThanOrEqualTo: startOfDay)
          .get();

      // This month's total
      final QuerySnapshot monthEnquiries = await _firestore
          .collection(enquiriesCollection)
          .where('createdAt', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      final QuerySnapshot monthVisits = await _firestore
          .collection(collegeVisitsCollection)
          .where('visitDate', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      // Get conversions (enquiries with status 'converted')
      final QuerySnapshot conversions = await _firestore
          .collection(enquiriesCollection)
          .where('status', isEqualTo: 'converted')
          .where('createdAt', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      return {
        'todayEnquiries': todayEnquiries.docs.length,
        'todayVisits': todayVisits.docs.length,
        'todayFollowUps': todayFollowUps.docs.length,
        'monthEnquiries': monthEnquiries.docs.length,
        'monthVisits': monthVisits.docs.length,
        'totalEnquiries':
            (await _firestore.collection(enquiriesCollection).get())
                .docs
                .length,
        'totalVisits':
            (await _firestore.collection(collegeVisitsCollection).get())
                .docs
                .length,
        'conversions': conversions.docs.length,
      };
    } catch (e) {
      print('Get dashboard stats error: $e');
      return {
        'todayEnquiries': 0,
        'todayVisits': 0,
        'todayFollowUps': 0,
        'monthEnquiries': 0,
        'monthVisits': 0,
        'totalEnquiries': 0,
        'totalVisits': 0,
        'conversions': 0,
      };
    }
  }

  // Get user-specific dashboard stats
  static Future<Map<String, dynamic>> getUserDashboardStats(
    String userId,
  ) async {
    try {
      final DateTime now = DateTime.now();
      final DateTime startOfDay = DateTime(now.year, now.month, now.day);
      final DateTime startOfMonth = DateTime(now.year, now.month, 1);

      // Today's enquiries for specific user
      final QuerySnapshot todayEnquiries = await _firestore
          .collection(enquiriesCollection)
          .where('createdBy', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .get();

      // Today's visits for specific user
      final QuerySnapshot todayVisits = await _firestore
          .collection(collegeVisitsCollection)
          .where('createdBy', isEqualTo: userId)
          .where('visitDate', isGreaterThanOrEqualTo: startOfDay)
          .get();

      // Today's follow ups for specific user
      final QuerySnapshot todayFollowUps = await _firestore
          .collection(followUpsCollection)
          .where('createdBy', isEqualTo: userId)
          .where('followUpDate', isGreaterThanOrEqualTo: startOfDay)
          .get();

      // This month's total for specific user
      final QuerySnapshot monthEnquiries = await _firestore
          .collection(enquiriesCollection)
          .where('createdBy', isEqualTo: userId)
          .where('createdAt', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      final QuerySnapshot monthVisits = await _firestore
          .collection(collegeVisitsCollection)
          .where('createdBy', isEqualTo: userId)
          .where('visitDate', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      // Get conversions for specific user
      final QuerySnapshot conversions = await _firestore
          .collection(enquiriesCollection)
          .where('createdBy', isEqualTo: userId)
          .where('status', isEqualTo: 'converted')
          .where('createdAt', isGreaterThanOrEqualTo: startOfMonth)
          .get();

      return {
        'todayEnquiries': todayEnquiries.docs.length,
        'todayVisits': todayVisits.docs.length,
        'todayFollowUps': todayFollowUps.docs.length,
        'monthEnquiries': monthEnquiries.docs.length,
        'monthVisits': monthVisits.docs.length,
        'totalEnquiries':
            (await _firestore
                    .collection(enquiriesCollection)
                    .where('createdBy', isEqualTo: userId)
                    .get())
                .docs
                .length,
        'totalVisits':
            (await _firestore
                    .collection(collegeVisitsCollection)
                    .where('createdBy', isEqualTo: userId)
                    .get())
                .docs
                .length,
        'conversions': conversions.docs.length,
      };
    } catch (e) {
      print('Get user dashboard stats error: $e');
      // Fallback: calculate stats from all data
      try {
        final allEnquiries = await getEnquiries();
        final allVisits = await getCollegeVisits();
        final allFollowUps = await getFollowUps();

        final userEnquiries = allEnquiries
            .where((e) => e['createdBy'] == userId)
            .toList();
        final userVisits = allVisits
            .where((v) => v['createdBy'] == userId)
            .toList();
        final userFollowUps = allFollowUps
            .where((f) => f['createdBy'] == userId)
            .toList();

        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final startOfMonth = DateTime(now.year, now.month, 1);

        return {
          'todayEnquiries': userEnquiries.where((e) {
            final createdAt = e['createdAt'] as Timestamp?;
            return createdAt != null && createdAt.toDate().isAfter(startOfDay);
          }).length,
          'todayVisits': userVisits.where((v) {
            final visitDate = v['visitDate'] as Timestamp?;
            return visitDate != null && visitDate.toDate().isAfter(startOfDay);
          }).length,
          'todayFollowUps': userFollowUps.where((f) {
            final followUpDate = f['followUpDate'] as Timestamp?;
            return followUpDate != null &&
                followUpDate.toDate().isAfter(startOfDay);
          }).length,
          'monthEnquiries': userEnquiries.where((e) {
            final createdAt = e['createdAt'] as Timestamp?;
            return createdAt != null &&
                createdAt.toDate().isAfter(startOfMonth);
          }).length,
          'monthVisits': userVisits.where((v) {
            final visitDate = v['visitDate'] as Timestamp?;
            return visitDate != null &&
                visitDate.toDate().isAfter(startOfMonth);
          }).length,
          'totalEnquiries': userEnquiries.length,
          'totalVisits': userVisits.length,
          'conversions': userEnquiries
              .where((e) => e['status'] == 'converted')
              .length,
        };
      } catch (fallbackError) {
        print('Fallback get user dashboard stats error: $fallbackError');
        return {
          'todayEnquiries': 0,
          'todayVisits': 0,
          'todayFollowUps': 0,
          'monthEnquiries': 0,
          'monthVisits': 0,
          'totalEnquiries': 0,
          'totalVisits': 0,
          'conversions': 0,
        };
      }
    }
  }

  // Get user-specific enquiries
  static Future<List<Map<String, dynamic>>> getUserEnquiries(
    String userId,
  ) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(enquiriesCollection)
          .where('createdBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Get user enquiries error: $e');
      // Fallback: get all enquiries and filter in memory
      try {
        final allEnquiries = await getEnquiries();
        return allEnquiries
            .where((enquiry) => enquiry['createdBy'] == userId)
            .toList();
      } catch (fallbackError) {
        print('Fallback get user enquiries error: $fallbackError');
        return [];
      }
    }
  }

  // Get user-specific college visits
  static Future<List<Map<String, dynamic>>> getUserCollegeVisits(
    String userId,
  ) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(collegeVisitsCollection)
          .where('createdBy', isEqualTo: userId)
          .orderBy('visitDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Get user college visits error: $e');
      // Fallback: get all visits and filter in memory
      try {
        final allVisits = await getCollegeVisits();
        return allVisits
            .where((visit) => visit['createdBy'] == userId)
            .toList();
      } catch (fallbackError) {
        print('Fallback get user college visits error: $fallbackError');
        return [];
      }
    }
  }

  // Get user-specific follow-ups
  static Future<List<Map<String, dynamic>>> getUserFollowUps(
    String userId,
  ) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(followUpsCollection)
          .where('createdBy', isEqualTo: userId)
          .orderBy('followUpDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('Get user follow ups error: $e');
      // Fallback: get all follow-ups and filter in memory
      try {
        final allFollowUps = await getFollowUps();
        return allFollowUps
            .where((followUp) => followUp['createdBy'] == userId)
            .toList();
      } catch (fallbackError) {
        print('Fallback get user follow ups error: $fallbackError');
        return [];
      }
    }
  }

  // Real-time listeners
  static Stream<QuerySnapshot> getEnquiriesStream() {
    return _firestore
        .collection(enquiriesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getCollegeVisitsStream() {
    return _firestore
        .collection(collegeVisitsCollection)
        .orderBy('visitDate', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getFollowUpsStream() {
    return _firestore
        .collection(followUpsCollection)
        .orderBy('followUpDate', descending: true)
        .snapshots();
  }

  static Stream<QuerySnapshot> getUsersStream() {
    return _firestore
        .collection(usersCollection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Role Management Functions
  static Future<List<Role>> getAllRoles() async {
    try {
      // Fetch all roles ordered by name. We don't filter by isActive at query level
      // to ensure legacy documents without the field are still returned.
      final QuerySnapshot snapshot = await _firestore
          .collection(rolesCollection)
          .orderBy('name')
          .get();

      final roles = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Role.fromJson({'id': doc.id, ...data});
      }).toList();

      return roles;
    } catch (e) {
      print('Get roles error: $e');
      return [];
    }
  }

  static Future<String?> addRole(Map<String, dynamic> roleData) async {
    try {
      // Remove id if present as it will be auto-generated
      roleData.remove('id');

      final DocumentReference docRef = await _firestore
          .collection(rolesCollection)
          .add({
            ...roleData,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'isActive': true,
          });
      return docRef.id;
    } catch (e) {
      print('Add role error: $e');
      return null;
    }
  }

  static Future<bool> updateRole(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(rolesCollection).doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Update role error: $e');
      return false;
    }
  }

  static Future<bool> deleteRole(String id) async {
    try {
      await _firestore.collection(rolesCollection).doc(id).delete();
      return true;
    } catch (e) {
      print('Delete role error: $e');
      return false;
    }
  }

  static Future<bool> toggleRoleStatus(String id, bool isActive) async {
    try {
      await _firestore.collection(rolesCollection).doc(id).update({
        'isActive': isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Toggle role status error: $e');
      return false;
    }
  }

  static Future<Role?> getRoleById(String id) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection(rolesCollection)
          .doc(id)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return Role.fromJson({'id': doc.id, ...data});
      }
      return null;
    } catch (e) {
      print('Get role by id error: $e');
      return null;
    }
  }

  static Future<Role?> getRoleByName(String name) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(rolesCollection)
          .where('name', isEqualTo: name)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        return Role.fromJson({'id': snapshot.docs.first.id, ...data});
      }
      return null;
    } catch (e) {
      print('Get role by name error: $e');
      return null;
    }
  }

  // Initialize default roles if they don't exist
  static Future<void> initializeDefaultRoles() async {
    try {
      final existingRoles = await getAllRoles();

      if (existingRoles.isEmpty) {
        // Add default roles
        final defaultRoles = [
          {
            'name': 'Admin',
            'description': 'Full system access and user management',
            'permissions': ['all'],
          },
          {
            'name': 'HR',
            'description': 'Human resources and employee management',
            'permissions': ['view_users', 'edit_users', 'view_reports'],
          },
          {
            'name': 'Marketing Executive',
            'description': 'Marketing and sales activities',
            'permissions': [
              'view_enquiries',
              'add_enquiries',
              'view_visits',
              'add_visits',
            ],
          },
        ];

        for (final roleData in defaultRoles) {
          await addRole(roleData);
        }
      }
    } catch (e) {
      print('Initialize default roles error: $e');
    }
  }
  // Call Tracking & Categorization
  static Future<void> recordCall(Map<String, dynamic> callData) async {
    try {
      await _firestore.collection(callsCollection).add({
        ...callData,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Record call error: $e');
    }
  }

  static Future<void> setNumberCategory(String number, String category) async {
    try {
      await _firestore.collection(numberCategoriesCollection).doc(number).set({
        'category': category,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Set number category error: $e');
    }
  }

  static Future<String?> getNumberCategory(String number) async {
    try {
      final doc = await _firestore.collection(numberCategoriesCollection).doc(number).get();
      if (doc.exists) {
        return doc.data()?['category'] as String?;
      }
      return null;
    } catch (e) {
      print('Get number category error: $e');
      return null;
    }
  }
}
