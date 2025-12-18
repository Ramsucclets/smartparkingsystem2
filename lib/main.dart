import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/amplifyconfiguration.dart';
import 'services/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureAmplify();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

Future<void> _configureAmplify() async {
  try {
    final auth = AmplifyAuthCognito();
    await Amplify.addPlugin(auth);

    await Amplify.configure(amplifyConfig);
    safePrint('Successfully configured Amplify');
  } on Exception catch (e) {
    safePrint('Error configuring Amplify: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isSignedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      setState(() {
        _isSignedIn = session.isSignedIn;
        _isLoading = false;
      });
    } catch (e) {
      safePrint('Error checking auth status: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Dark Theme - Teal/Cyan color scheme matching logo
  ThemeData get _darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
        primaryColor: const Color(0xFF00BFA5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00BFA5),
          brightness: Brightness.dark,
          primary: const Color(0xFF00BFA5),
          secondary: const Color(0xFF00ACC1),
          tertiary: const Color(0xFF26A69A),
          surface: const Color(0xFF1B3A4B),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
          bodyLarge: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFE0E0E0)),
          bodySmall: TextStyle(fontSize: 12, color: Color(0xFFB8B8C7)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1B3A4B),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF2D4A5A), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF00BFA5), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFFA0A0B0)),
          prefixIconColor: const Color(0xFF00BFA5),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00BFA5),
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: const Color(0xFF00BFA5).withValues(alpha: 0.4),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1B3A4B),
          elevation: 4,
          shadowColor: Colors.black38,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  // Light Theme - Teal/Cyan color scheme matching logo
  ThemeData get _lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F9F8),
        primaryColor: const Color(0xFF00897B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00897B),
          brightness: Brightness.light,
          primary: const Color(0xFF00897B),
          secondary: const Color(0xFF0097A7),
          tertiary: const Color(0xFF00796B),
          surface: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D1B2A),
            letterSpacing: 1.2,
          ),
          bodyLarge: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0D1B2A)),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF4A5568)),
          bodySmall: TextStyle(fontSize: 12, color: Color(0xFF718096)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFB2DFDB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFB2DFDB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF00897B), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF718096)),
          prefixIconColor: const Color(0xFF00897B),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00897B),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: const Color(0xFF00897B).withValues(alpha: 0.3),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: const Color(0xFF00897B).withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF0D1B2A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF0D1B2A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    if (_isLoading) {
      return MaterialApp(
        theme: themeProvider.isDarkMode ? _darkTheme : _lightTheme,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: 'Smart Parking System',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.isDarkMode ? _darkTheme : _lightTheme,
      home: _isSignedIn
          ? const HomeScreen(username: 'User', password: '')
          : const LoginScreen(),
    );
  }
}
