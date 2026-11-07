import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

const List<String> collegeDepartments = ['CSE', 'DS', 'Civil', 'Electrical'];
const List<String> academicYears = [
  'First Year (FY)',
  'Second Year (SY)',
  'Third Year (TY)',
  'Final Year',
];
const Color brandColor = Color(0xFF174A8B);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CollegeConnectApp());
}

class CollegeConnectApp extends StatelessWidget {
  const CollegeConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'College Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: brandColor,
        scaffoldBackgroundColor: const Color(0xFFF4F7FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: brandColor,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, auth) {
        if (auth.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }
        final user = auth.data;
        if (user == null) return const LoginScreen();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, profile) {
            if (profile.connectionState == ConnectionState.waiting) {
              return const LoadingScreen();
            }
            if (profile.hasError) {
              return ErrorScreen(message: 'Profile load failed: ${profile.error}');
            }
            if (!profile.hasData || !profile.data!.exists) {
              return const ErrorScreen(
                message: 'User profile not found. Contact College Admin.',
              );
            }

            final data = profile.data!.data()!;
            final role = (data['role'] ?? '').toString();
            final status = (data['status'] ?? '').toString();

            if (status == 'pending') return const PendingScreen();
            if (status == 'rejected') return const RejectedScreen();
            if (status != 'active') {
              return const ErrorScreen(
                message: 'Your account status is invalid. Contact Admin.',
              );
            }

            switch (role) {
              case 'admin':
                return AdminDashboard(userData: data);
              case 'hod':
                return HODDashboard(userData: data);
              case 'teacher':
                return TeacherDashboard(userData: data);
              case 'student':
                return StudentDashboard(userData: data);
              default:
                return const ErrorScreen(
                  message: 'Unknown account role. Contact Admin.',
                );
            }
          },
        );
      },
    );
  }
}

// ------------------------------ LOGIN ---------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool hidePassword = true;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      showMessage(context, 'Please enter email and password.');
      return;
    }

    setState(() => loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) showMessage(context, e.message ?? 'Login failed.');
    } catch (e) {
      if (mounted) showMessage(context, 'Login error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> forgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      showMessage(context, 'Enter your email address first.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) showMessage(context, 'Password reset email sent.');
    } on FirebaseAuthException catch (e) {
      if (mounted) showMessage(context, e.message ?? 'Reset email failed.');
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 38,
                      backgroundColor: brandColor,
                      child: Icon(Icons.school, color: Colors.white, size: 42),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'COLLEGE CONNECT',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: brandColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('D. Y. Patil College, Salokhe Nagar'),
                    const SizedBox(height: 28),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => hidePassword = !hidePassword),
                          icon: Icon(hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: forgotPassword,
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: loading ? null : login,
                        child: loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('LOGIN'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      ),
                      child: const Text('New Student? Create Account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------- STUDENT REGISTRATION ----------------------------

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final rollNumberController = TextEditingController();
  final mobileController = TextEditingController();

  String? selectedDepartment;
  String? selectedYear;
  bool loading = false;
  bool hidePassword = true;

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final rollNumber = rollNumberController.text.trim();
    final mobile = mobileController.text.trim();
    final department = selectedDepartment;
    final year = selectedYear;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        rollNumber.isEmpty ||
        mobile.isEmpty ||
        department == null ||
        year == null) {
      showMessage(context, 'Please complete all fields.');
      return;
    }
    if (password.length < 6) {
      showMessage(context, 'Password must contain at least 6 characters.');
      return;
    }
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(mobile)) {
      showMessage(context, 'Enter a valid 10-digit Indian mobile number.');
      return;
    }
    if (!RegExp(r'^[0-9]{1,4}$').hasMatch(rollNumber)) {
      showMessage(context, 'Enter a valid roll number (digits only).');
      return;
    }

    setState(() => loading = true);
    UserCredential? credential;
    try {
      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'mobile': mobile,
        'rollNumber': rollNumber,
        'year': year,
        'role': 'student',
        'department': department,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      showMessage(
        context,
        'Registration submitted. Wait for your Department HOD approval.',
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (mounted) showMessage(context, e.message ?? 'Registration failed.');
    } on FirebaseException catch (e) {
      try {
        if (credential?.user != null) {
          await credential!.user!.delete();
        }
      } catch (_) {
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
      }
      if (mounted) {
        showMessage(
          context,
          'Firestore error [${e.code}]: ${e.message ?? 'Could not save registration.'}',
        );
      }
    } catch (e) {
      if (mounted) showMessage(context, 'Registration error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    rollNumberController.dispose();
    mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Registration')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const Icon(Icons.person_add_alt_1,
                        size: 55, color: brandColor),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedDepartment,
                      decoration: const InputDecoration(
                        labelText: 'Select Department',
                        prefixIcon: Icon(Icons.apartment),
                      ),
                      items: collegeDepartments
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: loading
                          ? null
                          : (v) => setState(() => selectedDepartment = v),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: rollNumberController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Roll Number',
                        prefixIcon: Icon(Icons.numbers),
                        hintText: 'Enter roll number',
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Academic Year',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: academicYears
                          .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                          .toList(),
                      onChanged: loading
                          ? null
                          : (v) => setState(() => selectedYear = v),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number',
                        prefixIcon: Icon(Icons.phone_android),
                        prefixText: '+91 ',
                        counterText: '',
                        hintText: '10-digit mobile number',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      obscureText: hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password (minimum 6 characters)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => hidePassword = !hidePassword),
                          icon: Icon(hidePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: loading ? null : register,
                        child: loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('SUBMIT REGISTRATION'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your account will remain pending until your Department HOD reviews it.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------- DASHBOARDS ---------------------------------

class AdminDashboard extends StatelessWidget {
  final Map<String, dynamic> userData;
  const AdminDashboard({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      title: 'Admin Dashboard',
      name: (userData['name'] ?? 'Admin').toString(),
      role: 'Super Administrator',
      headerIcon: Icons.admin_panel_settings,
      modules: const [
        'Department Management',
        'HOD Management',
        'Student Management',
        'Teacher Management',
        'T.P.O. Department',
        'Exam Department',
        'Fees Management',
        'Attendance Monitoring',
        'Certificates',
        'Library Management',
        'Transport Management',
        'Scholarships',
        'Events & Notices',
        'Reports & Analytics',
        'Settings',
      ],
    );
  }
}

class HODDashboard extends StatelessWidget {
  final Map<String, dynamic> userData;
  const HODDashboard({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final department = (userData['department'] ?? '').toString();
    return DashboardLayout(
      title: '$department HOD Dashboard',
      name: (userData['name'] ?? 'HOD').toString(),
      role: '$department Department Head',
      headerIcon: Icons.account_balance,
      extraHeader: Column(
        children: [
          HODPendingApprovalCard(department: department),
          const SizedBox(height: 10),
          HODProfileRequestCard(department: department),
        ],
      ),
      modules: const [
        'Student Management',
        'Teacher Management',
        'Department Notices',
        'Attendance Monitoring',
        'Student Performance',
        'Department Reports',
        'My Profile',
      ],
    );
  }
}

class HODPendingApprovalCard extends StatelessWidget {
  final String department;
  const HODPendingApprovalCard({super.key, required this.department});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('status', isEqualTo: 'pending')
          .where('department', isEqualTo: department)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline, color: Colors.red),
              title: const Text('Unable to load approval requests'),
              subtitle: Text(snapshot.error.toString()),
            ),
          );
        }
        final count = snapshot.data?.docs.length ?? 0;
        return Card(
          color: const Color(0xFFEAF1FC),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.how_to_reg)),
            title: const Text('Student Approval Requests',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('$count $department students waiting'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HODApprovalScreen(department: department),
              ),
            ),
          ),
        );
      },
    );
  }
}

class HODApprovalScreen extends StatelessWidget {
  final String department;
  const HODApprovalScreen({super.key, required this.department});

  Future<void> reviewStudent(
    BuildContext context,
    String studentUid,
    String decision,
  ) async {
    final hodUid = FirebaseAuth.instance.currentUser?.uid;
    if (hodUid == null) {
      showMessage(context, 'HOD session not found. Please login again.');
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(studentUid).update({
        'status': decision,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': hodUid,
      });
      if (context.mounted) {
        showMessage(context, decision == 'active'
            ? 'Student approved successfully.'
            : 'Student rejected successfully.');
      }
    } on FirebaseException catch (e) {
      if (context.mounted) showMessage(context, 'Review failed: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$department Student Approvals')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .where('status', isEqualTo: 'pending')
            .where('department', isEqualTo: department)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load students: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingScreen();
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.verified,
              title: 'No Pending Approvals',
              message: 'All department requests have been reviewed.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final d = doc.data();
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((d['name'] ?? 'Student').toString(),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text('Email: ${(d['email'] ?? '').toString()}'),
                      Text('Mobile: ${(d['mobile'] ?? 'Not Added').toString()}'),
                      Text('Roll Number: ${(d['rollNumber'] ?? 'Not Added').toString()}'),
                      Text('Academic Year: ${(d['year'] ?? 'Not Added').toString()}'),
                      Text('Department: $department'),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => reviewStudent(context, doc.id, 'rejected'),
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => reviewStudent(context, doc.id, 'active'),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ------------------------- STUDENT PROFILE & REQUESTS -----------------------

class StudentDashboard extends StatelessWidget {
  final Map<String, dynamic> userData;
  const StudentDashboard({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final department = (userData['department'] ?? '').toString();
    return DashboardLayout(
      title: 'Student Dashboard',
      name: (userData['name'] ?? 'Student').toString(),
      role: '$department Student',
      headerIcon: Icons.school,
      extraHeader: StudentProfileSummary(userData: userData),
      modules: const [
        'My Attendance',
        'Exam Department',
        'Results & Hall Ticket',
        'T.P.O. & Placements',
        'Fees & Receipts',
        'Certificates',
        'Library',
        'Scholarships',
        'Transport',
        'Events',
        'Notices',
        'My Profile',
      ],
    );
  }
}

class StudentProfileSummary extends StatelessWidget {
  final Map<String, dynamic> userData;
  const StudentProfileSummary({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: const Text('My Profile'),
        subtitle: const Text('View and update your personal information'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StudentProfileScreen()),
        ),
      ),
    );
  }
}

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final nameController = TextEditingController();
  final mobileController = TextEditingController();
  bool initialized = false;
  bool saving = false;

  @override
  void dispose() {
    nameController.dispose();
    mobileController.dispose();
    super.dispose();
  }

  Future<void> savePersonalDetails(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final name = nameController.text.trim();
    final mobile = mobileController.text.trim();

    if (uid == null) return;
    if (name.isEmpty || !RegExp(r'^[6-9][0-9]{9}$').hasMatch(mobile)) {
      showMessage(context, 'Enter a name and valid 10-digit mobile number.');
      return;
    }

    setState(() => saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': name,
        'mobile': mobile,
        'profileUpdatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) showMessage(context, 'Profile updated successfully.');
    } on FirebaseException catch (e) {
      if (mounted) showMessage(context, 'Profile update failed: ${e.message}');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> submitAcademicRequest(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    String requestedRoll = (data['rollNumber'] ?? '').toString();
    String requestedYear = (data['year'] ?? academicYears.first).toString();
    String requestedDepartment = (data['department'] ?? '').toString();

    final rollController = TextEditingController(text: requestedRoll);
    String? year = requestedYear;
    String? department = requestedDepartment;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request Academic Details Change'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: rollController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Requested Roll Number'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: year != null && academicYears.contains(year) ? year : null,
                  decoration: const InputDecoration(labelText: 'Requested Academic Year'),
                  items: academicYears
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => year = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: department != null && collegeDepartments.contains(department)
                      ? department
                      : null,
                  decoration: const InputDecoration(labelText: 'Requested Department'),
                  items: collegeDepartments
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => department = v),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Department changes require approval from your current HOD and then the new department HOD.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final roll = rollController.text.trim();
                if (roll.isEmpty || year == null || department == null) return;
                Navigator.pop(dialogContext, {
                  'rollNumber': roll,
                  'year': year!,
                  'department': department!,
                });
              },
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
    rollController.dispose();

    if (result == null) return;

    final oldDepartment = (data['department'] ?? '').toString();
    final newDepartment = result['department']!;
    final changesDepartment = oldDepartment != newDepartment;

    try {
      final existing = await FirebaseFirestore.instance
          .collection('profile_change_requests')
          .where('studentUid', isEqualTo: uid)
          .where('status', whereIn: [
            'pending_current_hod',
            'pending_new_hod',
            'pending_hod',
          ]).limit(1).get();

      if (existing.docs.isNotEmpty) {
        if (mounted) {
          showMessage(context, 'You already have a pending profile request.');
        }
        return;
      }

      await FirebaseFirestore.instance.collection('profile_change_requests').add({
        'studentUid': uid,
        'studentName': (data['name'] ?? '').toString(),
        'studentEmail': (data['email'] ?? '').toString(),
        'currentDepartment': oldDepartment,
        'requestedDepartment': newDepartment,
        'currentRollNumber': (data['rollNumber'] ?? '').toString(),
        'requestedRollNumber': result['rollNumber'],
        'currentYear': (data['year'] ?? '').toString(),
        'requestedYear': result['year'],
        'status': changesDepartment ? 'pending_current_hod' : 'pending_hod',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showMessage(context, 'Profile change request submitted for HOD approval.');
      }
    } on FirebaseException catch (e) {
      if (mounted) showMessage(context, 'Request failed: ${e.message}');
    } catch (e) {
      if (mounted) showMessage(context, 'Request failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const LoginScreen();

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load profile: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const LoadingScreen();
          }
          final data = snapshot.data!.data()!;
          if (!initialized) {
            nameController.text = (data['name'] ?? '').toString();
            mobileController.text = (data['mobile'] ?? '').toString();
            initialized = true;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: CircleAvatar(
                          radius: 34,
                          child: Icon(Icons.person, size: 36),
                        ),
                      ),
                      const SizedBox(height: 18),
                      profileReadOnly('Email Address', data['email']),
                      profileReadOnly('Department', data['department']),
                      profileReadOnly('Roll Number', data['rollNumber']),
                      profileReadOnly('Academic Year', data['year']),
                      const Divider(height: 28),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: mobileController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          prefixIcon: Icon(Icons.phone_android),
                          prefixText: '+91 ',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: saving ? null : () => savePersonalDetails(data),
                          icon: const Icon(Icons.save),
                          label: Text(saving ? 'Saving...' : 'Save Personal Details'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.edit_document, color: brandColor),
                  title: const Text('Request Academic Details Change'),
                  subtitle: const Text('Roll Number, Year or Department (HOD approval)'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => submitAcademicRequest(data),
                ),
              ),
              const StudentRequestStatusCard(),
            ],
          );
        },
      ),
    );
  }
}

Widget profileReadOnly(String label, dynamic value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 125,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(
            (value ?? 'Not Added').toString(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class StudentRequestStatusCard extends StatelessWidget {
  const StudentRequestStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('profile_change_requests')
          .where('studentUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              title: const Text('Request status unavailable'),
              subtitle: Text(snapshot.error.toString()),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('My Profile Requests',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                ...docs.map((doc) {
                  final d = doc.data();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.pending_actions),
                    title: Text(
                      'Roll: ${d['requestedRollNumber']} • ${d['requestedYear']}',
                    ),
                    subtitle: Text(
                      'Department: ${d['requestedDepartment']} | Status: ${d['status']}',
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------------ HOD PROFILE CHANGE REQUESTS ------------------------

class HODProfileRequestCard extends StatelessWidget {
  final String department;
  const HODProfileRequestCard({super.key, required this.department});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.manage_accounts)),
        title: const Text('Profile Change Requests'),
        subtitle: const Text('Review student academic detail changes'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HODProfileRequestsScreen(department: department),
          ),
        ),
      ),
    );
  }
}

class HODProfileRequestsScreen extends StatelessWidget {
  final String department;
  const HODProfileRequestsScreen({super.key, required this.department});

  Future<void> processRequest(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool approve,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final data = doc.data();
    final status = (data['status'] ?? '').toString();
    final currentDepartment =
        (data['currentDepartment'] ?? '').toString();
    final requestedDepartment =
        (data['requestedDepartment'] ?? '').toString();

    final isDepartmentChange =
        currentDepartment != requestedDepartment;

    try {
      final requestRef = doc.reference;

      if (!approve) {
        await requestRef.update({
          'status': 'rejected',
          'reviewedBy': uid,
          'reviewedAt': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          showMessage(context, 'Request rejected.');
        }
        return;
      }

      // First approval: current department HOD forwards to target HOD.
      if (isDepartmentChange && status == 'pending_current_hod') {
        await requestRef.update({
          'status': 'pending_new_hod',
          'currentHodApprovedBy': uid,
          'currentHodApprovedAt': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          showMessage(
            context,
            'Approved by current HOD. Sent to new department HOD.',
          );
        }
        return;
      }

      final isNewHodStep =
          isDepartmentChange && status == 'pending_new_hod';
      final isSameDepartmentStep =
          !isDepartmentChange && status == 'pending_hod';

      if (!isNewHodStep && !isSameDepartmentStep) {
        throw Exception('Invalid request approval stage: $status');
      }

      final studentUid = (data['studentUid'] ?? '').toString();
      if (studentUid.isEmpty) {
        throw Exception('Student UID is missing.');
      }

      final studentRef = FirebaseFirestore.instance
          .collection('users')
          .doc(studentUid);

      // Student and request are committed atomically.
      final batch = FirebaseFirestore.instance.batch();

      batch.update(studentRef, {
        'rollNumber': data['requestedRollNumber'],
        'year': data['requestedYear'],
        if (isNewHodStep) ...{
          'department': requestedDepartment,
          'lastApprovedRequestId': doc.id,
        },
        'academicDetailsUpdatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(requestRef, {
        'status': 'approved',
        'finalApprovedBy': uid,
        'finalApprovedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (context.mounted) {
        showMessage(
          context,
          'Student academic details updated and approved successfully.',
        );
      }
    } on FirebaseException catch (e) {
      debugPrint('HOD APPROVAL FIREBASE ERROR: ${e.code} ${e.message}');
      if (context.mounted) {
        showMessage(
          context,
          'Approval failed [${e.code}]: ${e.message}',
        );
      }
    } catch (e) {
      debugPrint('HOD APPROVAL ERROR: $e');
      if (context.mounted) {
        showMessage(context, 'Approval failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentStep = FirebaseFirestore.instance
        .collection('profile_change_requests')
        .where('currentDepartment', isEqualTo: department)
        .where('status', whereIn: ['pending_current_hod', 'pending_hod']);

    final isTargetStep = FirebaseFirestore.instance
        .collection('profile_change_requests')
        .where('requestedDepartment', isEqualTo: department)
        .where('status', isEqualTo: 'pending_new_hod');

    return Scaffold(
      appBar: AppBar(title: Text('$department Profile Requests')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: isCurrentStep.snapshots(),
        builder: (context, currentSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: isTargetStep.snapshots(),
            builder: (context, targetSnapshot) {
              if (currentSnapshot.hasError || targetSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Could not load requests: ${currentSnapshot.error ?? targetSnapshot.error}',
                  ),
                );
              }
              if (!currentSnapshot.hasData || !targetSnapshot.hasData) {
                return const LoadingScreen();
              }

              final combined = <QueryDocumentSnapshot<Map<String, dynamic>>>[
                ...currentSnapshot.data!.docs,
                ...targetSnapshot.data!.docs,
              ];
              final unique = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
              for (final doc in combined) {
                unique[doc.id] = doc;
              }
              final docs = unique.values.toList();

              if (docs.isEmpty) {
                return const EmptyState(
                  icon: Icons.task_alt,
                  title: 'No Profile Requests',
                  message: 'There are no requests waiting for your department.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final d = doc.data();
                  final current = (d['currentDepartment'] ?? '').toString();
                  final requested = (d['requestedDepartment'] ?? '').toString();
                  final status = (d['status'] ?? '').toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (d['studentName'] ?? 'Student').toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                          Text((d['studentEmail'] ?? '').toString()),
                          const Divider(height: 22),
                          Text('Current Department: $current'),
                          Text('Requested Department: $requested'),
                          Text('Current Roll: ${d['currentRollNumber']}'),
                          Text('Requested Roll: ${d['requestedRollNumber']}'),
                          Text('Current Year: ${d['currentYear']}'),
                          Text('Requested Year: ${d['requestedYear']}'),
                          Text('Approval Stage: $status'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => processRequest(context, doc, false),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => processRequest(context, doc, true),
                                  child: Text(
                                    current != requested && status == 'pending_current_hod'
                                        ? 'Approve & Forward'
                                        : 'Final Approve',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// --------------------------- OTHER ROLE DASHBOARDS --------------------------

class TeacherDashboard extends StatelessWidget {
  final Map<String, dynamic> userData;
  const TeacherDashboard({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final department = (userData['department'] ?? '').toString();
    return DashboardLayout(
      title: 'Teacher Dashboard',
      name: (userData['name'] ?? 'Teacher').toString(),
      role: '$department Teacher',
      headerIcon: Icons.cast_for_education,
      modules: const [
        'My Classes',
        'Attendance Management',
        'Student Records',
        'Notes & Study Materials',
        'Assignments',
        'Exam Management',
        'Internal Marks',
        'Department Notices',
        'Student Performance',
        'My Profile',
      ],
    );
  }
}

// ------------------------------ DASHBOARD UI --------------------------------

class DashboardLayout extends StatelessWidget {
  final String title;
  final String name;
  final String role;
  final IconData headerIcon;
  final List<String> modules;
  final Widget? extraHeader;

  const DashboardLayout({
    super.key,
    required this.title,
    required this.name,
    required this.role,
    required this.modules,
    required this.headerIcon,
    this.extraHeader,
  });

  IconData moduleIcon(String module) {
    if (module.contains('Attendance')) return Icons.fact_check;
    if (module.contains('Exam') || module.contains('Result')) return Icons.assignment;
    if (module.contains('T.P.O.') || module.contains('Placement')) return Icons.work;
    if (module.contains('Fees')) return Icons.payments;
    if (module.contains('Certificate')) return Icons.workspace_premium;
    if (module.contains('Library')) return Icons.local_library;
    if (module.contains('Scholarship')) return Icons.school;
    if (module.contains('Transport')) return Icons.directions_bus;
    if (module.contains('Notice')) return Icons.campaign;
    if (module.contains('Teacher')) return Icons.person;
    if (module.contains('Student')) return Icons.groups;
    if (module.contains('Profile')) return Icons.account_circle;
    if (module.contains('Assignment')) return Icons.task;
    if (module.contains('Report')) return Icons.analytics;
    if (module.contains('Department') || module.contains('HOD')) return Icons.apartment;
    if (module.contains('Event')) return Icons.event;
    if (module.contains('Setting')) return Icons.settings;
    return Icons.dashboard;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () async => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: brandColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 29,
                  backgroundColor: Colors.white,
                  child: Icon(headerIcon, size: 32, color: brandColor),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $name',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(role, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (extraHeader != null) ...[
            const SizedBox(height: 16),
            extraHeader!,
          ],
          const SizedBox(height: 22),
          const Text(
            'COLLEGE SERVICES',
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: brandColor),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: modules.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemBuilder: (context, index) {
              final module = modules[index];
              return Card(
                elevation: 1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    if (module == 'My Profile') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudentProfileScreen(),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ModulePlaceholderScreen(moduleName: module),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(moduleIcon(module), size: 31, color: brandColor),
                        const SizedBox(height: 9),
                        Text(
                          module,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// -------------------------------- UTILITIES ---------------------------------

class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context) => const StatusScreen(
        icon: Icons.hourglass_top,
        title: 'Approval Pending',
        message:
            'Your registration is submitted. Please wait for your Department HOD approval.',
        color: Colors.orange,
      );
}

class RejectedScreen extends StatelessWidget {
  const RejectedScreen({super.key});

  @override
  Widget build(BuildContext context) => const StatusScreen(
        icon: Icons.cancel_outlined,
        title: 'Registration Rejected',
        message:
            'Your registration was not approved. Please contact your Department HOD.',
        color: Colors.red,
      );
}

class StatusScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;

  const StatusScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 75, color: color),
              const SizedBox(height: 20),
              Text(title,
                  style: const TextStyle(
                      fontSize: 23, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 25),
              FilledButton.icon(
                onPressed: () async => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModulePlaceholderScreen extends StatelessWidget {
  final String moduleName;
  const ModulePlaceholderScreen({super.key, required this.moduleName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(moduleName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.construction, size: 65, color: brandColor),
              const SizedBox(height: 16),
              Text(moduleName,
                  style: const TextStyle(
                      fontSize: 21, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text(
                'This module is not implemented yet. It will be developed in a later stage.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

class ErrorScreen extends StatelessWidget {
  final String message;
  const ErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 55, color: Colors.red),
              const SizedBox(height: 15),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async => FirebaseAuth.instance.signOut(),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 65, color: Colors.green),
            const SizedBox(height: 15),
            Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
