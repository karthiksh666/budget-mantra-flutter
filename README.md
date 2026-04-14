# Budget Mantra — Flutter

AI-powered personal finance app for India, built with Flutter targeting the Supabase backend.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | Flutter 3.41+ (Material 3) |
| State | Riverpod 2 (StateNotifier + FutureProvider) |
| Navigation | GoRouter 14 (ShellRoute for bottom nav) |
| HTTP | Dio 5 (with auth interceptor) |
| Storage | flutter_secure_storage (JWT token) |
| Charts | fl_chart (donut, bar, line) |
| Animations | Lottie |
| Backend | Supabase (PostgreSQL + Auth) hosted on Railway |
| AI | Chanakya — Claude-powered financial advisor |

## Project Structure

```
lib/
├── main.dart                        # Entry point — ProviderScope + GoRouter
├── core/
│   ├── api/api_client.dart          # Dio singleton — all API calls
│   ├── auth/
│   │   ├── auth_provider.dart       # Riverpod auth state (login/signup/logout)
│   │   └── router.dart              # GoRouter with auth redirect guard
│   ├── shell/main_shell.dart        # Bottom nav shell (Overview/Alerts/Chanakya/Expenses/More)
│   └── theme/app_theme.dart         # AppColors, AppTextStyles, buildAppTheme()
└── features/
    ├── auth/
    │   ├── login_screen.dart
    │   └── signup_screen.dart
    ├── dashboard/dashboard_screen.dart       # Net balance, income/expense cards, financial score
    ├── transactions/transactions_screen.dart # Month picker, add/delete, swipe-to-dismiss
    ├── budget/budget_screen.dart             # fl_chart donut — spending by category
    ├── income/income_screen.dart             # Income entries
    ├── goals/goals_screen.dart               # Savings goals with progress bars
    ├── emi/emi_screen.dart                   # EMI tracker with monthly burden
    ├── investments/investments_screen.dart   # Portfolio with gain/loss
    ├── notifications/notifications_screen.dart  # Alerts tab with mark-read
    ├── chatbot/chatbot_screen.dart           # Chanakya AI chat with history
    └── more/more_screen.dart                 # Menu hub (Manage / Preferences / Account)
```

## Backend

Points to the production Supabase backend on Railway:
```
https://budgetmantra-supabase-production.up.railway.app/api
```

For local development, swap the base URL in `lib/core/api/api_client.dart`:
```dart
const _kBaseUrl = 'http://192.168.x.x:8001/api'; // your Mac's local IP
```

## Running Locally

### Prerequisites
- Flutter 3.41+ (`flutter --version`)
- Android emulator or iOS simulator running
- Xcode (for iOS) or Android Studio (for Android)

### Steps

```bash
# Install dependencies
flutter pub get

# Check for issues
flutter analyze

# Run on connected device/simulator
flutter run

# Run on specific device
flutter devices          # list available
flutter run -d <id>
```

## Building for Production

```bash
# Android AAB (for Play Store)
flutter build appbundle --release

# Android APK (for direct install)
flutter build apk --release

# iOS (requires Mac + Xcode + provisioning profile)
flutter build ios --release
```

## Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `AppColors.primary` | `#F97316` | Orange — CTAs, active states |
| `AppColors.success` | `#10B981` | Emerald — income, goals |
| `AppColors.danger` | `#EF4444` | Red — expenses, alerts |
| `AppColors.warning` | `#F59E0B` | Amber — EMIs, warnings |
| `AppColors.bg` | `#FAFAF9` | Warm white — scaffold background |
| `AppColors.surface` | `#FFFFFF` | Cards |
| `AppColors.textMain` | `#1C1917` | Primary text |
| `AppColors.textSub` | `#78716C` | Secondary text |

## Features

- **Dashboard** — Net balance, income vs expenses, financial health score, quick actions
- **Transactions** — Add/delete with category, month-by-month view
- **Budget** — Interactive donut chart of spending by category
- **Income** — Track income entries by source
- **Goals** — Savings goals with progress tracking and deadlines
- **EMIs** — EMI tracker with monthly burden calculation
- **Investments** — Portfolio tracker with gain/loss
- **Alerts** — In-app notifications (EMI reminders, goal alerts, weekly digest, monthly summary)
- **Chanakya** — Claude-powered AI chat with full session history
- **More** — Hub for all features + sign out

## Push Notifications

The backend runs scheduled jobs (APScheduler) that write to the `notifications` table and send Expo push notifications:

| Job | Schedule | Pref key |
|-----|----------|---------|
| EMI reminders | Daily 9:00 AM IST | `emi_reminders` |
| Goal alerts | Daily 9:15 AM IST | `goal_alerts` |
| Weekly digest | Monday 9:30 AM IST | `weekly_digest` |
| Monthly summary | 1st of month 9:00 AM IST | `monthly_summary` |

All notifications respect per-user preferences from `notification_prefs` table.
