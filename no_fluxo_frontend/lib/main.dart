import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';
import 'cache/shared_preferences_helper.dart';
import 'config/size_config.dart';
import 'environment.dart';
import 'routes/app_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  Logger.root.level = Level.ALL;
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment configuration
  Environment.initialize();

  await Supabase.initialize(
      url: "https://lijmhbstgdinsukovyfl.supabase.co",
      anonKey:
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxpam1oYnN0Z2RpbnN1a292eWZsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc4MzkzNzMsImV4cCI6MjA2MzQxNTM3M30.A0bqhbEOn1SdDa5s6d9xFKHXgwpDZOA-1QJpfftFoco");

  if (kIsWeb) {
    usePathUrlStrategy();
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    SharedPreferencesHelper.init();
  }

  GoRouter get router => AppRouter.getRouter();

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return MaterialApp.router(
      title: 'NOFLX UNB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
