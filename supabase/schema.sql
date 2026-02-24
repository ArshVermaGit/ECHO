-- Users (both patients and caregivers)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  role TEXT CHECK (role IN ('patient', 'caregiver')),
  display_name TEXT,
  language_code TEXT DEFAULT 'en',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_active TIMESTAMPTZ DEFAULT NOW()
);

-- Patient-Caregiver relationships
CREATE TABLE IF NOT EXISTS patient_caregiver_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_id UUID REFERENCES users(id),
  caregiver_id UUID REFERENCES users(id),
  relationship TEXT,  -- 'family', 'professional', 'friend'
  active BOOLEAN DEFAULT true
);

-- Calibration data per device
CREATE TABLE IF NOT EXISTS calibration_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  device_id TEXT,
  calibration_matrix JSONB,  -- 15-point calibration offsets
  accuracy_score FLOAT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Personal vocabulary
CREATE TABLE IF NOT EXISTS vocabulary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  word TEXT,
  frequency INTEGER DEFAULT 1,
  last_used TIMESTAMPTZ DEFAULT NOW(),
  context_tags TEXT[]  -- ['medical', 'family', 'emotional']
);

-- Communication history
CREATE TABLE IF NOT EXISTS communication_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  message TEXT,
  input_method TEXT,  -- 'gaze', 'phrase_board', 'switch'
  sent_via TEXT,      -- 'voice', 'screen', 'both'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Phrase boards
CREATE TABLE IF NOT EXISTS phrase_boards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  name TEXT,
  context_trigger TEXT,   -- 'morning', 'medical', 'evening', 'custom'
  trigger_time TIME,
  active BOOLEAN DEFAULT true
);

CREATE TABLE IF NOT EXISTS phrase_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  board_id UUID REFERENCES phrase_boards(id),
  text TEXT,
  icon_name TEXT,
  sort_order INTEGER
);

-- Emergency contacts
CREATE TABLE IF NOT EXISTS emergency_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  name TEXT,
  phone_number TEXT,
  relationship TEXT,
  sort_order INTEGER  -- 1-5, determines SMS order
);

-- Analytics (for caregiver insights)
CREATE TABLE IF NOT EXISTS session_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  session_start TIMESTAMPTZ,
  session_end TIMESTAMPTZ,
  total_messages INTEGER,
  avg_gaze_accuracy FLOAT,
  avg_words_per_minute FLOAT,
  emergency_triggers INTEGER DEFAULT 0
);
