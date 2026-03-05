# 🛡️ PayShield

**Automatic payment sentinel for Ethiopian mobile payments.**
A Flutter Android app that runs silently in the background as a foreground service, listens for incoming payment SMS messages (from **CBE** and **Telebirr**), parses them, and reports them to your backend API in real-time.

---

## How It Works

```
Incoming SMS
     │
     ▼
┌─────────────────────────────────────────────┐
│  SmsService (Foreground Service / Isolate)  │
│    - Telephony plugin listens for SMS       │
│    - Works even when app is backgrounded    │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│           Parser Layer                      │
│  TelebirrParser → tries to parse first      │
│  CbeParser      → fallback if not Telebirr  │
│  ┌─────────────────────────────────────┐    │
│  │ CbeParser supports 4 variants:      │    │
│  │  A - "ETB X has been credited..."   │    │
│  │  B - "You have received X ETB..."   │    │
│  │  C - Generic ETB + Ref pattern      │    │
│  │  D - "Account credited...Ref No..." │    │
│  └─────────────────────────────────────┘    │
└────────────────┬────────────────────────────┘
                 │  Payment object
                 ▼
┌─────────────────────────────────────────────┐
│           Connectivity Check                │
│   Online  → POST to API immediately        │
│   Offline → Enqueue in local SQLite DB     │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│           QueueService (SQLite)             │
│    Retries pending payments every 15 min   │
│    or on next network reconnect            │
└─────────────────────────────────────────────┘
```
---
### Installation Instructions

Since this app is a custom Flutter build and not available on the Google Play Store, you'll need to sideload the APK file. Android's security features (like Google Play Protect) may block or warn about unknown sources during installation. Additionally, the app requires special permissions for SMS access and running background services reliably (even when battery optimization is enabled). These might not be granted automatically, so you'll need to manually adjust settings after installation.

Follow these steps carefully:

#### Step 1: Prepare for Installation (Disable Play Protect Temporarily)
1. Open the Google Play Store app on your Android device.
2. Tap your profile icon in the top right corner.
3. Select **Play Protect** (or search for it in settings).
4. Tap the gear icon (settings) in Play Protect.
5. Turn off **Scan apps with Play Protect** (you can turn it back on after installation).
6. Download the APK file from [https://github.com/kira-coding/PayShield/releases].
7. When prompted during installation, allow installation from unknown sources (this is usually in your browser or file manager settings).

**Note:** If you get a warning like "File might be harmful," tap **Install anyway** after disabling Play Protect. This is common for non-Play Store apps.

#### Step 2: Install the App
1. Locate the downloaded APK file (usually in your Downloads folder).
2. Tap the APK to start installation.
3. Follow the on-screen prompts to install.


If you run into issues, reply to this post with details! Enjoy the app. 🚀
---
---

## Setup

1. On first launch, tap **Settings** and enter:
   - **API Domain**: `https://your-server.com` (no trailing slash)
   - **Username** and **Password** to authenticate
2. The app exchanges credentials for a Bearer API key, stored securely in `flutter_secure_storage`.
3. Tap **Start Monitoring** to launch the foreground service.
4. Grant **SMS receive** and **battery optimization exemption** permissions when prompted.

---

## Authentication

### `POST {domain}/api/auth/login`

**Request Body:**
```json
{
  "username": "youruser",
  "password": "yourpassword"
}
```

**Success Response `200`:**
```json
{
  "api_key": "your-secret-api-key"
}
```

The returned `api_key` is stored securely and attached as a `Bearer` token on all subsequent requests.

---

## Payment Reporting API

### `POST {domain}/api/register_payment`

**Headers:**
```
Authorization: Bearer <api_key>
Content-Type: application/json
```

**Request Body (sent for every matched SMS):**
```json
{
  "source": "cbe",
  "reference": "FT26055F3FYB",
  "amount": 50.00,
  "sender_phone": "Mr Robel",
  "timestamp": "2026-02-24T19:57:07.000"
}
```

| Field          | Type           | Description                                              |
|----------------|----------------|----------------------------------------------------------|
| `source`       | `string`       | `"cbe"` or `"telebirr"`                                 |
| `reference`    | `string`       | Unique transaction/reference number from the SMS        |
| `amount`       | `number`       | Payment amount in ETB                                    |
| `sender_phone` | `string/null`  | Sender name or phone number extracted from the SMS      |
| `timestamp`    | `string`       | ISO 8601 datetime parsed from the SMS (or `now()`)      |

**Expected Success Response `2xx`:**
```json
{
  "status": "ok"
}
```
Any `2xx` status code is treated as a success.

**On failure:** The payment is enqueued locally and retried automatically.

---

## Supported SMS Formats

### CBE (Commercial Bank of Ethiopia)

| Variant | Example SMS |
|---------|-------------|
| **A** | `ETB 500.00 has been credited to your account 100XXXXXXXX from 100XXXXXXXX on 01/03/2026. Tran ID: 123456789.` |
| **B** | `You have received 500.00 ETB from Account No:100XXXXXXXX. Transaction Reference: REF123456789.` |
| **C** | Generic messages containing an ETB amount and a `Ref:` / `TID:` value |
| **D** | `Dear [Name] your Account [Acc] has been Credited with ETB [Amount] from [Sender], on DD/MM/YYYY at HH:MM:SS with Ref No [REF]...` |

Recognized SMS senders: `CBE`, `CBEBIRR`, `8397`

### Telebirr

Recognized by the `TelebirrParser`. Sender number: **`127`** (exact match, or sender name containing `telebirr`).

---

## Offline Queue

If the network is unavailable when an SMS arrives, the payment is saved to a local SQLite database with `SyncStatus.pending`. The queue is retried:

- Every **15 minutes** via the foreground task repeat event
- Immediately on any **network reconnect** (detected via `connectivity_plus`)

---

## Data Flow Summary

```
SMS arrives → Parsed → [Online?]
                          ├─ Yes → POST /api/register_payment → Save as `synced` → Show "Synced" notification
                          └─ No  → Save as `pending` → Show "X pending" notification
                                       └─ On reconnect → Retry all pending
```

---

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `telephony` | Receive incoming SMS in background/foreground |
| `flutter_foreground_task` | Keep background service alive |
| `dio` | HTTP client for API calls |
| `sqflite` | Local queue persistence |
| `connectivity_plus` | Detect network changes |
| `flutter_secure_storage` | Secure API key storage |
