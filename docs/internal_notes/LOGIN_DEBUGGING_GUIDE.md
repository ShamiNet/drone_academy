# 🔐 Login Debugging Guide

## Error: `INVALID_LOGIN_CREDENTIALS`

**Status Code:** 400  
**Error Message:** `{"success":false,"error":"INVALID_LOGIN_CREDENTIALS"}`

---

## ✅ Troubleshooting Steps

### Step 1: Verify the Credentials

**Issue:** The email/password combination doesn't exist in the database.

**Solutions:**

1. **Check if you have an account:**
   - Try clicking "Create New Account" to create a new account
   - Use a valid email address and password (minimum 6 characters)

2. **Verify the exact credentials:**
   - Emails are case-sensitive in some systems
   - Ensure there are no extra spaces before/after the email
   - Make sure CAPS LOCK is off for the password

3. **Password reset (if available):**
   - Check if there's a "Forgot Password" feature

---

### Step 2: Check Network Connectivity

After login fails, you may see additional errors like:
- `Failed host lookup: 'qaaz.live'`
- `Connection closed while receiving data`
- `Software caused connection abort`

**These indicate network issues:**

1. **Check Internet Connection:**
   ```bash
   ping qaaz.live
   ```

2. **Verify VPN/Firewall:**
   - If on a corporate network, check if the server is blocked
   - Try disabling VPN temporarily
   - Check Windows Firewall settings

3. **Server Status:**
   - The backend server `qaaz.live:3000` might be down
   - Try again in a few minutes

---

### Step 3: Validate Email Format

The app now validates email before sending to the server.

**Valid Email Examples:**
- `user@example.com`
- `firstname.lastname@company.co.uk`
- `test123@domain.org`

**Invalid Email Examples:**
- `user@` (missing domain)
- `user.example.com` (missing @)
- ` user@example.com ` (extra spaces)
- `user @example.com` (space in local part)

---

### Step 4: Test with a New Account

If you suspect your account credentials are wrong:

1. **Create a New Test Account:**
   - Click "Create New Account"
   - Fill in: Email, Password (6+ chars), Display Name, Select Role
   - Click Sign Up

2. **After Signup:**
   - The app should automatically log you in
   - You'll see the Home Screen

3. **If signup also fails:**
   - This indicates a server connectivity issue
   - Skip to Step 2 above

---

### Step 5: Check API Service Logs

The app now logs detailed information. Open **Logcat** in Android Studio:

```
Filter by: drone_academy or [API_ERROR]
```

**Look for these messages:**

| Message | Meaning |
|---------|---------|
| `🚀 [API][LOGIN] Attempting login for: ...` | Login attempt started |
| `Response Code: 200` | ✅ Server responded successfully |
| `Response Code: 400` | ❌ Invalid credentials |
| `Connection timeout` | ❌ Server not responding |
| `Failed host lookup: 'qaaz.live'` | ❌ Cannot resolve domain |

---

## 🔍 Advanced Debugging

### Check Device ID

The login request includes your device ID. This is used to prevent banned devices from logging in.

```
Device ID is sent in login body:
{
  "email": "user@example.com",
  "password": "password123",
  "deviceId": "device_unique_id_here"
}
```

If you see `DEVICE_BANNED` error, your device is blocked. Contact an administrator.

---

### Network Diagnosis

**On Windows, open PowerShell:**

```powershell
# Check if server is reachable
Test-Connection qaaz.live -Count 4

# Check if port 3000 is open
Test-NetConnection -ComputerName qaaz.live -Port 3000

# Check DNS resolution
Resolve-DnsName qaaz.live
```

**Expected Output for successful connection:**
```
ComputerName     : qaaz.live
RemoteAddress    : x.x.x.x (some IP address)
TcpTestSucceeded : True
```

---

## 📋 Common Issues Checklist

- [ ] Email address is correct and properly formatted
- [ ] Password is correct (at least 6 characters)
- [ ] No extra spaces in email or password
- [ ] Internet connection is working
- [ ] Not behind a restrictive proxy/firewall
- [ ] Server is online and reachable
- [ ] Device is not banned

---

## 🚀 Next Steps

### If You're Getting Stuck:

1. **Try Creating a New Account** instead of logging in
   - This tests if the server is reachable
   - If signup works, your login credentials are wrong

2. **Test Individual Steps:**
   - Validate your internet: `ping qaaz.live`
   - Verify credentials: re-enter them carefully
   - Check logs: Watch Logcat for detailed error messages

3. **Contact Administrator:**
   - If the server is down: `qaaz.live:3000`
   - If your device is banned: Contact support

---

## 📝 Log Examples

### Successful Login Log:
```
🚀 [API][LOGIN] Attempting login for: user@example.com
🚀 [API][LOGIN] Server URL: http://qaaz.live:3000/api/login
Response Code: 200
✅ Login successful for: user@example.com
```

### Failed Credentials Log:
```
🚀 [API][LOGIN] Attempting login for: user@example.com
🚀 [API][LOGIN] Server URL: http://qaaz.live:3000/api/login
Response Code: 400
🔴 [API_ERROR][LOGIN_FAIL] Status: 400 - Error: INVALID_LOGIN_CREDENTIALS
```

### Network Error Log:
```
🚀 [API][LOGIN] Attempting login for: user@example.com
🚀 [API][LOGIN] Server URL: http://qaaz.live:3000/api/login
🔴 [API_ERROR][LOGIN_TIMEOUT] Request timed out. Server not responding
```

---

## 📞 Support

If none of these steps resolve your issue:
1. Check the full error message in the app
2. Screenshot the error dialog
3. Check detailed logs in Logcat
4. Contact your system administrator with:
   - Email address used
   - Error message received
   - Timestamp of the attempt
   - Device ID (shown in logs)

