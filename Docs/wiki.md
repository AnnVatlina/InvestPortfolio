# Rentivo — Wiki

> Personal finance tracker for iOS. Tracks bank deposits, recurring subscriptions, and provides income/expense analytics.

---

## Table of Contents

1. [Overview](#overview)
2. [User Journey](#user-journey)
3. [Screens & Features](#screens--features)
   - [Onboarding](#onboarding)
   - [Home](#home)
   - [Deposits (Вклады)](#deposits)
   - [Subscriptions (Подписки)](#subscriptions)
   - [Analytics](#analytics)
   - [Settings](#settings)
4. [Data Model](#data-model)
5. [Architecture](#architecture)
6. [Localization](#localization)
7. [CSV Export & Import](#csv-export--import)
8. [Notifications](#notifications)
9. [Known Limitations & Roadmap](#known-limitations--roadmap)

---

## Overview

**Rentivo** is a native iOS app (iOS 17+) built with SwiftUI and SwiftData. It helps users:

- Track bank deposits with interest income calculation
- Manage recurring and one-time subscriptions with payment schedules
- Analyze income from deposits vs. expenses on subscriptions per month and per year
- Export and import data as CSV for backup or migration

All data is stored **locally on device** — no account, no cloud sync, no data sent to third-party servers.

**Bundle ID:** `io.rentivo.app`
**Supported languages:** Russian, English (switchable in-app without restart)
**Supported currencies:** USD, EUR, RUB, GEL, BYN

---

## User Journey

```
First Launch
    └─► Onboarding screen
            ├─► "Try with sample data" → loads 10 deposits + 20 subscriptions
            └─► "Start fresh" → empty state

Daily use
    ├─► Home tab — quick overview and navigation shortcuts
    ├─► Deposits — add/edit/delete deposits, track income
    ├─► Subscriptions — manage subscriptions, see upcoming payments
    ├─► Analytics — income vs. expense chart by month/year
    └─► Settings — language, currencies, export/import, reset
```

---

## Screens & Features

### Onboarding

Shown once on first launch (controlled by `App_HasCompletedOnboarding` in UserDefaults).

**Elements:**
- App icon with gradient background
- App name "Rentivo" and tagline
- Three feature highlights: Deposits (green), Subscriptions (orange), Analytics (purple)
- Two action buttons:
  - **"Try with sample data"** — creates 10 deposits and 20 subscriptions with historical data from 2024–2026
  - **"Start fresh"** — skips to empty app

**Sample data includes:**
- 10 deposits: mix of active and closed, currencies RUB/USD/EUR/GEL, banks Sberbank/VTB/Tinkoff/AlfaBank/Gazprombank, rates 3.5%–17%
- 20 subscriptions: 5 one-time purchases, 5 cancelled, 5 monthly, 5 yearly; all in USD

Re-shown after **Reset All Data** in Settings.

---

### Home

Landing screen with navigation cards for each section.

**Cards:**
| Icon | Section | Color |
|------|---------|-------|
| banknote.fill | Deposits | Green → Teal |
| repeat.circle.fill | Subscriptions | Orange → Pink |
| chart.bar.fill | Analytics | Purple → Indigo |
| gearshape.fill | Settings | Blue → Cyan |

Tapping a card switches to the corresponding tab.

---

### Deposits

Track bank deposits (вклады) with automated interest income calculation.

#### Deposit List

Each row shows:
- **Title** + bank name (optional)
- **Status badge**: Active (green) / Closed (gray)
- **Annual interest rate** (e.g. `17.00%`)
- **Amount** with currency (e.g. `1 500 000 RUB`)
- **Date range**: open date → close date (close date shown in orange if in the future)
- **Income to date** (green) — interest accrued from open date to today
- **Forecast to close** (orange) — projected total interest by close date (shown only for active deposits with a close date)

Closed deposits are shown at 75% opacity.

#### Adding / Editing a Deposit

Form fields:
| Field | Required | Notes |
|-------|----------|-------|
| Name | Yes | Free text |
| Bank name | No | Free text |
| Amount | Yes | Decimal number |
| Currency | Yes | From enabled currencies in Settings |
| Open date | Yes | Date picker |
| Has close date | Toggle | Enables close date field |
| Close date | If toggled | Must be after open date |
| Annual interest rate | Yes | Decimal, stored as percentage (e.g. `17` = 17%) |

#### Income Calculation

Interest is calculated using **simple interest** (not compound):

```
Income = Amount × (AnnualRate / 100) × (Days / 365)
```

Where `Days` is the number of days from `openDate` to `min(today, closeDate)`.

#### Report View

Toggle between list and report (pie chart icon in toolbar). Shows income breakdown by currency.

#### Swipe to Delete

Swipe left on a row → confirm deletion dialog.

#### Notifications

When a deposit is added or updated, a local notification is scheduled **7 days before the close date** reminding the user that the deposit is about to close.

---

### Subscriptions

Track recurring and one-time payments.

#### Billing Cycles

| Value | Description |
|-------|-------------|
| `weekly` | Every 7 days |
| `monthly` | Monthly on the same day |
| `quarterly` | Every 3 months |
| `yearly` | Annually on the same date |
| `oneTime` | Single payment, no recurrence |

#### Subscription List

**Header section — Upcoming (7 days):**
Shows subscriptions with a payment due within the next 7 days, sorted by payment date.

**Header section — Monthly total:**
Sum of monthly costs for all active recurring subscriptions in each active currency.

**Filters (segmented):**
| Filter | What it shows |
|--------|--------------|
| All | Every subscription |
| Active | `isActive = true` |
| Cancelled | `isActive = false` (has `endDate`) |
| Paid | `billingCycle = .oneTime` |

Each filter has its own sort order:
- **All** → by `createdAt` descending
- **Active** → by `nextPaymentDate` ascending
- **Cancelled** → by `endDate` descending
- **Paid** → by `startDate` descending

**Pagination:** 5 / 10 / All (selector in top-right of list)

#### Subscription Row

- SF Symbol icon in colored circle (green = active, gray = cancelled/one-time)
- Title + category (if set)
- Billing cycle label
- Amount + currency
- **Status badge**: Active (green) / Cancelled (gray) / One-time (blue)
- Next payment date (for active recurring)
- Approximate monthly cost (for yearly/quarterly billing, shown as `≈ X/mo`)

#### Adding a Subscription

Form fields:
| Field | Required | Notes |
|-------|----------|-------|
| Title | Yes | Free text |
| Category | No | Free text |
| Amount | Yes | Decimal |
| Currency | Yes | From enabled currencies |
| Billing cycle | Yes | weekly/monthly/quarterly/yearly/oneTime |
| Start date | Yes | Date picker |

#### Cancelling a Subscription

Long-press or tap edit → toggle "Active" off → sets `endDate` to today → subscription moves to "Cancelled" filter.

Cancelled subscriptions are excluded from upcoming payments and monthly cost calculations.

#### Report View

Monthly bar chart showing total subscription expenses by month for the selected year. Also shows yearly total per currency.

#### Notifications

When a subscription is added or updated (if active and recurring), a local notification is scheduled **1 day before the next payment date**.

---

### Analytics

Combined income/expense analysis across all deposits and subscriptions.

#### Layout

1. **Year picker** — navigate between years (arrows). Range covers all years that have data.

2. **Currency picker** — segmented control (shown only if multiple currencies have data).

3. **"To date" block** *(shown only for current and past years)*
   Actual amounts from **January 1 to today**:
   - Income: deposit interest accrued in this period
   - Expenses: subscription payments made in this period
   - Net: income − expenses

4. **Year total block**
   Full-year projection (includes forecasted months):
   - Income: total deposit interest for the whole year
   - Expenses: total subscription payments scheduled for the whole year
   - Net: income − expenses

5. **Monthly chart**
   Grouped bar chart (Swift Charts) showing income (teal) vs. expenses (orange) by month. Past months show actual values, future months show projections.

---

### Settings

#### Language

Switch between Russian and English. Change takes effect immediately — the entire view hierarchy is rebuilt. Saved to UserDefaults and restored on next launch.

#### Currencies

Toggle which currencies are visible in deposit/subscription forms and analytics. At least one currency must remain enabled.

All currencies: **USD, EUR, RUB, GEL, BYN**

#### Export / Import

See [CSV Export & Import](#csv-export--import).

#### Reset All Data

Deletes all deposits and subscriptions from the local database. Shows the onboarding screen again after reset (allowing re-load of sample data).

Requires confirmation via alert.

#### About

App name and version.

---

## Data Model

### Deposit

| Property | Type | Notes |
|----------|------|-------|
| `id` | UUID | Primary key |
| `title` | String | Deposit name |
| `bankName` | String? | Optional bank name |
| `amount` | Double | Principal amount |
| `currency` | DepositCurrency | USD/BYN/GEL/EUR/RUB |
| `createdAt` | Date | Record creation timestamp |
| `openDate` | Date | Deposit start date |
| `closeDate` | Date? | Deposit end date (nil = open-ended) |
| `annualInterestRate` | Double | Annual rate as percentage (e.g. 17.0) |

### Subscription

| Property | Type | Notes |
|----------|------|-------|
| `id` | UUID | Primary key |
| `title` | String | Service name |
| `amount` | Double | Payment amount per billing cycle |
| `currency` | DepositCurrency | |
| `billingCycle` | SubscriptionBillingCycle | weekly/monthly/quarterly/yearly/oneTime |
| `startDate` | Date | First payment date |
| `category` | String? | e.g. "Productivity", "Entertainment" |
| `iconName` | String? | SF Symbol name (reserved for future use) |
| `isActive` | Bool | False = cancelled |
| `endDate` | Date? | Date subscription was cancelled |
| `createdAt` | Date | Record creation timestamp |

### Computed Properties on Subscription

- `nextPaymentDate` — next scheduled payment date (after today), accounting for `endDate` if cancelled
- `monthlyCost` — normalized monthly amount (yearly → /12, quarterly → /3, weekly → ×4.33)

---

## Architecture

**Pattern:** MVVM + Repository + Service + DI Container

```
View
  └─► ViewModel (@MainActor, ObservableObject)
        └─► Service (protocol, Sendable)
              └─► Repository (protocol, @ModelActor)
                    └─► SwiftData (ModelContext)
```

### Layers

| Layer | Location | Role |
|-------|----------|------|
| Views | `View/` | SwiftUI views, no business logic |
| ViewModels | `ViewModel/` | State management, async coordination |
| Services | `Service/` | Business logic, aggregation |
| Repositories | `Model/*Repository.swift` | SwiftData CRUD, `@ModelActor` isolated |
| Models | `Model/` | SwiftData `@Model` classes |
| APIClient | `APIClient/` | Tradernet REST API (portfolio, cash operations) |
| DIContainer | `Service/DIContainer.swift` | Wires all dependencies, passed as `.environmentObject` |

### Key Design Decisions

- **No Combine** — all async work uses `async/await`
- **@ModelActor repositories** — SwiftData access is actor-isolated to avoid concurrency issues
- **InMemory implementations** — every repository has an in-memory variant for unit tests and SwiftUI previews
- **SwiftData schema** — `Subscription` model defined in `AppSchema.swift`; add `VersionedSchema` + `SchemaMigrationPlan` if stored properties ever change
- **Language switching** — `LanguageBundle` swizzles `Bundle.main` via `object_setClass`; `.id(localeIdentifier)` on root view forces full view tree rebuild on language change

---

## Localization

Two languages supported: **Russian (`ru`)** and **English (`en`)**.

- All user-visible strings are in `Resources/Localizable.strings/{en,ru}`
- Language is stored in `UserDefaults` key `App_LocaleIdentifier`
- Switching language in Settings calls `LanguageBundle.set(languageCode:)` **before** updating `@AppStorage` to ensure the bundle is ready when SwiftUI re-renders
- The root view uses `.id(localeIdentifier)` — changing language rebuilds the entire UI from scratch, guaranteeing all strings are re-evaluated in the new language

---

## CSV Export & Import

### Export

Available in Settings → Export. Shares a `.csv` file via the system share sheet (AirDrop, Files, Mail, etc.).

**Deposits CSV columns:**
```
ID, Title, Bank, Amount, Currency, OpenDate, CloseDate, AnnualRate%, CreatedAt
```

**Subscriptions CSV columns:**
```
ID, Title, Category, Amount, Currency, BillingCycle, StartDate, EndDate, IsActive, CreatedAt
```

Dates are ISO 8601 format. Numbers use `.` as decimal separator.

### Import

Available in Settings → Import. Opens the system file picker. Supports `.csv` and `.txt` files.

**Deduplication:** Records with an ID already present in the database are skipped (not duplicated).

**Result alert** shows: imported / skipped / failed counts.

**Encoding support:** UTF-8 (with and without BOM), Windows-1252, ISO Latin-1, UTF-16.

**Round-trip:** Export from Rentivo → Import back into Rentivo works without data loss.

---

## Notifications

The app uses `UNUserNotificationCenter` for local push notifications. Permission is requested when the first deposit or subscription is saved.

| Trigger | Lead time | Message |
|---------|-----------|---------|
| Deposit closing | 7 days before `closeDate` | "Your deposit is closing soon" |
| Subscription payment | 1 day before `nextPaymentDate` | "Payment due tomorrow: [title] [amount] [currency]" |

Notifications are identified by `deposit-<UUID>` and `subscription-<UUID>`. Re-saving an item replaces its existing notification.

---

## Known Limitations & Roadmap

### Current Limitations

- **Portfolio tab hidden** — Tradernet integration exists (`APIClient.swift`) but the tab is removed from the UI pending proper authentication flow
- **No iCloud sync** — data lives only on the device; use CSV export for manual backup
- **No widget** — Home Screen widget is not yet implemented

### Planned (Roadmap)

| Phase | Feature |
|-------|---------|
| Design | Home screen summary card (total deposits + monthly spend) |
| Design | Deposit progress bar (time elapsed / total term) |
| Auth | Sign in with Apple |
| Portfolio | Re-enable portfolio tab with Yahoo Finance quotes |
| Sync | CloudKit or REST backup API |
| Widget | Home Screen widget with quick summary |
