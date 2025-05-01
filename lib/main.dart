import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'auth/boarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    print("Flutter binding initialized");
    
    // Initialize Firebase with correct options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase initialized successfully");
    
    runApp(const RecipeFinderApp());
    print("App started successfully");
  } catch (e) {
    print("Error during app initialization: $e");
    // Run a minimal app to show the error
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text("Error starting app: $e", 
            style: TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ));
  }
}

class RecipeFinderApp extends StatefulWidget {
  const RecipeFinderApp({Key? key}) : super(key: key);

  @override
  State<RecipeFinderApp> createState() => _RecipeFinderAppState();
}

class _RecipeFinderAppState extends State<RecipeFinderApp> {
  final AuthService _authService = AuthService();
  bool _initialized = false;
  bool _shouldShowOnboarding = true;
  
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }
  
  // Check if user has seen onboarding and if user is logged in
  Future<void> _checkOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
      
      setState(() {
        _shouldShowOnboarding = !onboardingCompleted;
        _initialized = true;
      });
    } catch (e) {
      print('Error checking onboarding status: $e');
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthService>.value(
      value: _authService,
      child: MaterialApp(
        title: 'Recipe Finder',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.orange,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        home: _initialized
            ? _getLandingPage()
            : const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
      ),
    );
  }
  
  // Determine which screen to show first
  Widget _getLandingPage() {
    if (_shouldShowOnboarding) {
      return const BoardingScreen();
    }
    
    // Check if user is already logged in
    return StreamBuilder(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user != null) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        }
        
        // While checking auth state
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}