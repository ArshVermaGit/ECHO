# 12 — Supabase Backend
## ECHO AAC | Database, Auth, Realtime, Row Level Security

---

See 18_AI_IDE_PROMPTS.md PROMPT 11 for complete SQL schema.

## Supabase Client Setup

```dart
// lib/data/remote/supabase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static SupabaseClient get client => Supabase.instance.client;
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }
}
```

## Authentication

```dart
// Email/password auth for both patient and caregiver
// Patient: signs in, their ID links to all their data
// Caregiver: signs in, can see linked patient data via RLS policy

class AuthService {
  final SupabaseClient _client = SupabaseConfig.client;
  
  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  Future<AuthResponse> signUp(String email, String password, String role) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    
    if (response.user != null) {
      // Create user profile
      await _client.from('users').insert({
        'id': response.user!.id,
        'role': role,
        'display_name': email.split('@').first,
      });
    }
    
    return response;
  }
  
  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;
}
```

## Row Level Security Policies (SQL)

```sql
-- Users can only see their own data
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
CREATE POLICY users_self_only ON users 
  FOR ALL USING (auth.uid() = id);

-- Communication history: patient sees own, linked caregiver sees patient's
ALTER TABLE communication_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY comm_history_policy ON communication_history
  FOR SELECT USING (
    auth.uid() = user_id OR
    auth.uid() IN (
      SELECT caregiver_id FROM patient_caregiver_links 
      WHERE patient_id = user_id AND active = true
    )
  );

-- Same pattern for vocabulary, calibration_profiles, emergency_contacts
-- Patient INSERT/UPDATE their own. Caregiver READ linked patient's.
```

## Realtime Caregiver Notifications

```dart
// lib/features/caregiver/services/caregiver_sync_service.dart

class CaregiverSyncService {
  void subscribeToPatientMessages(String patientId, Function(String) onMessage) {
    SupabaseConfig.client
      .from('communication_history')
      .stream(primaryKey: ['id'])
      .eq('user_id', patientId)
      .order('created_at', ascending: false)
      .limit(1)
      .listen((data) {
        if (data.isNotEmpty) {
          onMessage(data.first['message'] as String);
        }
      });
  }
}
```

## 🤖 AI IDE Prompt — Supabase

```
Implement Supabase backend for ECHO (see PROMPT 11 in 18_AI_IDE_PROMPTS.md 
for the complete SQL schema). After running migrations:

1. Create AuthService with signIn, signUp (patient/caregiver roles), signOut
2. Create repository classes for each table with standard CRUD
3. Implement RLS so patients only see own data, caregivers see linked patient data
4. Create caregiver realtime subscription for live communication updates
5. Implement sync: when app comes online, push any pending Hive records to Supabase
```
