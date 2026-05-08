# SaafHisaab — Complete App Documentation

> **"Aapki dukaan ka saaf hisaab"** — Clean Accounts for Your Shop

---

## 1. PROJECT OVERVIEW

SaafHisaab is a Flutter-based shop management app for Indian local shopkeepers. It runs on **real production data** via Supabase (PostgreSQL backend). The app supports Hindi/English bilingual UI, phone OTP auth, 4-digit passcode lock, bill entry, stock tracking, credit (udhar) management, and push notifications.

### Tech Stack
| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Backend/DB | Supabase (PostgreSQL + Auth + Realtime) |
| State Mgmt | Riverpod (`flutter_riverpod`) |
| Auth | Supabase Phone OTP (SMS) |
| Security | SHA-256 hashed passcode via `flutter_secure_storage` + `crypto` |
| Notifications | Firebase Cloud Messaging + `flutter_local_notifications` |
| OCR (ready) | `google_mlkit_text_recognition` (service built, UI not wired) |
| Config | `.env` file loaded via `flutter_dotenv` |
| Payments (planned) | `razorpay_flutter` (dependency added, not implemented) |

### Target Platform
- **Primary:** Android (APK builds configured)
- **Secondary:** Chrome/Web (used for development/testing)
- iOS, Windows, Linux, macOS directories exist but untested

---

## 2. FILE STRUCTURE MAP

```
lib/
├── main.dart                          # App entry, AuthWrapper, lifecycle observer
├── globalVar.dart                     # SharedPrefs init, AppLang helper, language provider
├── firebase_options.dart              # Auto-generated Firebase config
├── constants/
│   ├── app_colors.dart                # Brand color palette (26 lines)
│   └── app_strings.dart               # EMPTY — not used
├── models/
│   ├── shop_model.dart                # ShopModel (id, userId, ownerName, shopName, city, shopType, gstNumber, phone, plan)
│   ├── bill_model.dart                # BillModel (id, shopId, userId, imageUrl, rawText, amount, billDate, vendorName, category, billType, isGstBill, gstAmount, notes)
│   ├── sale_model.dart                # SaleModel (id, shopId, userId, itemName, quantity, unit, sellingPrice, totalAmount, paymentMode, category, billId, saleDate, notes)
│   ├── stock_model.dart               # StockItemModel (id, shopId, userId, itemName, category, currentQuantity, unit, buyingPrice, sellingPrice, lowStockAlert, supplierName, supplierPhone) + isLowStock getter + profitPerUnit getter
│   ├── udhar_model.dart               # UdharCustomerModel + UdharEntryModel (credit/debit entries)
│   └── user_model.dart                # EMPTY — auth uses Supabase User directly
├── providers/
│   └── app_providers.dart             # All Riverpod providers (auth, shop, dashboard, bills, stock, udhar)
├── services/
│   ├── auth_service.dart              # sendOTP, verifyOTP, signOut, currentUser getters
│   ├── supabase_service.dart          # ALL database CRUD (shops, bills, sales, stock, udhar, dashboard stats)
│   ├── session_service.dart           # Passcode hash/verify, timeout logic, secure storage
│   ├── notification_service.dart      # FCM init, local notifications, low stock/daily/udhar alerts
│   ├── ocr_service.dart               # ML Kit text recognition, bill parser (amount, vendor, date, GST extraction)
│   └── share_service.dart             # EMPTY — planned for WhatsApp sharing
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart          # Phone number input + OTP send
│   │   ├── otp_screen.dart            # 6-digit OTP verification with timer
│   │   ├── shop_setup_screen.dart     # One-time shop profile setup
│   │   ├── set_passcode_screen.dart   # Set/Change 4-digit PIN with confirm
│   │   └── passcode_screen.dart       # Unlock screen with attempts + lockout
│   ├── home/
│   │   └── home_screen.dart           # Dashboard + BottomNav + Drawer (5 tabs)
│   ├── bills/
│   │   ├── bill_scan_screen.dart      # Bill list + manual bill entry dialog
│   │   └── bill_review_screen.dart    # EMPTY — planned for OCR review
│   ├── stock/
│   │   └── stock_screen.dart          # Stock list + add item dialog
│   ├── udhar/
│   │   └── udhar_screen.dart          # Credit customers + add/mark-paid
│   ├── profile/
│   │   └── profile_screen.dart        # Settings, shop info, security, language, sign out
│   └── settings/
│       └── session_timeout_screen.dart # Timeout duration picker (0/1/5/15/30/60/-1 min)
├── utils/                             # EMPTY directory
└── widgets/
    └── bottom_nav.dart                # EMPTY — nav is inline in home_screen.dart
```

---

## 3. SUPABASE DATABASE TABLES

All data is real. Tables inferred from model fields and service queries:

### `shops`
| Column | Type | Notes |
|---|---|---|
| id | UUID (PK) | Auto-generated |
| user_id | UUID (FK) | Links to Supabase auth.users |
| owner_name | text | |
| shop_name | text | |
| city | text | |
| shop_type | text | Kirana Store, Kapda/Cloth, Electronics, Medical/Pharmacy, Hardware, Stationery, Restaurant/Dhaba, Jewellery, Other |
| gst_number | text | Optional |
| phone | text | From auth |
| plan | text | Default: 'free' |
| fcm_token | text | For push notifications |
| created_at | timestamp | |
| updated_at | timestamp | |

### `bills`
| Column | Type | Notes |
|---|---|---|
| id | UUID (PK) | |
| shop_id | UUID (FK) | |
| user_id | UUID (FK) | |
| image_url | text | For OCR scanned bills |
| raw_text | text | OCR extracted text |
| amount | double | Bill total |
| bill_date | date | |
| vendor_name | text | |
| category | text | Default: 'General' |
| bill_type | text | 'purchase' or 'sale' |
| is_gst_bill | boolean | |
| gst_amount | double | |
| notes | text | |
| created_at | timestamp | |

### `sales`
| Column | Type | Notes |
|---|---|---|
| id | UUID (PK) | |
| shop_id | UUID (FK) | |
| user_id | UUID (FK) | |
| item_name | text | |
| quantity | double | Default: 1 |
| unit | text | Default: 'piece' |
| selling_price | double | |
| total_amount | double | |
| payment_mode | text | Default: 'cash' |
| category | text | Default: 'General' |
| bill_id | UUID (FK) | Optional link to bills |
| sale_date | date | |
| notes | text | |
| created_at | timestamp | |

### `stock_items`
| Column | Type | Notes |
|---|---|---|
| id | UUID (PK) | |
| shop_id | UUID (FK) | |
| user_id | UUID (FK) | |
| item_name | text | |
| category | text | Default: 'General' |
| current_quantity | double | |
| unit | text | piece, kg, litre, meter, box, dozen |
| buying_price | double | |
| selling_price | double | |
| low_stock_alert | double | Default: 5 — threshold for "Low" badge |
| supplier_name | text | |
| supplier_phone | text | |
| created_at | timestamp | |
| updated_at | timestamp | |

### `udhar_customers`
| Column | Type | Notes |
|---|---|---|
| id | UUID (PK) | |
| shop_id | UUID (FK) | |
| user_id | UUID (FK) | |
| customer_name | text | |
| customer_phone | text | |
| total_due | double | Running balance |
| created_at | timestamp | |
| updated_at | timestamp | |

### `udhar_entries`
| Column | Type | Notes |
|---|---|---|
| id | UUID (PK) | |
| shop_id | UUID (FK) | |
| user_id | UUID (FK) | |
| customer_id | UUID (FK) | |
| entry_type | text | 'credit' (gave udhar) or 'debit' (received payment) |
| amount | double | |
| note | text | |
| entry_date | date | |
| created_at | timestamp | |

---

## 4. AUTHENTICATION FLOW (FULLY WORKING)

```
User opens app
  → main.dart initializes: SharedPreferences, dotenv, Supabase, Firebase, Notifications
  → AuthWrapper (StreamBuilder on auth state)
      ├── No session → LoginScreen
      │     → User enters 10-digit phone → AuthService.sendOTP('+91XXXXXXXXXX')
      │     → OTPScreen (6 individual TextFields, auto-advance focus)
      │         → 30-second countdown timer
      │         → Resend button enabled after timer expires
      │         → AuthService.verifyOTP() → AuthResponse
      │         → If user.id exists in shops table → HomeScreen
      │         → If not → ShopSetupScreen
      │
      ├── Session exists, no shop → ShopSetupScreen
      │     → Progress bar: Login ✓ → Setup (current) → Start
      │     → Fields: Owner Name*, Shop Name*, City*, Shop Type* (dropdown), GST (optional)
      │     → SupabaseService.saveShop() → HomeScreen
      │
      ├── Session exists, shop exists, no passcode → SetPasscodeScreen
      │     → Custom numpad (digits 0-9 + backspace)
      │     → Enter 4 digits → stored as _firstPasscode
      │     → Screen changes to "Confirm Passcode"
      │     → Enter 4 digits again → if match → SHA-256 hash → flutter_secure_storage
      │     → If mismatch → shake animation (Curves.elasticIn) + red dots → retry confirm
      │     → On success → HomeScreen
      │
      ├── Session exists, passcode set, timeout expired → PasscodeScreen (via _PasscodeGate)
      │     → Shows "Hello, {ownerName} ji" greeting
      │     → 4-digit entry with animated dots
      │     → Wrong attempt counter (5 max)
      │     → After 3 wrong → 30-second lockout timer (buttons greyed out)
      │     → After 5 wrong → clearPasscode() + signOut() → LoginScreen
      │     → "Forgot passcode?" → same as 5 wrong (sign out)
      │     → Biometric hint text shown (not implemented yet)
      │     → PopScope canPop: false (can't back-swipe away)
      │
      └── All good → HomeScreen
```

### Lifecycle Observer (App Background/Resume)
- `didChangeAppLifecycleState` in `_SaafHisaabAppState`
- On `paused`/`inactive`: saves timestamp via `SessionService.saveLastActiveTime()`
- On `resumed`: calls `_checkPasscodeOnResume()` → if elapsed time ≥ timeout → shows `PasscodeScreen` as overlay via `navigatorKey`
- Uses `_isShowingPasscode` flag to prevent duplicate passcode screens

### Session Timeout Options
Stored in SharedPreferences as `session_timeout_minutes`:
- `0` = Immediately (every app open)
- `1` = 1 minute
- `5` = 5 minutes (DEFAULT)
- `15` = 15 minutes
- `30` = 30 minutes
- `60` = 1 hour
- `-1` = Never (only on logout)

### Passcode Security
- Hashed with SHA-256 (`crypto` package) before storing
- Stored in `flutter_secure_storage` (encrypted keychain/keystore)
- Last active timestamp also in secure storage
- On "Remove Passcode": deletes both passcode and timestamp keys

---

## 5. HOME SCREEN & NAVIGATION (FULLY WORKING)

### Bottom Navigation Bar (5 tabs via IndexedStack)
| Index | Label (EN/HI) | Screen | Icon |
|---|---|---|---|
| 0 | Home / होम | _DashboardTab | home_rounded |
| 1 | Bills / बिल | BillScanScreen | receipt_long_rounded |
| 2 | Stock / स्टॉक | StockScreen | inventory_2_rounded |
| 3 | Credit / उधार | UdharScreen | people_rounded |
| 4 | Settings / सेटिंग्स | ProfileScreen | settings_rounded |

### Drawer Menu
- Language toggle switch (English ↔ Hindi)
- My Profile (switches to tab 4)
- Help & Support (no-op currently)
- Sign Out → `AuthService.signOut()` → LoginScreen

### Dashboard Tab (_DashboardTab)
**Header**: Blue bar with hamburger menu, "Hello, {name} 👋", shop name, notification bell icon

**4 Stat Cards** (real-time from Supabase):
1. **Today's Sales** (₹ amount) — Sum of `sales.total_amount` WHERE `sale_date = today` PLUS sum of `bills.amount` WHERE `bill_type = 'sale'` AND `bill_date = today`
2. **Pending Credit** (₹ amount) — Sum of all `udhar_customers.total_due`
3. **Bills Today** (count) — Count of `bills` WHERE `bill_date = today` (falls back to sales count if no bills)
4. **Low Stock** (count) — Count of stock items where `current_quantity <= low_stock_alert`

**Quick Actions** (4-column grid):
- Bill Scan → tab 1
- Add Sale → tab 1
- Credit → tab 3
- Stock → tab 2

**Today's Bills List**:
- Shows each bill with: `#EntryNumber`, Vendor Name, Bill Type label (Sale/Purchase), Amount
- Sale bills: green icon + green amount
- Purchase bills: blue icon + blue amount
- Empty state: "No bills today — Scan a bill or add a sale"

**Pull-to-Refresh**: Invalidates `dashboardStatsProvider`, `todayBillsProvider`, `shopProvider`

---

## 6. BILLS MANAGEMENT (FULLY WORKING — MANUAL ENTRY)

### Bill List (BillScanScreen)
- Shows today's bills from `bills` table ordered by `created_at DESC`
- Each card: icon (green trending_up for sale, blue receipt for purchase), vendor name, category + type label, amount
- Empty state with instructions
- Pull-to-refresh

### Add Bill Dialog (Bottom Sheet)
- **Bill Type Toggle**: Purchase (default) | Sale — styled chips
- **Vendor/Party Name**: text field (optional)
- **Amount (₹)**: number field (required)
- **Save**: Creates `BillModel` → `SupabaseService.saveBill()` → invalidates providers → snackbar "Bill saved successfully!"
- Bill date auto-set to `DateTime.now()`

### OCR Service (BUILT but NOT wired to UI)
`ocr_service.dart` contains a complete bill scanning pipeline:
- Uses `google_mlkit_text_recognition` with Latin script
- `extractBillData(File)` → returns Map with: raw_text, amount, vendor_name, bill_date, is_gst_bill, gst_amount, gstin
- **Amount extraction**: Priority keyword search → "grand total" > "net amount" > "total amount" > "total" > largest number fallback
- **Vendor extraction**: First non-numeric line that isn't a date/phone/GST/invoice header
- **Date extraction**: Regex for DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY → converts to YYYY-MM-DD
- **GST detection**: Checks for GSTIN, CGST, SGST, IGST, "tax invoice" keywords
- **GSTIN extraction**: Regex for 15-char Indian GSTIN format
- `bill_review_screen.dart` is EMPTY — this is where scanned bill preview would go

---

## 7. STOCK MANAGEMENT (FULLY WORKING)

### Stock List (StockScreen)
- Lists all items from `stock_items` table ordered by `item_name`
- Each card: icon (warning if low, inventory if OK), item name, "{quantity} {unit} • ₹{sellingPrice}"
- Low stock items: red border, red warning icon, red "Low" badge
- Low stock threshold: `current_quantity <= low_stock_alert` (default alert = 5)
- Pull-to-refresh

### Add Stock Item (Bottom Sheet)
- **Item Name** (required)
- **Quantity** (required, number) + **Unit** dropdown (piece, kg, litre, meter, box, dozen)
- **Buying Price** (optional, number)
- **Selling Price** (optional, number)
- Save → `SupabaseService.saveStockItem()` → invalidates stock + dashboard providers

### Stock Deduction (Service exists, not auto-triggered)
`SupabaseService.deductStock(shopId, itemName, quantity)`:
- Finds item by name in shop's stock
- Subtracts quantity, clamps to 0 minimum
- Updates `current_quantity` in database

### Computed Properties on Model
- `isLowStock` → `currentQuantity <= lowStockAlert`
- `profitPerUnit` → `sellingPrice - buyingPrice`

---

## 8. UDHAR / CREDIT MANAGEMENT (FULLY WORKING)

### Customer List (UdharScreen)
- Shows customers with `total_due > 0`, ordered by highest due first
- Each card: avatar (first letter), name, phone, amount in red
- 3-dot menu → "✅ Mark as Paid" → sets `total_due = 0`
- Pull-to-refresh

### Add Credit Customer (Bottom Sheet)
- **Customer Name** (required)
- **Phone Number** (optional)
- **Credit Amount ₹** (required)
- Save → `SupabaseService.saveUdharCustomer()` → invalidates udhar + dashboard providers

### Udhar Entry System (Service exists)
`SupabaseService.addUdharEntry(entry, customerId)`:
- Inserts entry into `udhar_entries` table
- Reads current `total_due` from customer
- If `entry_type == 'credit'`: adds amount to due
- If `entry_type == 'debit'`: subtracts amount from due (clamped to 0)
- Updates customer's `total_due` and `updated_at`
- **Note**: The UI for adding individual credit/debit entries to existing customers is NOT built yet — only "Add new customer" and "Mark as Paid" exist in the UI.

---

## 9. PROFILE & SETTINGS (FULLY WORKING)

### Profile Screen (Tab 4)
- **Shop Info Card**: Shop name, type, city, phone, GST (if present), plan (FREE/etc)
- **Language Dropdown**: English / हिन्दी — persisted via SharedPreferences
- **Security Section**:
  - Change Passcode → navigates to SetPasscodeScreen (reuses setup screen)
  - Session Timeout → navigates to SessionTimeoutScreen
  - Remove Passcode → confirmation dialog → `SessionService.clearPasscode()`
- **General Section**:
  - Notifications (no-op)
  - Help & Support (no-op)
  - About SaafHisaab → Flutter `showAboutDialog`
- **Sign Out Button**: Clears passcode + signs out → LoginScreen
- **Footer**: "SaafHisaab v1.0.0"

### Session Timeout Screen
- Description card explaining the feature
- 7 radio-button options (0, 1, 5, 15, 30, 60 min, Never)
- Selected option highlighted with blue background + check icon
- Save button → `SessionService.saveTimeoutSetting()` → pops back with snackbar

---

## 10. LOCALIZATION SYSTEM

- **No i18n package** — uses a simple inline helper
- `AppLang.tr(bool isEn, String en, String hi)` returns the correct string
- Language state: `appLanguageProvider` (Riverpod `NotifierProvider<AppLanguageNotifier, bool>`)
- Persisted in `SharedPreferences` key `appLanguageEn`
- Default: English (`true`)
- Every screen watches `appLanguageProvider` and rebuilds on toggle
- Available on LoginScreen (dropdown), Drawer (switch), ProfileScreen (dropdown)

---

## 11. PUSH NOTIFICATIONS (PARTIALLY WORKING)

### Initialization
- Skips entirely on web (`kIsWeb` check)
- Requests permission → initializes local notifications → creates Android channel
- Listens to foreground FCM messages → shows local notification
- Background handler registered

### FCM Token
- Retrieved on HomeScreen init → saved to `shops.fcm_token` column via `NotificationService.saveTokenToSupabase(userId)`

### Pre-built Notification Templates (service methods exist, not auto-triggered):
- `showLowStockAlert(itemName)` — "⚠️ Low Stock Alert: {item} ka stock khatam hone wala hai"
- `showDailySummary(sales, bills)` — "📊 Aaj ka hisaab: Aaj ₹X ki sale hui — Y bills"
- `showUdharReminder(customerName, amount)` — "💰 Udhar Reminder: {name} ka ₹X baaki hai"

### Not Yet Implemented
- Automatic triggers for these notifications (would need backend cron/Edge Functions)
- Notification tap handling (logs payload but doesn't navigate)

---

## 12. DESIGN SYSTEM (AppColors)

```dart
primary         = #1A56DB  (Royal Blue)
primaryLight    = #3B82F6
primaryDark     = #1E40AF
primaryBg       = #F0F4FF  (Light blue tint for backgrounds)
primaryBorder   = #C7D7F9
background      = #F8FAFF  (Off-white blue)
surface         = #FFFFFF
surfaceBlue     = #F0F4FF
textPrimary     = #111827  (Near black)
textSecondary   = #6B7280  (Gray)
textHint        = #9CA3AF  (Light gray)
success         = #10B981  (Green — sales, confirmations)
error           = #EF4444  (Red — low stock, errors, delete)
warning         = #F59E0B  (Amber — udhar/credit)
purple          = #8B5CF6  (Stock quick action)
border          = #E5E7EB
borderBlue      = #C7D7F9
```

### UI Patterns
- **Headers**: Solid `primary` blue containers with white text, custom padding for status bar
- **Cards**: White `surface` with `border` outline, 12-14px border radius
- **Bottom Sheets**: Rounded top corners (24px), scroll-aware padding for keyboard
- **Buttons**: Solid `primary` with white text, 12px radius, no elevation
- **Form Fields**: Filled `background` color, `borderBlue` outline, 12px radius
- **Animations**: Shake (passcode error), AnimatedContainer (dot fill), AnimatedOpacity (error text)

---

## 13. EMPTY/PLACEHOLDER FILES

These files exist but are empty (0 bytes), indicating planned features:
| File | Planned Purpose |
|---|---|
| `models/user_model.dart` | Custom user model (currently uses Supabase User) |
| `services/share_service.dart` | WhatsApp sharing via `share_plus` |
| `constants/app_strings.dart` | Centralized string constants |
| `widgets/bottom_nav.dart` | Reusable bottom nav (currently inline) |
| `screens/bills/bill_review_screen.dart` | OCR bill review/edit before save |
| `utils/` (empty dir) | Utility functions |

---

## 14. DEPENDENCIES (pubspec.yaml)

```yaml
# Core
supabase_flutter: ^2.3.4
flutter_riverpod: ^2.5.1

# Camera + Image (for future OCR UI)
camera: ^0.10.5+9
image_picker: ^1.0.7

# ML Kit OCR
google_mlkit_text_recognition: ^0.13.0

# Sharing
share_plus: ^7.2.2

# Local Storage
hive_flutter: ^1.1.0         # Added but NOT used in code
shared_preferences: ^2.5.5
flutter_secure_storage: ^10.1.0

# Charts (planned)
fl_chart: ^0.67.0            # Added but NOT used in code

# PDF/Excel Reports (planned)
pdf: ^3.10.8                 # Added but NOT used in code
printing: ^5.12.0            # Added but NOT used in code

# Push Notifications
firebase_core: ^3.13.0
firebase_messaging: ^15.2.5
flutter_local_notifications: ^17.0.0

# Payments (planned)
razorpay_flutter: ^1.3.5     # Added but NOT used in code

# Security
crypto: ^3.0.7               # SHA-256 passcode hashing
flutter_dotenv: ^5.1.0       # .env file loading
```

---

## 15. WHAT WORKS vs WHAT'S PLANNED

### ✅ Fully Working (Real Data)
- Phone OTP login/signup
- Shop profile creation and display
- 4-digit passcode set/verify/change/remove with SHA-256
- Session timeout with configurable duration
- App lifecycle passcode re-lock
- Dashboard with 4 real-time stat cards
- Manual bill entry (Purchase/Sale) with Supabase persistence
- Today's bills list with entry numbers
- Stock item CRUD with low-stock alerts
- Udhar customer add + mark-as-paid
- Bilingual UI (English/Hindi) with persistence
- FCM token registration
- Pull-to-refresh on all list screens
- Navigation drawer + bottom nav

### 🔨 Service Built, UI Not Wired
- OCR bill scanning (`ocr_service.dart` — full parser)
- Individual udhar credit/debit entries (`addUdharEntry`)
- Stock deduction on sale (`deductStock`)
- Notification templates (low stock, daily summary, udhar reminder)

### 📋 Dependency Added, Not Implemented
- Charts (`fl_chart`) — no chart screens
- PDF/Excel reports (`pdf`, `printing`) — no export functionality
- Razorpay payments — no subscription/payment flow
- Hive local storage — no offline mode
- WhatsApp sharing (`share_plus`) — no share buttons
- Camera/ImagePicker — no camera UI for bill scanning
- Biometric auth — hint text shown but not functional

---

## 16. KNOWN ISSUES & RECENT FIXES

1. **Dashboard stats now include bills table** — Previously `today_sales` and `today_bills` only queried the `sales` table; now they also include sale-type entries from the `bills` table.
2. **SetPasscodeScreen height overflow fixed** — Restructured to `Expanded > LayoutBuilder > SingleChildScrollView > IntrinsicHeight` with smaller buttons (64px vs 72px).
3. **Dashboard stat card overflow fixed** — Values wrapped in `FittedBox(fit: BoxFit.scaleDown)`, labels use `TextOverflow.ellipsis`.
4. **pubspec.yaml merge conflict resolved** — Git conflict markers in firebase dependencies were cleaned up.
5. **PasscodeScreen (unlock)** still uses old 72px buttons — may overflow on very short screens (not yet fixed like SetPasscodeScreen was).
