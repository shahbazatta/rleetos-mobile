import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/fleet_provider.dart';
import 'screens/login_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/supervisor/supervisor_home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, FleetProvider>(
          create: (_) => FleetProvider(),
          update: (_, auth, fleet) => fleet!..updateToken(auth.token),
        ),
      ],
      child: const CloudNextApp(),
    ),
  );
}

class CloudNextApp extends StatelessWidget {
  const CloudNextApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloudNext Fleet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4E8),
          surface: Color(0xFF0A1828),
          onSurface: Color(0xFFE8EAF0),
        ),
        scaffoldBackgroundColor: const Color(0xFF050D1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A1828),
          foregroundColor: Color(0xFFE8EAF0),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().loadStoredToken();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF00D4E8))),
          );
        }
        if (!auth.isAuthenticated) return const LoginScreen();
        if (auth.user?['role'] == 'supervisor' || auth.user?['role'] == 'admin') {
          return const SupervisorHomeScreen();
        }
        return const DriverHomeScreen();
      },
    );
  }
}
