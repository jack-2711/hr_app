# HR Connect - Recreated Project

This project has been recreated from the original HR App with a Node.js backend and native-integrated features.

## Structure
- `backend/`: Node.js Express server with Supabase integration.
- `mobile/`: Flutter app configured for Android.
- `supabase/`: Database migration scripts.

## Setup Instructions

### 1. Database
- Run the SQL script in `supabase/migrations/001_initial_schema.sql` in your Supabase SQL Editor.

### 2. Backend
- Navigate to `backend/`.
- Run `npm install`.
- Update the `.env` file with your `SUPABASE_SERVICE_ROLE_KEY`.
- Run `npm start`.

### 3. Mobile
- Navigate to `mobile/`.
- **CRITICAL**: Copy `mobilefacenet.tflite` from the original app's `assets/` folder to `mobile/assets/`.
- Run `flutter pub get`.
- Run `flutter run`.

## Troubleshooting Build Errors
If you see "Inconsistent JVM-target compatibility", the project is currently configured to force JVM 11 in `android/build.gradle.kts`. Ensure your IDE/Terminal is using a JDK that matches (JDK 11 or 17+ with compatibility set).
