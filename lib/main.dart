import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

// Hive adapters - temporarily commented as they are not yet generated
/*
import 'data/local/models/user_profile_hive.dart';
import 'data/local/models/calibration_data_hive.dart';
import 'data/local/models/phrase_board_hive.dart';
import 'data/local/models/vocabulary_entry_hive.dart';
import 'data/local/models/communication_entry_hive.dart';
*/

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables FIRST
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Error loading .env file: $e');
  }
  
  // Lock to portrait mode (eye tracking works best in portrait)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Keep screen on during the app
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
  
  // Initialize Hive local database
  await Hive.initFlutter();
  
  // Register ALL Hive type adapters (Commented until generated)
  /*
  Hive.registerAdapter(UserProfileHiveAdapter());
  Hive.registerAdapter(CalibrationDataHiveAdapter());
  Hive.registerAdapter(PhraseBoardHiveAdapter());
  Hive.registerAdapter(VocabularyEntryHiveAdapter());
  Hive.registerAdapter(CommunicationEntryHiveAdapter());
  */
  
  // Open Hive boxes
  // await Hive.openBox<UserProfileHive>('user_profiles');
  // await Hive.openBox<CalibrationDataHive>('calibration_data');
  // await Hive.openBox<PhraseBoardHive>('phrase_boards');
  // await Hive.openBox<VocabularyEntryHive>('vocabulary');
  // await Hive.openBox<CommunicationEntryHive>('communication_history');
  await Hive.openBox('app_settings');
  
  // Initialize Supabase
  if (dotenv.env['SUPABASE_URL'] != null && dotenv.env['SUPABASE_ANON_KEY'] != null) {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: OAuthFlow.pkce,
      ),
    );
  }
  
  runApp(
    // Riverpod wrapper — enables all providers
    const ProviderScope(
      child: EchoApp(),
    ),
  );
}
