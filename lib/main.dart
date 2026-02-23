import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

// Hive adapters will be imported here after generation
// import 'data/local/models/user_profile_hive.dart';
// import 'data/local/models/calibration_data_hive.dart';
// import 'data/local/models/phrase_board_hive.dart';
// import 'data/local/models/vocabulary_entry_hive.dart';
// import 'data/local/models/communication_entry_hive.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }
  
  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Keep screen on
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Register Hive Adapters (Commented until generated)
  // Hive.registerAdapter(UserProfileHiveAdapter());
  // ...
  
  // Open Hive boxes
  await Hive.openBox('app_settings');
  // await Hive.openBox<UserProfileHive>('user_profiles');
  // ...
  
  // Initialize Supabase
  if (dotenv.env['SUPABASE_URL'] != null && dotenv.env['SUPABASE_ANON_KEY'] != null) {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }
  
  runApp(
    const ProviderScope(
      child: EchoApp(),
    ),
  );
}
