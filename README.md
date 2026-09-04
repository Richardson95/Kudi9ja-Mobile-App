# Kudi9ja — Mobile App

**Pay smart. Pay global.**

A Flutter microlending and high-yield savings app. Gold-on-black, built around two
promises: **17% a year on savings, paid the moment you lock**, and **up to ₦5,000,000
of credit** over anything from one month to two years, with a repayment plan you
can read at a glance.

---

## Product rules

`AppConfig` holds the compiled-in defaults; the live values sit in
`PlatformSettings` and are editable from the admin panel. Every calculation runs
through `Finance` in `lib/data/models/models.dart`, which reads the live
settings — so an admin rate change takes effect app-wide immediately. The UI
never does its own maths.

| Rule | Value |
|---|---|
| Fixed Savings | **17% per annum**, paid to the wallet the instant the plan starts |
| Fixed lock period | **30 days → 5 years** (1,825 days), chosen in days |
| Fixed early exit | **None — a Fixed plan can never be broken** (top-ups welcome) |
| Target Savings | Bonus on the final day: **2.5%** (3–5mo), **5%** (6–11mo), **10%** (1yr+) |
| Target minimum term | **3 months** |
| Target early exit | Any time — principal returned in full, **bonus forfeited entirely** |
| Minimum savings | ₦5,000 |
| Minimum loan | **₦50,000** |
| Maximum loan | **₦5,000,000** |
| Loan rate | Flat on the amount borrowed, **a separate rate for every tenure**, all admin-editable |
| Loan tenure | Any month from **1 to 24** |
| Processing fee (management fee) | **Flat ₦5,000** up to and including ₦500,000; above that, **1% of the whole amount** |
| Fee is | **Deducted from the loan before it reaches the wallet** |

### The two savings products

**Fixed Savings** — one lump sum, locked for a term the customer picks **in
days**, anywhere from 30 to 1,825. Interest is pro-rated straight off the annual
rate:

```
interest = principal × 0.17 × days ÷ 365
```

Nothing is rounded to whole months, so an odd term is priced exactly and the
customer sees the naira figure the instant they pick the number:

| Lock | Yield | ₦100,000 earns |
| --- | --- | --- |
| 30 days (1 month) | 1.397% | ₦1,397.26 |
| 90 days (3 months) | 4.192% | ₦4,191.78 |
| 171 days (5 months, 3 weeks) | 7.964% | ₦7,964.38 |
| 365 days (1 year) | 17.000% | ₦17,000.00 |
| 730 days (2 years) | 34.000% | ₦34,000.00 |
| 1,825 days (5 years) | 85.000% | ₦85,000.00 |

Periods are always shown in days with the human equivalent in brackets, and the
picker offers presets, a slider and a field for typing an exact number.

The whole return is paid into the wallet **immediately**, free to spend the same
day. You can **top it up whenever you like**, and each top-up earns its own 17%
pro-rated over the days still to run — not the plan's original term — paid to
the wallet immediately.

What you cannot do is take money out. There is no early exit at any price — the
principal is released only on the maturity date. The app says so before you
commit, and `breakPlan()` is a hard no-op on a Fixed plan.

**Target Savings** — you name a **total** and a **term**; the app works out what
has to go in each day or week and moves it automatically. A month counts as
30 days, so six months is exactly 180.

```
Save ₦100,000 over 6 months, daily
  →  180 deposits of ₦555.56
  →  5% bonus (the 6–11 month tier) = ₦5,000 on the final day
  →  ₦105,000 at maturity
```

The bonus **rises with the term** — commit longer, earn more:

| Term | Bonus |
|---|---|
| 3 – 5 months | **2.5%** |
| 6 – 11 months | **5%** |
| 1 year and above | **10%** |

The rate is snapshotted when the plan opens, so a later admin change never
alters an existing plan. Nothing is paid along the way; the bonus lands as one
payment on the final day.

It **can be broken at any time**. Every naira saved comes straight back — no
penalty, no deduction — but the entire bonus is forfeited. There is no partial
payout.

If the wallet is short on a due date the deposit is skipped rather than
overdrawing the customer, and retried next cycle. The bonus is calculated on
what was **actually** saved, so missed deposits reduce it proportionally rather
than paying out on money that never arrived.

### The loan rate

A single **flat charge** on the amount borrowed. It never compounds and it does
not vary with the amount — only with the **tenure**:

**Every month from 1 to 24 carries its own rate**, held in
`AppConfig.loanRatesByTenure` and editable one tenure at a time from the admin
panel. A loan stores the rate it was priced at, so a later change never touches
a loan already running.

| Tenure | Flat rate | Per month | Borrow ₦200,000 |
| --- | --- | --- | --- |
| 1 month | 12.5% | 12.50% | ₦225,000 in one instalment |
| 2 months | 17% | 8.50% | ₦117,000 × 2 |
| 3 months | 25% | 8.33% | ₦83,333 × 3 |
| 6 months | 45% | 7.50% | ₦48,333 × 6 |
| 12 months | 78% | 6.50% | ₦29,667 × 12 |
| 18 months | 107% | 5.94% | ₦23,000 × 18 |
| 24 months | 134% | 5.58% | ₦19,500 × 24 |

The full card runs 12.5, 17, 25, 32, 38, 45, 51, 57, 63, 68, 73, 78, 83, 88, 93,
98, 102, 107, 111, 116, 121, 125, 130, 134 — one rate for each month from 1 to
24. It is built on two rules, and `finance_test.dart` fails the build if an edit
breaks either:

1. **The total always rises with the tenure**, so nobody is ever better off
   borrowing for longer than they need.
2. **The cost per month always falls**, because the fixed cost of writing a loan
   spreads over more months.

> Months 1–3 are the published rate card. **Months 4–24 are provisional** —
> shaped to continue that curve, but set them in **Admin → Settings → Lending**
> before lending against them in anger. The repayment period is
a slider rather than chips — two years of options will not fit on a phone — and
it shows the rate and the cost per month for the tenure under the thumb, because
the tenure choice **is** a price choice and should never be made blind.

Rates print through `PlatformSettings.ratePct`, which keeps a half point
(`12.5%`) and drops a trailing zero (`17%`), so no surface can round a rate into
something the customer is not actually charged.

Loans run for a **maximum of 24 months**, after which principal and interest are
due back in full. `settings.loanRateFor(months)` is the single source of the
rate; a loan stores the rate it was priced at, so later rate changes never touch
a running loan.

Settling early rebates **half the flat interest attributable to the months that
never started** — on a 3-month loan cleared after one month, that is half of a
third of the interest.

### The processing fee

Also called the **management fee**. A flat **₦5,000** on every loan from ₦50,000
up to *and including* ₦500,000. The moment a loan goes past that — ₦500,001
counts — the fee becomes **1% of the whole principal**, not 1% of the part above
the threshold. The two rules meet exactly at the threshold —
1% of ₦500,000 *is* ₦5,000 — so the fee curve is continuous with no jump at the
boundary.

The fee always comes **out of the disbursement**, never on top of the debt:

```
Borrow ₦200,000  →  ₦5,000 fee  →  ₦195,000 lands in your wallet
                                   ₦250,000 repayable over 3 months
```

Repayment is still calculated on the full ₦200,000 principal. Every screen that
touches a loan states the net figure: a live banner under the amount field, the
fee line in the breakdown, the PIN confirmation sheet, the approval receipt, and
the loan's own terms panel.

---

## Security

Two independent codes, both salted-SHA-256 hashed before they ever touch disk
(`SecurityService`). A plaintext passcode is never stored or compared.

- **Sign-in passcode** — 6 digits. Demanded every time the app is opened or comes
  back from the background after 2 minutes idle. Five wrong tries signs the user
  out to full email + password.
- **Transaction PIN** — 4 digits, separate from the passcode. Every transfer,
  savings lock, withdrawal and repayment passes through `confirmWithPin()`.
- Both reject repeated digits (`111111`) and straight runs (`123456`).
- Optional biometric unlock (`local_auth`) when the device supports it.

### Signup verification — 8 gated steps

1. Personal details — name, email, phone, DOB (18+ enforced), gender
2. **Email OTP** — 6-digit code, 45-second resend cooldown. Email is the only
   channel verified; the phone number is collected so support can reach a
   customer, not as a second factor, so there is no SMS step to wait on
3. **Identity** — BVN (11 digits) + NIN (11 digits) + address + state, run through
   a verification check that must pass before the step unlocks
4. **Payout account** — the customer's own bank and account number
5. Password — strength meter with live requirement checks + security question
6. Sign-in passcode — set, then confirm
7. Transaction PIN — set, then confirm
8. Review — full summary, explicit terms acceptance

### Kudi9ja issues no account numbers

There is no Kudi9ja account number, and nothing is minted from a phone number.
Money earned or borrowed lands in the wallet, and leaves it to **a bank account
the customer already holds in their own name**, nominated at sign-up and
changeable at any time. The withdrawal screen starts on that account and lets
them send an individual payout somewhere else.

What each customer does have is a short **customer reference** (`K9-A1B2C3`,
derived from their id) — an identifier for matching a bank transfer to them and
for the admin queues. It is not payable into, and `app_boot_test.dart` fails the
build if anything reintroduces a generated account number.

---

## Savings

| Product | Return | Timing | Breakable |
|---|---|---|---|
| **Fixed Savings** | 17% p.a. | Paid upfront, day one | **Never** |
| **Target Savings** | 2.5% / 5% / 10% by term | Paid on the final day | Yes — bonus forfeited |
| **Ajo Circle** | The pot | Your turn in the rotation | Leave any time |

Ajo Circles sit alongside the two personal plans as a group product: everyone
contributes each cycle and one member collects the whole pot per round.

Supporting screens: a **savings calculator** with a live growth chart; per-plan
detail with a progress ring, and — depending on the product — either a top-up
and break control, or a sealed notice explaining there is no early exit; circle
detail showing the full payout rotation, who has paid, and the invite code.

## Lending — the full credit lifecycle

- **Loan calculator** — model any amount and tenure, with the complete dated
  repayment schedule, before applying.
- **Amortisation schedule** — every instalment with its due date and live status
  (paid / part paid / upcoming / overdue), derived from what has actually been repaid.
- **Early settlement** — clear a loan ahead of schedule and get back **half the
  flat interest on the months that never started**, booked as a rebate.
- **Credit score breakdown** — the score out of 850 with every contributing
  factor shown and scored: KYC, savings habit, amount saved, repayment history,
  and an overdue penalty. Plus concrete steps to raise it.
- **Auto-debit** — opt in to have instalments pulled on their due dates.
- **Due reminders** — the next instalment surfaces on the dashboard and the
  borrow tab, colour-coded as it approaches and after it passes.

## Money in — the collection account

Every naira a customer pays in goes to one company account:

```
Quadrilateral Technologies Ltd
1018548852
Zenith Bank
```

Whether they are funding a wallet, opening savings or repaying a loan, that is
where it goes. **Bank transfer is the only way in** — there is no card and no
USSD, and no path anywhere in the app credits a wallet without approval.

Every pay-in mints **its own reference** the moment the screen opens:

```
K9-A1B2C3-7F4K
^^^^^^^^^ the customer   ^^^^ this payment
```

The customer quotes it as the transfer narration. Because it is per-payment and
not per-customer, two transfers of the same amount on the same day are still
tellable apart on a bank statement, and the embedded customer code means an
admin reading a narration can find the person without a lookup.

**Nothing is credited on the customer's word.** The flow is:

1. Transfer to the collection account
2. Screenshot the receipt from their bank app
3. Upload it in the app and submit
4. An admin matches it against the statement and confirms

Only then does money move. On confirmation a wallet-funding claim credits the
wallet; a **loan repayment** claim is credited and applied to the loan in one
step, so the ledger shows both legs. Rejecting reverses nothing — nothing was
ever credited — and passes the reason back to the customer.

The account is editable from **Rates → Collection account**, and changing it
changes what every customer is told to pay into, everywhere.

## Withdrawals go through approval

A withdrawal is a **request**, not an instant transfer. The money leaves the
wallet the moment it is submitted — so it cannot be spent twice while under
review — and the transaction sits at **pending** until an admin decides.

- **Approve** → settles the record and marks the transaction successful. No
  second debit; the money already moved.
- **Decline** → refunds the customer in full, marks the original transaction
  **reversed**, and passes on the reason given.

Either way the customer is notified and the decision is written to the audit
log with the admin's name. A decision is one-way: a settled request cannot be
approved twice or declined after the fact.

Pending requests are surfaced three ways in the panel — a red count badge on
the **Payouts** tab, a callout on Home, and the queue itself, filterable by
pending / approved / declined.

## Across the app

- **Notification centre** — persisted, unread-badged. Interest payouts, maturity,
  Auto Save runs, circle rounds and repayment events all land here.
- **Receipts** — a formal, perforated-ticket receipt per transaction, copyable
  as text for sharing or record-keeping.
- **Insights** — net-worth split (wallet vs locked vs owed), money in/out,
  interest earned net of fees, and a pie breakdown of where money went.

## Admin panel

Reachable only from a **"Go to admin"** card that renders on the dashboard for
accounts listed on the admin team — ordinary customers never see it. Access is
matched on the signed-in email address, and is re-checked on every build, so
revoking someone ejects them immediately rather than at their next cold start.

**Bootstrap:** the first account opened on a device becomes the **owner**, so the
panel is reachable at all. Every later admin is added from inside it.

**Granting access is a search, not a form.** An owner searches people who have
already signed up and picks one — there is no name, email or phone to type.
Membership is keyed on the account's **email address** and nothing else; the
name and phone shown in the team list are copied off that account. Adding
somebody creates no account and no password: it only means that when they sign
in with that address, the panel appears. Remove them and it disappears on the
next build.

Because nothing is typed, an owner cannot grant the panel to an address that
belongs to nobody — the old form would happily accept a typo and leave a
dangling grant.

### Five sections

| Section | What it does |
|---|---|
| **Overview** | Book-wide metrics, live rate summary, saved-vs-lent chart, product switch states |
| **Users** | Searchable list → full record: KYC, BVN/NIN, address, balances, plans, loans, credit score, and the **complete transaction history** filterable by deposit / withdrawal / transfer / savings / loan / fee. Flag, freeze, copy contact |
| **Payments** | Both directions. **Money in:** claimed transfers with the customer's receipt shown inline, tap to enlarge — confirm or reject. **Money out:** the withdrawal queue |
| **Lending** | Exposure, collections and fee income; every loan with its schedule; overdue reminders |
| **Controls** | Every rate, limit and switch (below) |
| **Team** | Grant the panel to an existing account, promote, suspend and remove admins |

Plus an **audit log** (top-right) — an append-only timeline of every rate change,
team change and customer action, with actor and timestamp.

### What Controls can change

**Every number in the product is set here.** Nothing economic is compiled in
beyond its default — `AppConfig` holds the shipped values, `PlatformSettings`
holds the live ones, and every calculation in the app reads the live one.

| Group | Settable |
|---|---|
| **Savings** | Fixed rate; minimum and maximum lock; minimum and maximum plan size; all three Target bonus rates; the two month boundaries those tiers switch at; minimum Target term; how many days count as a Target month |
| **Lending** | A separate flat rate for **every tenure from 1 to 24 months**, edited one at a time from a grid of the whole table; maximum tenure; minimum and maximum loan; the early-settlement rebate share |
| **Management fee** | Flat amount, threshold, and the rate above it — with a live preview of what customers at five loan sizes are charged and receive, including the ₦500,001 boundary |
| **What a customer is offered** | Base offer, the multiple applied to what they have saved, the amount added per credit-score point, the score baseline, and the rounding — with a preview of three example customers |
| **Credit score** | Starting score, points per savings plan and their cap, naira saved per point and its cap, points per repaid loan and their cap, the overdue penalty, the verification bonus, and the floor and ceiling — with a preview of four example customers |
| **Security** | Passcode attempts before lockout; idle minutes before the app locks |
| **Wallet** | Daily transfer limit; welcome bonus |
| **Collection account** | Bank, account name and number |
| **Switches** | Savings, lending, Ajo circles, maintenance mode |

| **Pay-in and payout** | Smallest pay-in we will match; smallest withdrawal |
| **Thrift circles** | Minimum contribution per cycle; smallest and largest circle |
| **Sign-up** | One-time code resend delay |

**Every value can be typed, not just nudged.** Sliders and +/− steppers remain,
but each figure is also a tap target: tapping opens a keypad sheet with the
current value, the allowed range, and Save. Nobody has to drag a slider from 17
to 85, and the bounds are enforced on the typed value exactly as on the slider.

**Passcode and PIN lengths are deliberately not settable.** Every customer code
is stored as a hash of a code of that length, so changing it would lock out
everyone who already has one. The panel says so where the control would be.

A settings round-trip test changes every field away from its default and
asserts none is lost in storage, so a setting added without a persistence entry
fails the build rather than silently reverting on the next app start.

Changes are confirmed with a diff of exactly what will move, applied app-wide
immediately, and written to the audit log. **Existing plans and loans keep the
terms they were opened on** — a rate change never rewrites history.

### Roles

| What they can do | Owner | Administrator | Support | Viewer |
|---|:---:|:---:|:---:|:---:|
| See customers and their full records | ✓ | ✓ | ✓ | ✓ |
| Read the audit log | ✓ | ✓ | ✓ | ✓ |
| Confirm pay-ins and approve withdrawals | ✓ | ✓ | ✓ | — |
| Act on loans — remind, write off | ✓ | ✓ | ✓ | — |
| Flag or freeze a customer | ✓ | ✓ | ✓ | — |
| Change rates, limits and switches | ✓ | ✓ | — | — |
| Add, promote, suspend or remove admins | ✓ | — | — | — |

Read down the columns and the roles are cumulative: a **Viewer** looks and
changes nothing; **Support** moves money and works customers but cannot reprice
the product; an **Administrator** owns the economics too; only the **Owner**
touches the team.

The panel renders this same table under **Team → What each role can do**, built
from `kAdminCapabilities` — and each row reads the very getter that gates the
real screen, so the table cannot drift from what the panel allows.
`admin_test.dart` pins the whole matrix.

Self-lockout is impossible by construction: an admin cannot suspend, demote or
remove their own access, since each of those would revoke the permission needed
to undo it.

### Customer data honesty

The account on this device is the only real record and is badged **THIS DEVICE**.
The other rows are badged **SAMPLE** — they stand in for the wider book a live API
would return, and are labelled as such everywhere they appear so they can never
be mistaken for genuine customers.

## Structure

```
lib/
  core/
    constants/   app_config.dart (all product rules), app_assets.dart
    theme/       app_colors.dart (gold/black tokens), app_theme.dart
    utils/       formatters.dart (₦ + dates), validators.dart
  data/
    models/      models.dart — AppUser, SavingsPlan, Loan, Installment,
                 Transaction, Finance; thrift.dart; app_notification.dart;
                 admin.dart; platform_settings.dart (live, admin-tunable)
    legal/       legal_models.dart (document blocks), terms_of_service.dart,
                 privacy_policy.dart, lending_agreement.dart
    services/    storage_service.dart, security_service.dart
  state/
    app_state.dart — the single controller: session, wallet, savings,
                     loans, circles, notifications, credit factors,
                     admin team, audit log, platform settings
  widgets/       primitives, inputs, passcode, pin_sheet, result_screen
  features/
    splash/ onboarding/ auth/ (+ signup/steps) shell/
    dashboard/ savings/ (+ thrift/) loans/ wallet/
    notifications/ insights/ profile/ admin/ legal/
```

State is a single `ChangeNotifier` (`AppState`) over `provider`. Persistence is
`shared_preferences` behind `StorageService` — swap that one class for the live
Kudi9ja API and nothing above it changes.

## Legal

Three documents govern a Kudi9ja account, and all three are readable in full
inside the app — from **Profile → Legal**, from the acceptance box in signup,
and (for the Lending Agreement) from the loan request screen.

| Document | Covers |
| --- | --- |
| Terms of Service | The account, the wallet, paying in and out, both savings products, thrift circles, security duties, freezing and closure, liability, complaints, disputes |
| Privacy Policy | What data is collected, the lawful basis for each use, automated credit decisions, who it is shared with, retention, and the rights the NDPA 2023 gives a customer |
| Lending Agreement | The cost of credit in figures, disbursement, repayment, early settlement, default, credit reporting, and the conduct limits we accept when collecting |

They are written as data (`lib/data/legal/`) rather than as prose blobs, and
every rate, fee and limit is interpolated from the live `settings` and priced
through `Finance` — so a document can never quote a number the app is not
actually applying. `test/legal_test.dart` enforces that, and scrolls all three
documents to prove every section renders.

The contracting party throughout is **Quadrilateral Technologies Limited
(RC 1657731)**, of which Kudi9ja is a product. Enquiries route to
`legal@kudi9ja.com` (terms), `privacy@kudi9ja.com` (data) and
`support@kudi9ja.com` (everything else).

## Themes

Kudi9ja ships **dark and light**, chosen in **Profile → Appearance**: *Match my
phone · Light · Dark*. It defaults to **dark** — gold on black is the brand's
home ground, and light mode is a deliberate choice rather than something a
phone setting turns on for a customer who never asked.

`AppColors` used to be compile-time constants, which made a second theme
impossible. The tokens are now getters over an active `AppPalette`, so the same
name means white-on-black or ink-on-warm-white depending on which palette is in
force. `AppTheme.forPalette` applies the palette as it builds, and `MaterialApp`
pins it to whichever theme is actually being painted.

The light gold is **deepened** (`#9A6510`) rather than matched to the brand hex:
the brand gold is legible on black but washes out on white, and a 4.5:1 contrast
floor matters more than an exact match. `theme_test.dart` checks WCAG contrast
for body text, secondary text, gold, text-on-gold and every semantic colour, in
both palettes — a palette edit that hurts legibility fails the build.

## Brand

Assets are the official Kudi9ja marks, recoloured to the gold palette.

| Token | Hex |
|---|---|
| Gold (primary) | `#F1A83B` |
| Deep gold | `#D09133` |
| Black (canvas) | `#000000` |
| Surface | `#141212` |
| Surface alt | `#2A2626` |
| Surface high | `#3B3838` |
| Text primary | `#FFFFFF` |
| Text secondary | `#B8B0A8` |
| Success | `#3FCE86` |

Type is **Figtree** via `google_fonts`, matching the Kudi9ja brand guide.

---

## Running it

```bash
flutter pub get
flutter run                      # on a connected device or emulator
flutter build apk --release      # → build/app/outputs/flutter-apk/app-release.apk
flutter test                     # 112 tests: finance, fees, schedules,
                                 # both savings products, circles, withdrawal
                                 # approvals, receipts, tx filters, admin access,
                                 # settings propagation, security, boot gating
```

Regenerate launcher icons and splash after changing the art:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

---

## Demo mode

The app runs standalone with no backend. OTP codes are generated locally and shown
on the verification screen so the flow is testable end to end; identity checks,
name enquiry on transfers and loan underwriting are simulated with realistic
latency. New accounts open with a ₦2,000 welcome credit so nothing is a dead end.

Replace `StorageService` and the simulated calls in `SecurityService` with the live
API to go to production.
