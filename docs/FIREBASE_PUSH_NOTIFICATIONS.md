# Firebase push notifications

This project now supports real Firebase Cloud Messaging push notifications.

## Flutter runtime configuration

Run the app with Firebase values from your Firebase project settings:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://jprscnyqjkzlofzfaarw.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY `
  --dart-define=FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY `
  --dart-define=FIREBASE_APP_ID=YOUR_FIREBASE_APP_ID `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_SENDER_ID `
  --dart-define=FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID `
  --dart-define=FIREBASE_STORAGE_BUCKET=YOUR_FIREBASE_STORAGE_BUCKET
```

If Firebase values are missing, the app still opens, but push notifications are disabled in Settings.

## Database migration

Run:

```sql
supabase/migrations/20260809001700_firebase_push_notifications.sql
```

It creates:

- `device_push_tokens`
- `notification_push_deliveries`
- `register_device_push_token`
- `unregister_device_push_token`
- delivery queue functions
- a trigger that queues every inserted row in `notifications`

## Supabase Edge Function

Deploy:

```powershell
supabase functions deploy dispatch-push-notifications
```

Set secrets:

```powershell
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='<your firebase service account json>'
```

The function needs existing Supabase secrets:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `FIREBASE_SERVICE_ACCOUNT_JSON`

Call it on a schedule, after creating notifications, or from an admin operation:

```powershell
supabase functions invoke dispatch-push-notifications --method POST
```

Production recommendation: run it every minute with Supabase scheduled functions or your own scheduler. The function claims pending queued notifications and sends them through Firebase HTTP v1.
