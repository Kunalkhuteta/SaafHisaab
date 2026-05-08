<<<<<<< HEAD
# saafhisaab

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
=======
# 🧾 SaafHisaab — Aapki Dukaan Ka Saaf Hisaab

A complete **ERP & Shop Management** mobile app built with **Flutter + Supabase**, designed for Indian shopkeepers (Kirana, Cloth, Electronics, Medical, etc.).

---

## 🚀 What's Built So Far

### ✅ Day 1 — Foundation & Supabase Connection
| Feature | Status | Details |
|---------|--------|---------|
| Flutter project setup | ✅ Done | Clean architecture with models/services/screens/providers |
| Supabase backend connected | ✅ Done | Real-time database with `.env` config |
| Environment config | ✅ Done | `flutter_dotenv` with `.env` file for secrets |
| Design system | ✅ Done | `AppColors` with consistent blue theme |
| Data models | ✅ Done | Shop, Bill, Sale, Stock, Udhar (Customer + Entry) |

### ✅ Day 2 — Auth with Supabase OTP (via Twilio)
| Feature | Status | Details |
|---------|--------|---------|
| Phone OTP login | ✅ Done | Supabase Auth + Twilio SMS integration |
| OTP screen with 6-digit boxes | ✅ Done | Auto-focus, auto-verify on last digit |
| Smart auth routing | ✅ Done | `AuthWrapper` — redirects logged-in users to Home |
| New vs returning user detection | ✅ Done | New → Shop Setup, Returning → Home |

### ✅ Day 3 — Firebase Push Notifications
| Feature | Status | Details |
|---------|--------|---------|
| Firebase project configured | ✅ Done | `firebase_options.dart` via FlutterFire CLI |
| FCM push notifications | ✅ Done | Foreground + background message handling |
| Local notifications | ✅ Done | Low stock alerts, daily summary, udhar reminders |
| FCM token saved to Supabase | ✅ Done | Per-user token in `shops` table |
| Notification channel (Android) | ✅ Done | High importance channel |

### ✅ Day 4 — Shop Setup & Dashboard
| Feature | Status | Details |
|---------|--------|---------|
| Shop setup screen | ✅ Done | Owner name, shop name, city, type, GST |
| Shop data saved to Supabase | ✅ Done | `SupabaseService.saveShop()` |
| Dashboard with real stats | ✅ Done | Today's sales, pending udhar, bill count, low stock |
| Riverpod providers | ✅ Done | `shopProvider`, `dashboardStatsProvider`, etc. |
| Pull-to-refresh | ✅ Done | Dashboard stats refresh on pull |

### ✅ Day 5 — Full Feature Screens
| Feature | Status | Details |
|---------|--------|---------|
| Bottom navigation (5 tabs) | ✅ Done | Home, Bills, Stock, Udhar, More |
| Stock management screen | ✅ Done | List items, add new items, low stock indicators |
| Udhar/Credit screen | ✅ Done | Customer list, add customer, mark paid |
| Bills screen | ✅ Done | Today's bills, add purchase/sale bills |
| Profile/More screen | ✅ Done | Shop info, sign out, about |
| Quick actions wired up | ✅ Done | Dashboard shortcuts navigate to correct tabs |

---

## 🛠 Tech Stack

| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform mobile app |
| **Supabase** | Backend — Database, Auth (phone OTP), Real-time |
| **Twilio** | SMS delivery for Supabase OTP |
| **Firebase** | Push notifications (FCM) only |
| **Riverpod** | State management |
| **flutter_dotenv** | Environment variable management |

---

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry, Supabase + Firebase init, AuthWrapper
├── firebase_options.dart        # FlutterFire CLI generated config
│
├── constants/
│   └── app_colors.dart          # Design system colors
│
├── models/
│   ├── shop_model.dart          # Shop data model
│   ├── bill_model.dart          # Bill/invoice data model
│   ├── sale_model.dart          # Sale transaction model
│   ├── stock_model.dart         # Stock item model (with isLowStock)
│   └── udhar_model.dart         # Udhar customer + entry models
│
├── services/
│   ├── auth_service.dart        # Supabase phone OTP auth
│   ├── supabase_service.dart    # All database CRUD operations
│   └── notification_service.dart # FCM + local notifications
│
├── providers/
│   └── app_providers.dart       # Riverpod providers for all data
│
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart    # Phone number input + send OTP
│   │   ├── otp_screen.dart      # 6-digit OTP verification
│   │   └── shop_setup_screen.dart # New user shop registration
│   ├── home/
│   │   └── home_screen.dart     # Main shell with bottom nav + dashboard
│   ├── bills/
│   │   └── bill_scan_screen.dart # Bills list + add bill
│   ├── stock/
│   │   └── stock_screen.dart    # Stock items + add item
│   ├── udhar/
│   │   └── udhar_screen.dart    # Udhar customers + payments
│   └── profile/
│       └── profile_screen.dart  # Shop info + sign out
│
└── widgets/                     # Reusable widgets (future)
```

---

## 🗄 Supabase Tables Required

Create these tables in your Supabase dashboard:

### `shops`
| Column | Type | Notes |
|--------|------|-------|
| id | uuid (PK, default) | |
| user_id | text (unique) | Supabase auth user ID |
| owner_name | text | |
| shop_name | text | |
| city | text | |
| shop_type | text | |
| phone | text | |
| gst_number | text | |
| plan | text (default: 'free') | |
| fcm_token | text | FCM push token |
| created_at | timestamptz (default: now()) | |
| updated_at | timestamptz | |

### `bills`
| Column | Type |
|--------|------|
| id | uuid (PK) |
| shop_id | uuid (FK → shops.id) |
| user_id | text |
| image_url | text |
| raw_text | text |
| amount | numeric |
| bill_date | date |
| vendor_name | text |
| category | text |
| bill_type | text (purchase/sale) |
| is_gst_bill | boolean |
| gst_amount | numeric |
| notes | text |
| created_at | timestamptz |

### `sales`
| Column | Type |
|--------|------|
| id | uuid (PK) |
| shop_id | uuid (FK) |
| user_id | text |
| item_name | text |
| quantity | numeric |
| unit | text |
| selling_price | numeric |
| total_amount | numeric |
| payment_mode | text |
| category | text |
| bill_id | uuid (FK, nullable) |
| sale_date | date |
| notes | text |
| created_at | timestamptz |

### `stock_items`
| Column | Type |
|--------|------|
| id | uuid (PK) |
| shop_id | uuid (FK) |
| user_id | text |
| item_name | text |
| category | text |
| current_quantity | numeric |
| unit | text |
| buying_price | numeric |
| selling_price | numeric |
| low_stock_alert | numeric (default: 5) |
| supplier_name | text |
| supplier_phone | text |
| created_at | timestamptz |
| updated_at | timestamptz |

### `udhar_customers`
| Column | Type |
|--------|------|
| id | uuid (PK) |
| shop_id | uuid (FK) |
| user_id | text |
| customer_name | text |
| customer_phone | text |
| total_due | numeric |
| created_at | timestamptz |
| updated_at | timestamptz |

### `udhar_entries`
| Column | Type |
|--------|------|
| id | uuid (PK) |
| shop_id | uuid (FK) |
| user_id | text |
| customer_id | uuid (FK → udhar_customers.id) |
| entry_type | text (credit/debit) |
| amount | numeric |
| note | text |
| entry_date | date |
| created_at | timestamptz |

---

## 🏃 How to Run

```bash
# 1. Clone the repo
git clone <repo-url>
cd saafhisaab

# 2. Install dependencies
flutter pub get

# 3. Make sure .env has your Supabase credentials
# PROJECT_URL=https://your-project.supabase.co
# ANON_PUBLIC_KEY=your-anon-key

# 4. Run on device/emulator
flutter run
```

---

## 📱 App Flow

```
Login Screen (Phone)
    ↓ Send OTP via Supabase + Twilio
OTP Screen (6-digit verify)
    ↓ New user? → Shop Setup
    ↓ Returning? → Home
Shop Setup Screen
    ↓ Save shop to Supabase
Home (Dashboard)
    ├── Bills Tab (list + add)
    ├── Stock Tab (list + add)
    ├── Udhar Tab (customers + payments)
    └── Profile Tab (info + sign out)
```

---

## 🔮 Upcoming Features (Planned)

- [ ] OCR Bill Scanning (ML Kit)
- [ ] PDF/Excel report generation
- [ ] WhatsApp share for udhar reminders
- [ ] Charts on dashboard (fl_chart)
- [ ] Razorpay premium plan payments
- [ ] Offline mode with Hive sync
- [ ] Camera integration for bills

---

**Made with ❤️ for Indian shopkeepers**
>>>>>>> c00c9d440be47def005461b5f096b9180b2c8584
