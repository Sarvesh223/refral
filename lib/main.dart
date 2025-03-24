import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:form/dashboard.dart';
import 'package:form/firebase_options.dart';
import 'package:form/responsive_form.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart'; // Add this import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set URL strategy to path-based (removes the hash # from URLs)
  setUrlStrategy(PathUrlStrategy());

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Referral',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Poppins',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.teal.shade300, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
      // Use routes for navigation
      initialRoute: '/',
      routes: {
        '/': (context) => const ResponsiveFormPage(),
        '/dashboard': (context) => const AdminDashboard(),
      },
      
      // Handle unknown routes
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder:
              (context) => Scaffold(
                appBar: AppBar(title: const Text('Page Not Found')),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Oops! Page not found.',
                        style: TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pushNamed('/'),
                        child: const Text('Go to Home'),
                      ),
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }
}
