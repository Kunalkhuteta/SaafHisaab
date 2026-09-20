# 🧾 SaafHisaab — Complete Project Blueprint & Developer Reference
> **"Aapki dukaan ka saaf hisaab"** — Cloud-connected ERP & Shop Management Ecosystem for Indian MSMEs & Retailers.

---

## 📌 Executive Summary

**SaafHisaab** is a production-grade Flutter + Supabase ERP and retail shop accounting mobile/web application tailored specifically for Indian local business owners (Kirana, Cloth/Garment, Electronics, Medical/Pharmacy, Hardware, Stationery, Restaurants, Jewellery, and Wholesale traders).

It solves the end-to-end operational lifecycle of local shops:
- ⚡ **Multi-tenant & Role-Based Team Management** (Owner, Admin, Manager, Staff)
- 🧾 **GST & Non-GST Invoicing** (Sales, Purchases, Sales Return, Purchase Return)
- 📦 **Inventory & Stock Management** (Live stock balance, Low stock thresholds, Item masters)
- 💰 **Udhar (Credit) & Party Ledgers** (Receivables from customers, Payables to suppliers)
- 📊 **Financial Reconciliations & Reports** (Daily Cash/Bank balances, Monthly Ledgers, Outstanding Aging)
- 🤖 **AI-Powered & ML Kit OCR Bill Scanning** (Automatic invoice data extraction)
- 🔒 **Enterprise-Grade Security** (SHA-256 PIN Passcode lock, Session timeouts, RLS on Supabase)
- 🌐 **Indian Localization & Context** (Bilingual EN/HI, IST Timezone, Indian Lakhs/Crores numbering format)

---

## 🏗️ Technology Stack & Architecture

| Layer | Technology | Version / Details | Purpose |
|---|---|---|---|
| **Frontend Framework** | **Flutter (Dart)** | SDK `^3.11.0` | Cross-platform UI (Target: Android APK primary, Chrome Web for testing/dev, iOS/Desktop ready) |
| **Backend & Database** | **Supabase (PostgreSQL)** | `supabase_flutter: ^2.3.4` | PostgreSQL 15+, Auth (Phone OTP via SMS), Realtime, Row Level Security (RLS), Storage buckets |
| **State Management** | **Flutter Riverpod** | `flutter_riverpod: ^2.5.1` | Reactive state management, async dependency injection (`NotifierProvider`, `FutureProvider`) |
| **Authentication** | **Supabase Auth + Twilio** | SMS OTP | Phone number login with 6-digit OTP verification & auto-routing |
| **Security & Passcode** | **Secure Storage + Crypto** | `flutter_secure_storage: ^10.1.0`, `crypto: ^3.0.7` | SHA-256 encrypted 4-digit App PIN with auto-lock lifecycle observer & brute-force lockout |
| **Push Notifications** | **Firebase Cloud Messaging** | `firebase_core: ^3.13.0`, `firebase_messaging: ^15.2.5` | FCM background/foreground push tokens stored in `shops.fcm_token` |
| **Local Notifications** | **Flutter Local Notifications** | `flutter_local_notifications: ^17.0.0` | In-app push notifications for low stock, daily summary, and credit collection alerts |
| **OCR & AI Vision** | **Google ML Kit & Together AI** | `google_mlkit_text_recognition: ^0.13.0`, `http` | Dual OCR: On-device offline text recognition + Cloud Vision LLM parsing (Kimi-K2.5/Together AI) |
| **Data Visualizations** | **fl_chart** | `fl_chart: ^0.67.0` | Interactive Sales, Expenses, and Cash-flow charts (Bar, Line, Pie) with custom time ranges |
| **Document Generation** | **PDF & Printing** | `pdf: ^3.10.8`, `printing: ^5.12.0` | Formatted PDF bill generation and sharing |
| **Configuration** | **flutter_dotenv** | `flutter_dotenv: ^5.1.0` | Environment variables loaded securely from `.env` |

---

## 📁 Repository Directory Structure

```
saafhisaab/
├── .env                                  # Supabase URL, Anon Key, AI OCR API keys
├── pubspec.yaml                          # Flutter package definitions and asset declarations
├── analysis_options.yaml                 # Dart static analyzer linting rules
├── firebase.json / firebase_options.dart # Firebase Cloud Messaging configurations
│
├── docs/                                 # Architecture, SQL migrations, and database maps
│   └── bill_crud_database_map.md         # In-depth technical guide on billing lifecycle & table relationships
├── sqc/                                  # Database migration scripts & RLS policies
│   ├── sales_invoice_headers.sql         # SQL schema for ERP invoice header JSONB data
│   ├── supabase_multi_user_phase1.sql    # Multi-user RBAC table definitions & functions
│   ├── supabase_multi_user_phase2-4.sql  # Extended access policies & trigger syncs
│   └── transporters.sql                  # Transporter master database schema
│
└── lib/
    ├── main.dart                         # Entry point, Supabase/Firebase init, AuthWrapper, AppLifecycle observer
    ├── globalVar.dart                    # SharedPreferences instance, Language Notifier, Chart Type Notifier
    ├── sys_param.dart                    # System Parameter toggle notifier (GST, Address, Stock, Station)
    │
    ├── constants/
    │   ├── app_colors.dart               # Unified design system color palette
    │   └── app_strings.dart              # String resource definitions
    │
    ├── models/
    │   ├── shop_model.dart               # Shop profile definition (ID, Owner, GST, Type, Plan)
    │   ├── shop_access_model.dart        # Multi-user RBAC model (Roles: Admin, Manager, Staff)
    │   ├── bill_model.dart               # Parent bill model (Sale, Purchase, Return types)
    │   ├── sale_model.dart               # Line-item transactions attached to bills
    │   ├── item_master_model.dart        # Unified inventory master item model
    │   ├── stock_model.dart              # Legacy stock model with isLowStock/profit getters
    │   ├── udhar_model.dart              # Customer models & credit/debit entries
    │   ├── daily_balance_model.dart      # Day-wise Cash/Bank financial summaries
    │   └── ledger_row_model.dart         # Dual-entry ledger report row representation
    │
    ├── providers/
    │   └── app_providers.dart            # Riverpod providers for Shop, Access, Dashboard, Bills, Stock, Ledgers
    │
    ├── services/
    │   ├── supabase_service.dart         # Core database CRUD service (80KB+ centralized SQL client logic)
    │   ├── auth_service.dart             # Supabase phone OTP auth & session retrieval
    │   ├── session_service.dart          # Passcode hash/verification, timeout check, and lockout rules
    │   ├── general_service.dart          # High-performance caching, UUID-Integer mapper, ERP adapters
    │   ├── handlelib_service.dart        # ERP sales invoice processor & stock orchestrator
    │   ├── notification_service.dart     # Push & local notification handlers
    │   ├── ai_ocr_service.dart           # Cloud LLM vision receipt parsing engine
    │   ├── ocr_service.dart              # On-device Google ML Kit OCR extraction logic
    │   ├── app_cache.dart                # In-memory dictionary cache for items & parties
    │   ├── global_data.dart              # Singleton context for active shop ID & user ID
    │   ├── share_service.dart            # WhatsApp & external report sharing
    │   └── system_params_service.dart    # System parameters preferences manager
    │
    ├── screens/
    │   ├── auth/                         # Authentication & Security onboarding
    │   │   ├── login_screen.dart         # Phone number input with validation & OTP request
    │   │   ├── otp_screen.dart           # 6-digit PIN input with timer & auto-verification
    │   │   ├── shop_setup_screen.dart    # Initial business profile registration
    │   │   ├── set_passcode_screen.dart  # 4-digit PIN setup & confirmation screen
    │   │   ├── passcode_screen.dart      # App unlock screen with brute-force lockout
    │   │   ├── access_removed_screen.dart# Graceful error state for deactivated staff
    │   │   └── member_welcome_screen.dart# First-login splash for newly invited staff
    │   │
    │   ├── home/                         # Dashboard & Main navigation shell
    │   │   ├── home_screen.dart          # 5-tab dynamic navigation with RBAC filtering & drawer
    │   │   ├── dashboard_tab.dart        # 4 real-time stat cards, quick action grid, recent transactions
    │   │   ├── charts_screen.dart        # Interactive sales/expenses/profit chart engine (fl_chart)
    │   │   ├── chart_data_helper.dart    # Aggregators for day/week/month/year chart data points
    │   │   └── reports_tab.dart          # Launcher hub for all accounting & business reports
    │   │
    │   ├── bills/                        # Invoicing & Scanning screens
    │   │   ├── invoice_list_screen.dart  # Filterable tabbed invoice registry (Sales, Purchases, Returns)
    │   │   ├── bill_scan_screen.dart     # Camera/Gallery OCR capture trigger
    │   │   └── bill_review_screen.dart   # OCR parsed data review, editing, and saving
    │   │
    │   ├── sales/                        # Sales operations
    │   │   ├── sale_entry_screen.dart    # Complete sale/purchase creation & edit engine
    │   │   ├── sale_detail_screen.dart   # Line-item invoice viewer with share/print options
    │   │   ├── sale_return_screen.dart   # Sales return processor with credit reversal
    │   │   ├── sale_account_screen.dart  # Sales account ledger view
    │   │   └── sale_parties_list_screen.dart # Customer sales directory
    │   │
    │   ├── purchase/                     # Purchase & Supplier operations
    │   │   ├── purchase_account_screen.dart  # Supplier ledger & purchase history
    │   │   ├── purchase_parties_list_screen.dart # Supplier directory with pending payable badges
    │   │   └── purchase_return_screen.dart   # Purchase return processor with payable adjustment
    │   │
    │   ├── stock/                        # Inventory management
    │   │   └── stock_screen.dart         # Stock catalog with search, filter, and low-stock highlights
    │   │
    │   ├── udhar/                        # Credit & Receivables
    │   │   ├── udhar_screen.dart         # Customer credit list sorted by pending amount
    │   │   └── udhar_detail_screen.dart  # Customer transaction history & payment settlement
    │   │
    │   ├── reports/                      # Financial & Tax reporting
    │   │   ├── daily_balances_screen.dart      # Day-by-day Cash & Bank reconciliation
    │   │   ├── ledger_party_selection_page.dart# Party selection for dual-entry accounting ledgers
    │   │   ├── ledger_monthly_view_page.dart   # 12-month summary of Debits & Credits
    │   │   ├── ledger_particular_month_page.dart # Day-wise drilldown of monthly transactions
    │   │   ├── outstanding_receivable_screen.dart # Customer dues aging report
    │   │   ├── receivable_party_detail_screen.dart # Deep dive into single customer receivable
    │   │   ├── outstanding_payable_screen.dart    # Supplier payables aging report
    │   │   ├── payable_party_detail_screen.dart   # Deep dive into single supplier payable
    │   │   └── bill_image_viewer_screen.dart      # High-res bill attachment viewer
    │   │
    │   ├── master/                       # Enterprise Master Directories
    │   │   ├── master_screen.dart        # Master menu launcher
    │   │   ├── item_master_list_screen.dart  # Inventory item catalog
    │   │   ├── item_master_entry_screen.dart # Item creation with categories, groups, and GST
    │   │   ├── transportmaster.dart      # Transporter directory & vehicle tracking
    │   │   ├── user_master_screen.dart   # Team member invite & staff management
    │   │   └── role_master_screen.dart   # RBAC role permissions visualizer
    │   │
    │   ├── orderPages/                   # Advanced ERP Invoicing & Orders
    │   │   ├── CreateSalesInvoicePage.dart   # Full-blown ERP Sales Invoice creation screen
    │   │   ├── CreateOrderPage.dart          # Purchase/Sales order creator
    │   │   ├── salesOrder/                   # Dedicated Sales Order modules & dialogs
    │   │   └── widgets/                      # Tax engines, E-Way dialogs, Item/Party pickers
    │   │
    │   ├── profile/                      # Settings & Shop details
    │   │   └── profile_screen.dart       # Business details, PIN settings, Language, Logout
    │   │
    │   └── settings/                     # Fine-tuning configurations
    │       ├── session_timeout_screen.dart   # Passcode auto-lock timer settings
    │       └── system_params_screen.dart     # System-wide column & UI visibility toggles
    │
    ├── widgets/                          # Reusable components
    │   ├── credit_entry_sheet.dart       # Bottom sheet for customer credit/debit entry
    │   ├── purchase_credit_entry_sheet.dart # Bottom sheet for supplier payable entry
    │   ├── party_name_field.dart         # Autocomplete text field for party lookup
    │   ├── custom_alert.dart             # Consistent modal alert dialogs
    │   ├── credit_item_row.dart          # Reusable item tile for credit vouchers
    │   ├── bottom_contact_bar.dart       # Call & WhatsApp shortcut widget
    │   └── app_loader.dart               # Standardized loader spinner
    │
    └── utils/
        └── indian_date_time.dart         # IST Date & Time formatter and helpers
```

---

## 🗄️ Database Architecture & Supabase Schema

All primary business records are scoped to a `shop_id` (multi-tenant architecture).

```
                      +------------------+
                      |      shops       |
                      +--------+---------+
                               | 1
                               |
            +------------------+-------------------+--------------------+
            |                  |                   |                    |
            | *                | *                 | *                  | *
    +-------v--------+  +------v-------+    +------v------+    +--------v--------+
    |  shop_members  |  | item_master  |    | purchase_   |    | udhar_customers |
    +----------------+  +------+-------+    | parties     |    +--------+--------+
                               |            +------+------+             |
                               |                   |                    |
                               |                   |                    | *
                               |            +------v------+    +--------v--------+
                               |            | bills (PIN) |    |  udhar_entries  |
                               |            +------+------+    +-----------------+
                               |                   |
            +------------------+-------------------+
            |                  |
            | *                | *
    +-------v--------+  +------v-------+
    |     sales      |  | bills (SIN)  |
    +----------------+  +------+-------+
                               | 1
                               |
                        +------v----------------+
                        | sales_invoice_headers |
                        +-----------------------+
```

### Table Dictionary

#### 1. `shops` — Shop Profile & Root Tenant
- `id` (uuid, PK): Unique shop identifier.
- `user_id` (text): Supabase Auth UID of the shop owner.
- `owner_name` (text), `shop_name` (text), `city` (text), `shop_type` (text), `phone` (text).
- `gst_number` (text, nullable): Business GSTIN.
- `plan` (text): Subscription tier (`free`, `premium`).
- `fcm_token` (text): Firebase Cloud Messaging push token for the device.

#### 2. `shop_members` & `shop_member_invites` — Multi-User RBAC
- `shop_id` (uuid, FK → `shops.id`): Shop being accessed.
- `user_id` (uuid, FK → `auth.users.id`): Auth user ID of the staff/admin.
- `name` (text), `phone` (text): Member profile.
- `role` (text): Role level — `'admin'`, `'manager'`, or `'staff'`.
- `is_active` (boolean): Activation switch.

#### 3. `bills` — Master Transaction Headers
- `id` (uuid, PK): Unique bill document ID.
- `shop_id` (uuid, FK → `shops.id`), `user_id` (text): Creator user ID.
- `bill_type` (text): Document type:
  - `sale` (SIN) — Sales invoice (deducts stock).
  - `purchase` (PIN) — Purchase invoice (adds stock).
  - `sale_return` (SRN) — Customer sales return (adds stock back).
  - `purchase_return` (PRN) — Supplier purchase return (deducts stock).
- `amount` (numeric): Total invoice net amount.
- `bill_date` (date): Transaction date.
- `vendor_name` (text): Customer or Supplier name.
- `is_gst_bill` (bool), `gst_amount` (numeric): Tax information.
- `image_url` (text): Uploaded bill receipt image in Supabase bucket `items`.
- `notes` (text): Metadata flags, return links (`__saafhisaab_return_ref:<id>__`), and ERP JSON payloads.

#### 4. `sales` — Bill Line Items
- `id` (uuid, PK): Line item ID.
- `bill_id` (uuid, FK → `bills.id`): Parent bill linkage.
- `stock_item_id` (uuid, FK → `item_master.id`): Link to inventory item.
- `item_name` (text), `quantity` (numeric), `unit` (text), `selling_price` (numeric), `total_amount` (numeric).
- `payment_mode` (text): `'cash'`, `'upi'`, `'card'`, `'credit'`, `'split'`, `'adjustment'`.

#### 5. `sales_invoice_headers` — Detailed ERP Header Store
- `id` (uuid, PK), `bill_id` (uuid, FK → `bills.id`, UNIQUE), `shop_id` (uuid).
- `inv_seq_no` (integer), `party_account_id` (integer), `buyer_name` (text), `net_amount` (float).
- `sihdr_data` (jsonb), `inv_tran_data` (jsonb), `stock_dtl_data` (jsonb): Full ERP payloads.

#### 6. `item_master` — Inventory & Stock Items
- `id` (uuid, PK), `shop_id` (uuid), `item_name` (text).
- `item_category` (text), `item_group` (text).
- `current_stock` (numeric): Real-time remaining stock level.
- `image_url` (text): Optional item photo.

#### 7. `udhar_customers` & `udhar_entries` — Customer Credit Ledger
- `udhar_customers`: `id` (uuid, PK), `customer_name` (text), `customer_phone` (text), `total_due` (numeric), `tobeadjustAmount` (numeric).
- `udhar_entries`: `id` (uuid, PK), `customer_id` (uuid, FK), `entry_type` (`credit`, `debit`, `credit_adjustment`), `amount` (numeric), `note` (text), `entry_date` (date), `is_paid` (bool).

#### 8. `purchase_parties` — Supplier Master
- `id` (uuid, PK), `name` (text), `phone_number` (text), `gst_number` (text).
- `pending_amount` (numeric): Current payable balance.
- `tobeadjust_amount` (numeric): Advance / return balance.

#### 9. `transporters` — Logistics Master
- `id` (uuid, PK), `shop_id` (uuid), `transporter_name` (text), `transporter_id` (text), `vehicle_number` (text), `phone_number` (text).

#### 10. `daily_balances` — Cash & Bank Reconciliation
- `shop_id` (uuid), `balance_date` (date), `cash_in` (numeric), `cash_out` (numeric), `bank_in` (numeric), `bank_out` (numeric), `net_cash` (numeric), `net_bank` (numeric).

---

## 🔑 Security, Authentication & Session Lifecycle

```
[App Launch]
    ↓
[Supabase Session Active?]
    ├─ No  → [LoginScreen (Phone + OTP)] → [Verify OTP]
    │                                             ↓
    │                                    [New User?] ── Yes → [ShopSetupScreen]
    │                                             │ No
    │                                             ↓
    └─ Yes → [Shop Access Context Loaded]
                 ↓
           [Is Passcode Set?] ── No → [SetPasscodeScreen (Enter 4 digits + Confirm)]
                 │ Yes
                 ↓
           [Passcode Timeout Expired?] ── Yes → [PasscodeScreen (4-digit PIN unlock)]
                 │ No                                    │ (Max 5 attempts)
                 ↓                                       ↓
           [HomeScreen Dashboard] <─────────── [Passcode Validated]
```

### Passcode & Auto-Lock Specifications:
1. **SHA-256 Storage**: User PIN is never stored in plain text. It is hashed using `crypto` and stored inside `flutter_secure_storage`.
2. **App Lifecycle Listener**: When the app is paused/backgrounded, `SessionService.saveLastActiveTime()` records the timestamp. On resume, if the duration exceeds the timeout, `PasscodeScreen` is displayed over the navigator.
3. **Configurable Timeout**: Settable in Settings to `0` (instant), `1m`, `5m` (default), `15m`, `30m`, `60m`, or `-1` (never).
4. **Brute Force Protection**:
   - 3 consecutive failed attempts = 30-second lockout timer.
   - 5 consecutive failed attempts = Automatic session wipe & logout.

---

## 🎨 Design System & UI Specifications

The UI utilizes a modern, clean, high-contrast aesthetic designed for outdoor and shop lighting conditions.

```dart
// Core Brand Colors (lib/constants/app_colors.dart)
static const Color primary        = Color(0xFF1A56DB); // Royal Shop Blue
static const Color primaryLight   = Color(0xFF3B82F6);
static const Color primaryDark    = Color(0xFF1E40AF);
static const Color primaryBg      = Color(0xFFF0F4FF); // Soft tint for cards & chips
static const Color background     = Color(0xFFF8FAFF); // Neutral background
static const Color surface        = Color(0xFFFFFFFF); // Card surface

// Semantic Colors
static const Color success        = Color(0xFF10B981); // Sales, Positive Cash, Paid status
static const Color error          = Color(0xFFEF4444); // Low Stock, Outflow, Delete
static const Color warning        = Color(0xFFF59E0B); // Udhar / Pending Balances
static const Color purple         = Color(0xFF8B5CF6); // Master & Special modules
```

### Localization & Formatting Standards:
- **Language**: English and Hindi toggle available across all screens via `appLanguageProvider` (`AppLang.tr(isEn, 'English', 'हिन्दी')`).
- **Currency & Numbers**: Formatted using the Indian Numbering System (`₹ 1,50,000.00`) via `IndianNumberFormat.formatAmount()`.
- **Date & Time**: Timestamps use Indian Standard Time (IST, UTC+5:30) via `IndianDateTime`.

---

## ⚙️ How to Configure and Run

### 1. Prerequisites
- **Flutter SDK**: `>= 3.11.0`
- **Dart SDK**: `>= 3.0.0`
- **Android Studio** / VS Code with Flutter extension
- Supabase Project & Firebase Project (for FCM)

### 2. Configure Environment (`.env`)
Create a `.env` file in the project root:
```env
PROJECT_URL=https://your-project.supabase.co
ANON_PUBLIC_KEY=your-supabase-anon-key
AI_API_KEY=your-together-ai-key
AI_BASE_URL=https://api.together.xyz/v1/chat/completions
AI_MODEL=moonshotai/Kimi-K2.5:together
```

### 3. Run Migrations in Supabase
Run the SQL scripts located in `sqc/` inside your Supabase SQL Editor in order:
1. `sqc/supabase_multi_user_phase1.sql` (Creates roles & membership tables)
2. `sqc/supabase_multi_user_phase2.sql` through `phase4.sql` (Applies RLS policies)
3. `sqc/sales_invoice_headers.sql` (Creates ERP header storage)
4. `sqc/transporters.sql` (Creates logistics table)

### 4. Install Dependencies & Launch
```bash
# Get Flutter packages
flutter pub get

# Run on connected Android device / Chrome
flutter run -d chrome
# or for Android
flutter run
```

---

## 💡 Developer Guidelines for Collaborating on this Codebase

When working on this project together, always follow these core principles:

1. **Multi-Tenant Scoping**: Always ensure every query on `bills`, `sales`, `item_master`, `udhar_customers`, and `purchase_parties` is filtered with `.eq('shop_id', shopId)`.
2. **Bill-Sale Relationship**: `bills` is the parent invoice. `sales` represents the itemized lines. When updating or deleting an invoice, reverse stock movements on `item_master`, clean up child `sales` rows, and trigger `syncAndGetDailyBalances`.
3. **Stock Reversal Logic**:
   - `sale` deduction reversed by adding stock back.
   - `purchase` addition reversed by deducting stock.
   - `sale_return` adds stock back; `purchase_return` removes stock.
4. **State Management**: Use `ref.invalidate(provider)` after database mutations so that dashboard stats, invoice lists, and ledgers stay synchronized.
5. **No Blind Overwrites**: When modifying models or services, preserve existing JSONB ERP payload serializers and reverse-compatibility helpers.

---

**Made with ❤️ for Indian Shopkeepers | SaafHisaab Team**
