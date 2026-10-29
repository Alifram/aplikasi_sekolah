import 'package:flutter/material.dart';
import 'screens/user/splash_screen.dart';
import 'screens/dashboard/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart'; // Pastikan import dashboard ada
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!SupabaseConfig.isConfigured) {
    throw StateError(
      'SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY harus disediakan '
      'melalui --dart-define-from-file.',
    );
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkModeActive = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MIM Pasir Lor',
      debugShowCheckedModeBanner: false,
      
      theme: _isDarkModeActive 
          ? ThemeData.dark(useMaterial3: true).copyWith(
              scaffoldBackgroundColor: const Color(0xFF0B141A),
              cardColor: const Color(0xFF111B21),
              dividerColor: Colors.grey.shade800,
            ) 
          : ThemeData(
              primarySwatch: Colors.green,
              scaffoldBackgroundColor: Colors.white,
              useMaterial3: true,
            ),
            
      initialRoute: '/',
      
      onGenerateRoute: (settings) {
        if (settings.name == '/dashboard') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => DashboardScreen(
              role: args['role'] ?? 'siswa',
              namaUser: args['nama_lengkap'] ?? 'User',
              extraData: args,
              statusTemaGelap: _isDarkModeActive, 
              padaPerubahanTema: (nilaiBaru) {
                setState(() {
                  _isDarkModeActive = nilaiBaru;
                });
              },
            ),
          );
        }
        if (settings.name == '/login') {
          return MaterialPageRoute(builder: (context) => const LoginScreen());
        }
        if (settings.name == '/onboarding') {
          return MaterialPageRoute(builder: (context) => const OnboardingScreen());
        }
        
        return MaterialPageRoute(builder: (context) => const SplashScreen());
      },
    );
  }
}
