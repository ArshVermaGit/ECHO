# ECHO AAC — Master Build Index
## The Complete AI-IDE Instruction Set

> **What is this?**
> This folder contains every document needed to build ECHO — a production-grade, medically serious Augmentative and Alternative Communication (AAC) app — using Flutter + MediaPipe + Claude AI. Each file is a detailed instruction set for an AI IDE. Read them in order. Follow every step. Do not skip files.

---

## 🗂️ Document Map

| File | Purpose | Build Phase |
|------|---------|-------------|
| `00_MASTER_INDEX.md` | You are here — navigation + philosophy | Pre-build |
| `01_PROJECT_ARCHITECTURE.md` | Full system design, data flows, folder structure | Pre-build |
| `02_ENVIRONMENT_SETUP.md` | Flutter install, dependencies, pubspec, emulator config | Day 1 |
| `03_CAMERA_AND_MEDIAPIPE.md` | Camera feed, face mesh 468 landmarks, blink detection | Day 1-2 |
| `04_GAZE_ENGINE.md` | Gaze vector math, zone mapping, dwell timer | Day 2-3 |
| `05_CALIBRATION_SYSTEM.md` | 15-point calibration wizard, accuracy scoring, persistence | Day 3-4 |
| `06_GAZE_KEYBOARD.md` | Full adaptive on-screen keyboard, letter selection, haptics | Day 4-6 |
| `07_CLAUDE_AI_INTEGRATION.md` | Predictive text, vocabulary learning, Claude API calls | Day 6-8 |
| `08_VOICE_ENGINE.md` | TTS, voice cloning with Coqui, 100 voice profiles | Day 8-10 |
| `09_EMERGENCY_PROTOCOL.md` | Double-blink trigger, SMS, GPS, max-volume alert | Day 10-11 |
| `10_PHRASE_BOARDS.md` | Contextual boards, time-aware, caregiver-schedulable | Day 11-12 |
| `11_OFFLINE_MODE.md` | Hive local DB, n-gram fallback, full offline operation | Day 12-13 |
| `12_BACKEND_SUPABASE.md` | Full DB schema, auth, real-time subscriptions, RLS policies | Day 13-15 |
| `13_CAREGIVER_APP.md` | Companion portal, analytics, remote monitoring | Day 15-18 |
| `14_UI_DESIGN_SYSTEM.md` | Color, typography, animations, accessibility, all screens | Day 18-20 |
| `15_ADVANCED_FEATURES.md` | Switch access, smart home, emotion detection, multilingual | Day 20-28 |
| `16_TESTING_AND_QA.md` | Unit, widget, integration tests, real-device testing protocol | Day 28-30 |
| `17_DEPLOYMENT.md` | App Store + Play Store submission, signing, review prep | Day 30+ |
| `18_AI_IDE_PROMPTS.md` | Copy-paste prompts for every single feature for AI IDEs | All phases |

---

## 🧠 Philosophy of This Build

### Why This App Matters
ECHO is not a productivity tool. It is, for some users, the **only way they can communicate with another human being**. A locked-in ALS patient cannot tap the wrong letter, wait 5 seconds for a laggy prediction, or have the app crash. Every technical decision must be made with this weight in mind.

- **Speed**: Sub-100ms gaze response. 60fps UI. No janky frames.
- **Reliability**: App must work with zero internet. Emergency must never fail.
- **Accuracy**: 96%+ post-calibration. Errors are not "bugs" — they are failures of care.
- **Warmth**: This is someone's voice. Design it like it matters.

### How to Use These Documents With an AI IDE
Each document is structured in three layers:
1. **WHAT** — What this feature is and why it exists
2. **HOW** — Exact implementation details, code structure, algorithms
3. **PROMPT** — The exact text to paste into your AI IDE to build it

When using Antigravity IDE (or Cursor, Windsurf, etc.):
1. Open the relevant `.md` file
2. Read the full document yourself first
3. Copy the `## 🤖 AI IDE Prompt` section at the bottom
4. Paste into your AI IDE chat
5. Review output, then move to the next file

### Build Order is Non-Negotiable
Each feature depends on the previous. You cannot build the keyboard without the gaze engine. You cannot build gaze engine without MediaPipe running. Do not skip steps.

---

## ✅ Pre-Build Checklist

Before opening any IDE, confirm:

- [ ] Flutter SDK 3.19+ installed (`flutter --version`)
- [ ] Android Studio OR Xcode installed (for emulator)
- [ ] Physical Android/iOS device available for real testing (emulators can't fully test camera)
- [ ] Anthropic API key obtained from `console.anthropic.com`
- [ ] Supabase project created at `supabase.com` (free tier is fine)
- [ ] Node.js 18+ installed (for Coqui voice server)
- [ ] Git initialized (`git init` in project folder)
- [ ] At least 8GB RAM on dev machine (MediaPipe is memory intensive)

---

## 🏗️ What You Will Have Built When Done

A fully working Flutter application that:
- Tracks eye gaze at 60fps using phone camera and Google MediaPipe
- Allows a paralyzed patient to type using only their eyes
- Predicts sentences using Claude AI trained on their personal vocabulary
- Speaks in the patient's own cloned voice
- Sends emergency alerts with GPS to 5 contacts via SMS, with zero internet required
- Works in 40 languages
- Has a full caregiver companion app for monitoring and scheduling
- Stores all data privately, locally encrypted, with cloud backup
- Integrates with smart home devices via Bluetooth
- Achieves 96-98% gaze accuracy post-calibration — matching $15,000 commercial devices

**Estimated total build time:** 4-6 weeks for one focused developer using AI assistance.

---

*Start with `01_PROJECT_ARCHITECTURE.md` →*
