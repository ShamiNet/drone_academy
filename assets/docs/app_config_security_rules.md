# Firestore Security Rules for App Config

These rules restrict writes to the `app_config/config` document to Owner users only. Adjust the path/claims to match your auth setup.

```rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Everyone can read app configuration
    match /app_config/config {
      allow read: if true;
      // Only owners can write
      allow write: if request.auth != null && request.auth.token.role == 'owner';
    }
  }
}
```

Notes:
- `request.auth.token.role` assumes you set a custom claim `role` via Firebase Admin SDK.
- If you store roles in a users collection, consider fetching it securely via Cloud Functions or mirroring an `owner` boolean in the auth token.
- After updating rules, test with a non-owner account to verify writes are blocked.
