
ergencyContact Freezed model with id, name, phoneNumber, relationship, sortOrder, customMessage

2. Create EmergencyTriggerService that:
   - Monitors BlinkType.single events
   - Two singles within 800ms → starts 5-second confirmation countdown
   - Emits Stream<EmergencyTriggerEvent> with type and secondsRemaining
   - cancel() resets all state

3. Create LocationService:
   - getCurrentPosition with 10s timeout
   - Returns Google Maps URL: https://maps.google.com/?q=lat,lng  
   - Returns null if permission denied

4. Create SmsService:
   - sendEmergencyToAll(contacts, patientName, locationUrl)
   - "EMERGENCY: [name] needs help. [customMsg] Location: [url]"
   - 200ms delay between each SMS

5. Create EmergencyController (Riverpod):
   - On confirmationStarted: show overlay + warning audio (0.5 vol)
   - On emergencyFired: get GPS → send SMS → max volume audio → SOS vibration
   - SOS pattern: [0,100,100,100,100,100,200,300,100,300,100,300,200,100,100,100,100,100]
   - cancelByPatient() stops everything

6. EmergencyOverlayWidget:
   - Full screen red (#F85149) during 5-second countdown
   - Pulsing warning icon + giant countdown number (animated scale per tick)
   - Large white "CANCEL" button (gaze-selectable zone)
   - After emergency fires: dark screen + green checkmark + "X contacts notified"

7. EmergencySetupScreen: 5 contact slots with name, phone (international format), 
   relationship picker, saved to Hive and Supabase

MUST work with airplane mode ON (SMS uses GSM, not data).
```
