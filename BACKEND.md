# Kudi9ja — Backend Specification

Everything a backend team needs to build the server behind the Kudi9ja mobile
app: the entities, the money rules, the state machines, the API surface, the
permissions, and the things the client currently fakes that the server must
own.

**Legal entity:** Quadrilateral Technologies Limited (**RC 1657731**),
Lagos, Nigeria. Kudi9ja is its product. Every contract, receipt and legal
document names the company, not the product.

**Contacts:** `support@kudi9ja.com` (general) · `legal@kudi9ja.com` (terms) ·
`privacy@kudi9ja.com` (data) · +234 800 5834 952 · WhatsApp +234 805 679 1426,
+234 803 630 0582.

---

## 0. Read this first

The Flutter client is **complete and running**, but it is **device-local**:
every model is persisted to `shared_preferences` behind a single class,
`StorageService`. There is no network call anywhere in the app.

That is deliberate. `StorageService` is the seam — swap that one class for an
API client and nothing above it changes. This document describes what the API
behind that seam has to do.

Two consequences to keep in front of you:

1. **The client is not the source of truth and must stop behaving as if it
   is.** Balances, interest, credit scores and loan pricing are all computed
   client-side today. Every one of those calculations must move to the server
   and the client must display what the server returns. The formulas here are
   the specification; the Dart is the current reference implementation.
2. **Anything the client can lie about, it will.** Balance, plan maturity,
   loan eligibility and admin role are all trivially forgeable once there is
   a network. The server re-derives all of them.

### Where the rules live in the code

| Concern | File |
|---|---|
| Product constants (shipped defaults) | `lib/core/constants/app_config.dart` |
| Live, admin-tunable settings | `lib/data/models/platform_settings.dart` |
| Every money formula | `Finance` in `lib/data/models/models.dart` |
| All entities | `lib/data/models/` |
| Every operation | `lib/state/app_state.dart` |
| Persistence seam | `lib/data/services/storage_service.dart` |
| Hashing, OTP, references | `lib/data/services/security_service.dart` |
| Legal documents (as data) | `lib/data/legal/` |

---

## 1. The golden rules

These are invariants. If an implementation choice breaks one of them, the
choice is wrong.

1. **Kudi9ja issues no account numbers.** Money leaves the wallet to a bank
   account the customer already holds, in their own name. What each customer
   has is a **customer reference** (`K9-A1B2C3`) for matching payments — it
   is not payable into.
2. **No money enters a wallet without an admin confirming it** against the
   bank statement. There is no card, no USSD, no instant credit. Bank
   transfer only, with a receipt attached.
3. **Every pay-in has its own unique reference.** Not one per customer —
   one per payment, or two transfers of the same amount on the same day
   cannot be told apart on a statement.
4. **Withdrawals debit at request, not at approval**, so the money cannot be
   spent twice while it is being reviewed. Declining refunds in full.
5. **A running plan or loan keeps the terms it was opened on.** Rate changes
   never rewrite history. Every loan stores the rate it was priced at; every
   savings plan stores its own interest.
6. **Fixed Savings cannot be broken.** The return is paid upfront precisely
   because the principal stays put. The only early release is death or
   permanent incapacity.
7. **Interest is never compounded anywhere in this product.** Savings and
   loan interest are both flat, computed once.
8. **Every admin action is written to an append-only audit log**, with actor,
   category, timestamp and a human-readable before → after.
9. **An admin cannot revoke their own access** — not suspend, demote or
   remove themselves. Self-lockout is impossible by construction.
10. **Passcodes, PINs and passwords are never stored or transmitted in the
    clear**, and never returned by any endpoint.

---

## 2. Money model

### The wallet

A wallet is a **balance plus an append-only ledger**. Every movement writes a
`Transaction` carrying the resulting `balanceAfter`. The balance is the
running total of that ledger and must be reconstructible from it — treat any
divergence as a defect.

The wallet is **not a bank account** and is **not NDIC-insured**. The Terms
say so in those words; do not build anything that implies otherwise.

Customer money paid in sits in the **collection account** (currently Zenith
Bank, 1018548852, Quadrilateral Technologies Ltd — all three admin-settable).

### The four ways money moves

| Direction | Route | Approval |
|---|---|---|
| **In** | Bank transfer to the collection account, claimed in-app with a receipt | **Admin confirms** |
| **Out** | Transfer to the customer's own bank account | **Admin approves** |
| **Internal** | Wallet ↔ savings, loan disbursement, loan repayment, thrift | Automatic |
| **Earned** | Savings interest, target bonus, thrift payout | Automatic |

---

## 3. Data model

Types are given as JSON. Enums are serialised **by index** in the current
client — the server should prefer strings and the client will be adapted;
both forms are listed.

### 3.1 User

```json
{
  "id": "uuid",
  "fullName": "string",
  "email": "string, unique, lowercased",
  "phone": "string, 11 digits",
  "dateOfBirth": "ISO-8601",
  "gender": "Female | Male | Prefer not to say",
  "bvn": "string, 11 digits",
  "nin": "string, 11 digits",
  "address": "string",
  "state": "one of the 36 states + FCT",
  "payoutBank": "string",
  "payoutAccountNumber": "string, 10 digits",
  "createdAt": "ISO-8601",
  "kycTier": "tier0 | tier1 | tier2",
  "emailVerified": "bool",
  "phoneVerified": "bool",
  "biometricsEnabled": "bool",
  "securityQuestion": "string",
  "securityAnswer": "hash, never returned"
}
```

**Derived, server-side:**

- `customerRef` — `K9-` + first 6 hex of the id, uppercased. Stable forever.
- `hasPayoutAccount` — both payout fields non-empty.

**Never returned by any endpoint:** `securityAnswer`, and the password,
passcode and PIN hashes.

**KYC tiers:** `tier0` Unverified · `tier1` Verified · `tier2` Fully
Verified. Tier gates what an account may do; the client currently assumes
tier2 for everyone, which the server must stop doing.

### 3.2 Transaction (the ledger)

```json
{
  "id": "uuid",
  "kind": "deposit | withdrawal | transfer | savingsLock | interestPayout |
           savingsRelease | loanDisbursement | loanRepayment | fee",
  "amount": "number, always positive",
  "description": "string, shown to the customer",
  "date": "ISO-8601",
  "balanceAfter": "number",
  "reference": "string",
  "counterparty": "string",
  "status": "pending | successful | reversed"
}
```

**Credits** (increase the balance): `deposit`, `interestPayout`,
`savingsRelease`, `loanDisbursement`. Everything else debits.

**Status:** almost everything settles `successful` immediately. A withdrawal
is written `pending` and becomes `successful` on approval or `reversed` on
decline. A reversed transaction is never deleted — the ledger is append-only,
and the refund is a state change on the same row plus a description change.

**Reference format:** `PREFIX-<base36 timestamp><base36 noise>`, uppercased.

### 3.3 Savings plan

```json
{
  "id": "uuid",
  "title": "string",
  "type": "fixed | target",
  "principal": "number",
  "lockDays": "integer",
  "interestPaid": "number",
  "startDate": "ISO-8601",
  "maturityDate": "ISO-8601",
  "status": "active | matured | withdrawn | broken",
  "targetAmount": "number, target plans only",
  "emoji": "string",
  "autoFrequency": "daily | weekly | monthly, target only",
  "autoAmount": "number, target only",
  "nextAutoRun": "ISO-8601, target only",
  "autoEnabled": "bool",
  "contributions": "integer, how many deposits have gone in",
  "bonusRate": "number, target only — the rate fixed at creation",
  "bonusPaid": "bool"
}
```

### 3.4 Loan

```json
{
  "id": "uuid",
  "principal": "number",
  "tenureMonths": "integer, 1..24",
  "flatRate": "number, fixed at disbursement",
  "processingFee": "number",
  "purpose": "string",
  "disbursedAt": "ISO-8601",
  "dueDate": "ISO-8601",
  "amountRepaid": "number",
  "status": "pending | active | repaid | overdue | rejected"
}
```

**Derived:** `totalInterest = principal × flatRate` ·
`totalRepayable = principal + totalInterest` ·
`monthlyRepayment = totalRepayable / tenureMonths` ·
`outstanding = totalRepayable − amountRepaid` (floored at 0) ·
`schedule` (below) · `installmentsPaid`.

**Schedule:** `tenureMonths` equal instalments, the *n*th due
`addMonths(disbursedAt, n)`. Each instalment's status is derived by pouring
`amountRepaid` into them oldest-first: `paid` when covered, `partial` when
partly covered, `overdue` when the due date has passed and it is not covered,
otherwise `upcoming`.

### 3.5 Deposit claim (money in)

```json
{
  "id": "uuid",
  "customerId": "uuid",
  "customerName": "string",
  "customerAccount": "the customer reference",
  "amount": "number",
  "claimedAt": "ISO-8601",
  "reference": "K9-A1B2C3-7F4K — unique to this payment",
  "purpose": "wallet | loanRepayment",
  "loanId": "uuid | null",
  "loanPurpose": "string",
  "receiptPath": "the receipt image — REQUIRED",
  "senderName": "string, whose bank account it came from",
  "status": "pending | confirmed | rejected",
  "reviewedAt": "ISO-8601 | null",
  "reviewedBy": "string",
  "note": "string, the reason when rejected"
}
```

The receipt is a real uploaded file server-side, not a local path. Store it
in object storage, serve it to admins over a signed, expiring URL, and keep
it for five years as part of the transaction record.

### 3.6 Withdrawal request (money out)

```json
{
  "id": "uuid — the same id as the pending ledger transaction",
  "customerId": "uuid",
  "customerName": "string",
  "customerAccount": "the customer reference",
  "amount": "number",
  "bank": "string",
  "destinationAccount": "string, 10 digits",
  "requestedAt": "ISO-8601",
  "reference": "string, matches the transaction",
  "status": "pending | approved | declined",
  "reviewedAt": "ISO-8601 | null",
  "reviewedBy": "string",
  "note": "string, the reason when declined"
}
```

The request id **is** the pending transaction id. Approving settles that
transaction; declining reverses it and refunds.

### 3.7 Thrift circle (ajo / esusu / adashe)

```json
{
  "id": "uuid",
  "name": "string",
  "contribution": "number, per member per cycle",
  "frequency": "daily | weekly | monthly",
  "members": [{ "name": "string", "initials": "string", "isMe": "bool" }],
  "startDate": "ISO-8601",
  "createdBy": "uuid",
  "currentRound": "integer, 1-based",
  "roundsPaid": ["integer"],
  "inviteCode": "string",
  "emoji": "string"
}
```

**Derived:** `potSize = contribution × members.length` ·
`myRound` — the round at which this member collects · `isComplete` when
`currentRound > members.length`.

**Members must be existing Kudi9ja accounts.** The client says so on the
name field but cannot enforce it. **The server must**: resolve each member to
a real account and reject a circle containing anyone who is not one.

### 3.8 Admin

```json
{
  "id": "uuid",
  "name": "string, copied from their account",
  "email": "string — THE identity; access is matched on this alone",
  "phone": "string, copied from their account",
  "role": "owner | admin | support | viewer",
  "addedAt": "ISO-8601",
  "addedBy": "string",
  "active": "bool",
  "lastActive": "ISO-8601 | null"
}
```

Granting access creates **no account and no password**. It means: when
somebody signs in with that email, the panel appears. Access is re-checked on
every request. Access may only be granted to an email that already belongs to
an account.

### 3.9 Audit entry

```json
{
  "id": "uuid",
  "actor": "string, who did it",
  "category": "general | settings | team | customer | loan",
  "action": "string, short",
  "detail": "string, human-readable, with before → after",
  "date": "ISO-8601"
}
```

Append-only. No edit, no delete, ever.

### 3.10 Notification

```json
{
  "id": "uuid",
  "kind": "interest | maturity | repaymentDue | repaymentPaid | autoSave |
           thrift | security | general",
  "title": "string",
  "body": "string",
  "date": "ISO-8601",
  "read": "bool",
  "amount": "number | null"
}
```

---

## 4. Product rules and formulas

Every figure below reads from platform settings (§5), not from a constant.
The values given are today's defaults.

### 4.1 Fixed Savings — priced by the day

A lump sum locked for a period the customer picks **in days**, from **30 to
1,825** (5 years).

```
interest = principal × savingsAnnualRate × days ÷ daysPerYear
         = principal × 0.17 × days ÷ 365
```

Nothing rounds to whole months. The interest is **paid into the wallet the
moment the plan is created**, not at maturity.

| Lock | Yield | On ₦100,000 |
|---|---|---|
| 30 days | 1.397% | ₦1,397.26 |
| 60 days | 2.795% | ₦2,794.52 |
| 90 days | 4.192% | ₦4,191.78 |
| 171 days | 7.964% | ₦7,964.38 |
| 365 days | 17.000% | ₦17,000.00 |
| 730 days | 34.000% | ₦34,000.00 |
| 1,825 days | 85.000% | ₦85,000.00 |

**Rules:**

- Minimum ₦5,000, maximum ₦50,000,000 per plan.
- The rate is fixed at creation. Later changes never touch a running plan.
- **Cannot be broken.** `breakPlan` is a no-op on a fixed plan.
- On maturity the principal returns to the wallet in full.
- **Top-ups** are allowed at any time and earn the return for **the days
  remaining**, not the plan's original term, paid upfront like the original.
- On death or permanent incapacity, released early, in full, without penalty.

### 4.2 Target Savings — a goal funded over time

Contributions pulled from the wallet on a schedule. A bonus is paid on the
**final day**, on the total actually saved.

| Term | Bonus |
|---|---|
| 3–5 months | 2.5% |
| 6–11 months | 5% |
| 12 months and above | 10% |

- Minimum term 3 months. A target month counts as **30 days**.
- `perDeposit = goal ÷ runs`, where runs = days/1, days/7 or months.
- **Breaking returns every naira saved, in full; the bonus is forfeited.**
  No break fee, no cut of the principal.
- A missed auto-save is skipped and retried next cycle; the bonus is paid on
  what was saved, not what was intended.

### 4.3 Lending — flat interest, priced by tenure

**Every month from 1 to 24 has its own rate.** Interest is flat: computed
once on the principal, never compounding, never growing.

| Mo | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **%** | 12.5 | 17 | 25 | 32 | 38 | 45 | 51 | 57 | 63 | 68 | 73 | 78 |

| Mo | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **%** | 83 | 88 | 93 | 98 | 102 | 107 | 111 | 116 | 121 | 125 | 130 | 134 |

Two invariants hold across the whole card and are enforced by test:

1. **The total always rises with the tenure** — nobody is better off
   borrowing for longer than they need.
2. **The cost per month always falls** — 12.50%/mo at 1 month, 8.33% at 3,
   6.50% at 12, 5.58% at 24.

> **Months 1–3 are the client's published card. Months 4–24 are provisional**
> — shaped to continue the curve but not yet priced by the business. Confirm
> them before lending against them.

**Amounts:** ₦50,000 to ₦5,000,000. **Tenure:** 1 to 24 months.

**Management fee** (also called the processing fee):

```
principal ≤ ₦500,000  →  flat ₦5,000
principal >  ₦500,000  →  1% of the WHOLE principal, not of the excess
```

₦500,001 is already on the percentage. The two rules meet exactly at the
threshold (1% of ₦500,000 *is* ₦5,000), so the curve is continuous. **The fee
is deducted from the disbursement, never added to the debt.**

```
netDisbursed  = principal − fee
totalInterest = principal × rateFor(tenure)
totalRepayable = principal + totalInterest
instalment     = totalRepayable ÷ tenureMonths
```

**Early settlement** rebates `earlyPayoffRebateShare` (0.5) of the interest
attributable to the months that never started:

```
elapsed   = whole months since disbursement
remaining = tenureMonths − elapsed − 1
rebate    = totalInterest × (remaining ÷ tenureMonths) × 0.5
```

capped at the outstanding balance. No early-settlement charge.

**No late fee and no penalty interest exist.** The Lending Agreement commits
to this in writing: *"Even in default, the amount you owe does not increase."*
Do not add one without changing that document first.

**What a customer is offered** (before the hard maximum):

```
offer = loanBaseCap                              (₦100,000)
      + totalSaved × loanSavingsMultiple         (× 1.5)
      + (creditScore − loanScoreBaseline) × loanScorePerPoint   (× ₦400)
offer = min(offer, headroom, maxLoanAmount)
offer = floor(offer ÷ loanOfferRounding) × loanOfferRounding    (₦5,000)
if offer < minLoanAmount → not eligible
```

`headroom = maxLoanAmount − principal of all open loans`.

### 4.4 Credit score

A score out of 850, built only from what the customer has done with Kudi9ja.

```
score  = creditBaseScore                         (560)
       + min(plans × 18, 90)
       + min(floor(totalSaved ÷ 25,000), 100)
       + min(loansRepaid × 30, 120)
       − 90  if any loan is overdue
       + 40  if fully verified
score  = clamp(score, 300, 850)
```

Every coefficient is admin-settable. This is **Kudi9ja's own view**, not a
credit-bureau score — the Privacy Policy says so, and says the customer may
demand a human review of any automated decision that goes against them.

### 4.5 Wallet limits

- **Daily transfer limit:** ₦1,000,000.
- **Minimum pay-in:** ₦100. **Minimum withdrawal:** ₦500.
- Transfers between Kudi9ja customers are free; withdrawals are free.

---

## 5. Platform settings

All of these are editable from the admin panel, take effect immediately, are
diffed and written to the audit log, and **never rewrite a running plan or
loan**. The server must expose them as a single versioned document.

| Group | Keys |
|---|---|
| **Savings** | `savingsAnnualRate` `minLockDays` `maxLockDays` `daysPerYear` `minSavingsAmount` `maxSavingsAmount` `targetRateShort` `targetRateMedium` `targetRateLong` `targetTierMedium` `targetTierLong` `minTargetMonths` `daysPerSavingsMonth` |
| **Lending** | `loanRates` (map: tenure → rate) `maxLoanTenureMonths` `minLoanAmount` `maxLoanAmount` `earlyPayoffRebateShare` |
| **Management fee** | `flatProcessingFee` `processingFeeThreshold` `loanProcessingFeeRate` |
| **Loan offer** | `loanBaseCap` `loanSavingsMultiple` `loanScoreBaseline` `loanScorePerPoint` `loanOfferRounding` |
| **Credit score** | `creditBaseScore` `creditPointsPerPlan` `creditPlanPointsCap` `creditNairaPerSavingsPoint` `creditSavingsPointsCap` `creditPointsPerRepaidLoan` `creditRepaidPointsCap` `creditOverduePenalty` `creditVerifiedBonus` `creditScoreFloor` `creditScoreCeiling` |
| **Security** | `maxPasscodeAttempts` `lockTimeoutMinutes` `otpResendSeconds` |
| **Wallet** | `dailyTransferLimit` `minDepositAmount` `minWithdrawalAmount` |
| **Thrift** | `minCircleContribution` `minCircleMembers` `maxCircleMembers` |
| **Collection account** | `companyAccountName` `companyAccountNumber` `companyBank` |
| **Switches** | `savingsEnabled` `lendingEnabled` `thriftEnabled` `maintenanceMode` |

**Not settable, deliberately:** passcode length (6) and PIN length (4). Every
stored code is a hash of a code that length; changing it locks out everyone
who already has one.

**Validation the server must enforce:** `minLockDays < maxLockDays` ·
`minLoanAmount < maxLoanAmount` · `savingsAnnualRate > 0` ·
`creditScoreFloor < creditScoreCeiling` ·
`targetTierMedium < targetTierLong` · a rate for every selectable tenure.

---

## 6. Flows and state machines

### 6.1 Sign-up — 8 gated steps

1. **Personal details** — name, email, phone, DOB (**18+ enforced**), gender
2. **Email OTP** — 6 digits, 45-second resend cooldown. **Email is the only
   channel verified. There is no SMS step**; the phone is collected so
   support can reach the customer, not as a second factor
3. **Identity** — BVN (11 digits) + NIN (11 digits) + address + state,
   verified against the issuing institutions
4. **Payout account** — the customer's own bank + 10-digit account number
5. **Password** — strength-checked + security question
6. **Sign-in passcode** — 6 digits, set then confirmed
7. **Transaction PIN** — 4 digits, set then confirmed
8. **Review** — full summary and explicit acceptance of all three legal
   documents

The server must record, against the account: **which version of each document
was accepted, the timestamp, and the device**. The Terms rely on this as
evidence under the Evidence Act 2011.

**BVN/NIN verification is currently simulated** by a 1.5-second delay. It
must become a real call to a licensed verification provider, and the name and
date of birth returned must match what was typed.

**Name matching on the payout account:** the client cannot check that the
bank account belongs to the customer. The server should resolve the account
name and refuse a mismatch — the Terms promise payouts only to the customer.

### 6.2 Money in — the only route

```
Customer taps Add money
   ↓
Server mints a UNIQUE reference for THIS payment:  K9-A1B2C3-7F4K
   ↓  (customer code + 4 random chars, from an unambiguous alphabet)
Customer transfers to the collection account, quoting it as the narration
   ↓
Customer submits the claim IN-APP with the amount, sender name and a RECEIPT
   ↓  claim = pending. Nothing is credited. Balance unchanged.
Admin matches the reference against the bank statement, sees the receipt
   ↓
   ├── Confirm → credit the wallet (or apply to the loan) + notify + audit
   └── Reject  → claim rejected with a reason + notify + audit
```

**A receipt is mandatory.** The claim cannot be submitted without one.

For `purpose = loanRepayment`, confirming credits the wallet **and**
immediately applies the amount to the named loan, so both legs appear in the
ledger.

**Unmatched money:** if a payment arrives that cannot be tied to a customer,
hold it, attempt to trace it, and **return it to source after 30 days**.
Written into the Terms.

### 6.3 Money out

```
Customer requests a withdrawal (prefilled with their payout account)
   ↓
Wallet is debited IMMEDIATELY; a PENDING transaction is written
   ↓  so the same money cannot be spent twice while under review
Admin reviews
   ↓
   ├── Approve → transaction becomes successful; pay out; notify; audit
   └── Decline → transaction REVERSED, refunded in full, reason given
```

Target: reviewed within **one working day**. Only to an account in the
customer's own name.

### 6.4 Loan lifecycle

```
Request (amount, tenure, purpose)
   → affordability + eligibility checked server-side
   → approved: loan created with the rate for THAT tenure, frozen
   → wallet credited with the principal, then debited the fee
     (booked gross then netted, so the ledger shows both)
   → schedule generated
   → repay from wallet, or by bank transfer claimed as a loan repayment
   → settle early → rebate applied
   → fully repaid → status repaid
   → past due with an outstanding balance → status overdue
```

**Cancellation:** the Lending Agreement grants a **24-hour change of mind** —
return the amount received plus the fee within 24 hours, pay **no interest**,
and the loan leaves the record. **This is not implemented in the client.**
Either build it server-side or strike the clause.

### 6.5 Scheduled jobs the server must run

| Job | Cadence | What it does |
|---|---|---|
| **Maturity sweep** | hourly | Flip `active` plans past `maturityDate` to `matured`; stop their auto-save |
| **Overdue sweep** | hourly | Flip `active` loans past `dueDate` with a balance to `overdue` |
| **Auto-save runs** | hourly | Pull due target contributions from the wallet; skip and notify on a short balance; reschedule |
| **Target bonus** | on maturity | Credit the bonus on the final day |
| **Repayment reminders** | daily | Notify before each instalment date |
| **Unmatched pay-ins** | daily | Return to source after 30 days |
| **Dormancy** | daily | Mark accounts with no activity for 12 months dormant, notify, freeze until re-verified |

The client currently does the first three lazily, on app open. That is not
good enough once money is real.

---

## 7. API surface

Derived one-to-one from the operations in `AppState`. Names are suggestions;
the semantics are not.

### Auth and account

| Method | Path | Notes |
|---|---|---|
| `POST` | `/auth/signup` | Full draft; returns the account |
| `POST` | `/auth/otp/send` | Email only |
| `POST` | `/auth/otp/verify` | |
| `POST` | `/auth/signin` | Email + password |
| `POST` | `/auth/passcode/verify` | Sign-in passcode; counts failures |
| `POST` | `/auth/pin/verify` | Transaction PIN; gates every money move |
| `PATCH` | `/auth/passcode` · `/auth/pin` | Change |
| `POST` | `/auth/signout` | |
| `DELETE`| `/account` | Delete; see §10 on retention |
| `GET`   | `/me` | Profile, balance, derived figures |
| `PATCH` | `/me` | Phone, address, state, payout account, **theme** |

### Wallet and payments

| Method | Path | Notes |
|---|---|---|
| `GET` | `/wallet` | Balance + derived totals |
| `GET` | `/transactions` | Filterable: all/deposits/withdrawals/transfers/savings/loans/fees |
| `POST` | `/payins/reference` | Mint a unique reference for a new payment |
| `POST` | `/payins` | Submit a claim (multipart: receipt) |
| `GET` | `/payins` | The customer's claims |
| `POST` | `/withdrawals` | Request; debits immediately |
| `GET` | `/withdrawals` | |
| `POST` | `/transfers` | To another Kudi9ja customer |

### Savings

| Method | Path |
|---|---|
| `GET` `POST` | `/savings/plans` |
| `GET` | `/savings/plans/{id}` |
| `POST` | `/savings/plans/{id}/topup` |
| `POST` | `/savings/plans/{id}/withdraw` (matured only) |
| `POST` | `/savings/plans/{id}/break` (target only) |
| `PATCH` | `/savings/plans/{id}/autosave` |
| `GET` | `/savings/quote?amount&days` — returns interest, maturity, yield |

### Lending

| Method | Path |
|---|---|
| `GET` | `/loans` · `/loans/{id}` |
| `GET` | `/loans/eligibility` — offer, headroom, score |
| `GET` | `/loans/quote?amount&months` — fee, net, interest, total, schedule |
| `POST` | `/loans` — request |
| `POST` | `/loans/{id}/repay` |
| `POST` | `/loans/{id}/settle` — early payoff with rebate |
| `GET` | `/credit-score` — score, band, factor breakdown |

### Thrift

| Method | Path |
|---|---|
| `GET` `POST` | `/circles` |
| `POST` | `/circles/{id}/contribute` · `/circles/{id}/leave` |
| `POST` | `/circles/join` — by invite code |

### Notifications and settings

| Method | Path |
|---|---|
| `GET` | `/notifications` · `POST /notifications/read` · `DELETE /notifications` |
| `GET` | `/settings/public` — rates and limits the app displays |
| `GET` | `/legal/{terms\|privacy\|lending}` — versioned documents |

### Admin

| Method | Path | Permission |
|---|---|---|
| `GET` | `/admin/overview` | any admin |
| `GET` | `/admin/customers` · `/admin/customers/{id}` | any admin |
| `GET` | `/admin/customers/{id}/{transactions\|payins\|withdrawals\|plans\|loans}` | any admin |
| `POST` | `/admin/payins/{id}/{confirm\|reject}` | `canApprovePayments` |
| `POST` | `/admin/withdrawals/{id}/{approve\|decline}` | `canApprovePayments` |
| `POST` | `/admin/loans/{id}/{remind\|writeoff}` | `canActOnLoans` |
| `POST` | `/admin/customers/{id}/{flag\|freeze}` | `canManageCustomers` |
| `GET` `PUT` | `/admin/settings` | `canEditSettings` |
| `GET` `POST` `PATCH` `DELETE` | `/admin/team` | `canManageTeam` |
| `GET` | `/admin/audit` | any admin |

---

## 8. Roles and permissions

| What they can do | Owner | Administrator | Support | Viewer |
|---|:---:|:---:|:---:|:---:|
| See customers and their full records | ✓ | ✓ | ✓ | ✓ |
| Read the audit log | ✓ | ✓ | ✓ | ✓ |
| Confirm pay-ins and approve withdrawals | ✓ | ✓ | ✓ | — |
| Act on loans — remind, write off | ✓ | ✓ | ✓ | — |
| Flag or freeze a customer | ✓ | ✓ | ✓ | — |
| Change rates, limits and switches | ✓ | ✓ | — | — |
| Add, promote, suspend or remove admins | ✓ | — | — | — |

Enforce **server-side on every request**. The client's role check is a
convenience for hiding buttons, nothing more.

**Bootstrap:** the first account on a device becomes owner. That is a
development affordance — the server needs a deliberate seeding process.

**Self-lockout is impossible:** an admin may not change their own role,
suspend themselves or remove their own access.

---

## 9. Security

| Concern | Requirement |
|---|---|
| **Password, passcode, PIN** | Salted one-way hash. Currently SHA-256 with a compile-time pepper — **the server must use a slow KDF (argon2id or bcrypt) with a per-user salt and a pepper held in secret config, never in source.** |
| **The current pepper** | `SecurityService._pepper` is a literal in the repo, now in public git history. Rotate it as part of the migration. |
| **Never returned** | Any hash, the security answer, full BVN/NIN (mask to last 4). |
| **Transaction PIN** | Required for every money movement. Verify server-side; never trust a client assertion that it was entered. |
| **Lockout** | 5 failed passcode attempts. Track server-side. |
| **Idle lock** | 2 minutes — client concern, but the session token should be short-lived and refreshable. |
| **Biometrics** | Performed by the device; the template never leaves it and never reaches the server. It is a local unlock, **not** an authentication factor. |
| **OTP** | 6 digits, single-use, short expiry, rate-limited, resend cooldown 45s. The client currently displays the code on screen for testability — **that must never ship against a real backend.** |
| **Receipts** | Private storage, signed expiring URLs, admin access only, audit every view. |
| **Idempotency** | Every money-moving endpoint takes an idempotency key. A retried pay-in claim or withdrawal must not double. |

---

## 10. Compliance obligations

These come from the three legal documents shipped in the app
(`lib/data/legal/`), which are binding on the company. The backend has to
make them true.

- **NDPA 2023.** Lawful basis per purpose. Data subject rights: access,
  rectification, erasure, restriction, objection, portability, withdraw
  consent, human review of automated decisions. **Answer within 30 days.**
  Build export and deletion endpoints.
- **Breach reporting.** Notify the NDPC within **72 hours** of becoming aware,
  and affected customers without undue delay.
- **AML retention.** Identity and transaction records for **at least 5 years**
  after the relationship ends. Deletion requests cannot override this — soft
  delete, do not hard delete.
- **Automated decisions.** A declined or reduced loan must record the reasons
  and support a human review request.
- **Credit reporting.** Report loan existence, performance and settlement to
  licensed bureaux; obtain reports when assessing.
- **Collections conduct.** Never contact the borrower's phone contacts,
  family or employer. Contact only between **8am and 8pm**, not on public
  holidays. Log every collections contact. Bind partners contractually.
- **Complaints.** Acknowledge within 24 hours with a reference; substantive
  answer within 10 working days; resolve within 30 days.
- **Change notice.** 30 days' notice before a new charge, an increase, or a
  material change to the documents.
- **Document versioning.** Serve versioned legal documents and record which
  version each customer accepted.

---

## 11. What the client currently fakes

Everything here is a placeholder that the backend replaces. This is the
migration checklist.

| Faked today | Must become |
|---|---|
| **All persistence** — `shared_preferences` on device | Server database; `StorageService` becomes an API client |
| **BVN/NIN check** — 1.5s delay, always passes | Real verification provider; name and DOB must match |
| **OTP** — generated on device and shown on screen | Server-issued, emailed, never returned to the client |
| **Balance and interest** | Server-computed; the client displays only |
| **Credit score and eligibility** | Server-computed |
| **Loan pricing** | Server-quoted; the client never prices a loan |
| **Admin role** — from the device's account list | Server-side claim, checked per request |
| **First account = owner** | Deliberate seeding |
| **Sample customers** — 3 illustrative rows badged SAMPLE | Real customer list; delete the fixtures |
| **Thrift members** — typed names, unverified | Resolved to real accounts, invitations, per-member debits |
| **Receipt** — a local file path | Uploaded object, signed URLs |
| **Maturity, overdue, auto-save** — lazily on app open | Scheduled jobs |
| **Transfers** — no real recipient resolution | Name enquiry then transfer |
| **Payout account** — unverified | Name enquiry; refuse a mismatch |

---

## 12. Light mode

**Built.** The app ships dark and light, chosen in **Profile → Appearance**:
*Match my phone · Light · Dark*, defaulting to dark.

The preference is stored on the device today (`k9.themeMode`). **It belongs on
the account**: add `themeMode: system | light | dark` to the user record,
return it on `GET /me` and accept it on `PATCH /me`, so the choice follows the
customer between devices.

---

## 13. Open decisions for the business

Flagged during implementation. None of these are blocking, but all need an
answer before real money moves.

1. **Licensing.** Taking deposits and paying 17% is deposit-taking, which
   needs a CBN licence. Digital lending needs a state money-lender's licence
   and FCCPC approval. The legal documents deliberately claim no licence.
2. **Loan rates for months 4–24 are provisional.** Confirm them.
3. **Flat interest over two years** invites comparison with reducing-balance
   lenders. At 24 months, ₦5,000,000 repays ₦11,500,000 at the provisional
   rates.
4. **The 24-hour loan cancellation right** is written into the agreement but
   not built.
5. **GSI mandate** is not included. Add it if you intend to use it.
6. **Sign-up requires a payout account.** Consider allowing an account to be
   opened without one.
7. **Operational promises** in the documents that the backend must staff for:
   1-working-day pay-in and withdrawal review, 24-hour complaint
   acknowledgement, 10-working-day investigations, 8am–8pm collections.

---

## 14. Reference values

```
Savings     17% p.a., 365-day year, 30–1,825 day locks
            ₦5,000 min · ₦50,000,000 max · interest paid upfront
Target      2.5% / 5% / 10% at 3–5, 6–11, 12+ months; 30-day months
Loans       ₦50,000 – ₦5,000,000 · 1–24 months · flat, priced per tenure
            12.5% at 1 month … 134% at 24 months
Fee         ₦5,000 flat to ₦500,000; 1% of the whole amount above
Wallet      ₦1,000,000 daily transfer limit
            ₦100 min pay-in · ₦500 min withdrawal
Thrift      ₦1,000 min contribution · 2–12 members
Security    6-digit passcode · 4-digit PIN · 5 attempts · 2-minute idle lock
Credit      300–850, base 560
Collection  Zenith Bank · 1018548852 · Quadrilateral Technologies Ltd
```

---

*Generated from the Kudi9ja Flutter client at commit `3e11542`. Where this
document and the code disagree, the code is the current behaviour and this
document is the intent — reconcile deliberately, not by assumption.*
