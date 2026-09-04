import '../../core/constants/app_config.dart';
import '../../core/utils/formatters.dart';
import '../models/platform_settings.dart';
import 'legal_models.dart';

/// The Terms of Service — the master agreement between a customer and
/// [AppConfig.legalEntity]. Rates and limits are read from [settings] so the
/// document can never quote a number the app is not actually applying.
LegalDocument termsOfService() {
  final s = settings;

  return LegalDocument(
    id: 'terms',
    title: 'Terms of Service',
    shortTitle: 'Terms of Service',
    summary:
        'The agreement that governs your Kudi9ja account, your wallet, your '
        'savings and everything else you do in the app.',
    version: '1.0',
    effective: DateTime(2026, 9, 4),
    readMinutes: 18,
    sections: [
      LegalSection('Who you are agreeing with', [
        const LegalText(
          'Kudi9ja is a product of **${AppConfig.legalEntity}** '
          '(**${AppConfig.rcNumber}**), a company incorporated in Nigeria at '
          '${AppConfig.registeredAddress}. In these Terms, "Kudi9ja", "we", '
          '"us" and "our" mean that company. "You" and "your" mean the person '
          'who opens or uses a Kudi9ja account.',
        ),
        const LegalText(
          'A Kudi9ja account may only be opened and used by an individual, in '
          'their own name, for their own benefit.',
        ),
        const LegalDefs([
          ('General support', AppConfig.supportEmail),
          ('Questions about these Terms', AppConfig.legalEmail),
          ('Privacy and your data', AppConfig.privacyEmail),
          ('Phone', AppConfig.supportPhone),
          ('WhatsApp', '+234 805 679 1426 or +234 803 630 0582'),
          ('Address', AppConfig.registeredAddress),
        ]),
      ]),

      LegalSection('These Terms, and the documents that go with them', [
        const LegalText(
          'By ticking the acceptance box when you open your account, and by '
          'continuing to use Kudi9ja afterwards, you agree to these Terms. If '
          'you do not agree with them, do not open an account, and stop using '
          'the app.',
        ),
        const LegalText('Three documents make up your agreement with us:'),
        const LegalList([
          '**These Terms of Service**, which cover your account, your wallet, '
              'savings and thrift circles.',
          '**The Privacy Policy**, which explains what we do with your '
              'personal data.',
          '**The Lending Agreement**, which applies only if you borrow from '
              'us, and which sets out what a loan costs and how it is repaid.',
        ]),
        const LegalText(
          'Where a specific product term contradicts these general Terms, the '
          'specific term wins for that product. The Lending Agreement, for '
          'example, governs your loan even where these Terms say something '
          'more general about money owed to us.',
        ),
        const LegalNote(
          'You are entering into a legally binding contract electronically. '
          'Under the Evidence Act 2011, the electronic record we keep of your '
          'acceptance — the version accepted, the date, the time and the '
          'device — is admissible evidence of this agreement, and you agree '
          'not to dispute it on the ground that it was not signed on paper.',
          title: 'Electronic acceptance',
        ),
      ]),

      LegalSection('Who can open an account', [
        const LegalText('To open a Kudi9ja account you must:'),
        const LegalList([
          'be a natural person aged **18 or above**;',
          'be resident in Nigeria, or hold a Nigerian bank account in your own '
              'name;',
          'have a valid **Bank Verification Number (BVN)** and **National '
              'Identification Number (NIN)** issued to you;',
          'have a working email address and a Nigerian mobile number you '
              'control;',
          'not be acting on behalf of anybody else; and',
          'not be barred from using financial services under Nigerian law, or '
              'listed on any sanctions list we are required to screen against.',
        ]),
        const LegalText(
          'We may refuse to open an account, and we do not have to give a '
          'reason. Where the law allows us to explain, we will.',
        ),
      ]),

      LegalSection('Opening your account and verifying who you are', [
        const LegalText(
          'Nigerian law requires us to know who our customers are. When you '
          'sign up we collect your name, date of birth, gender, address, state '
          'of residence, phone number, email address, BVN and NIN, and we '
          'verify them against the records held by the institutions that '
          'issued them.',
        ),
        const LegalText(
          'You promise that everything you tell us is true, complete and '
          'current, and that you will update us within **7 days** if any of it '
          'changes — particularly your phone number, email address or home '
          'address.',
        ),
        const LegalText(
          'Verification decides what your account can do. Until your identity '
          'is confirmed we may hold your account at a lower tier, cap what you '
          'can move, or keep it closed to new funds.',
        ),
        const LegalNote(
          'Giving us false information, or using somebody else\'s identity '
          'documents, is a criminal offence. It will also cost you your '
          'account, and we will report it.',
          tone: LegalTone.caution,
        ),
      ]),

      LegalSection('Your wallet, and what it is not', [
        const LegalText(
          'Your Kudi9ja wallet is a record of what we owe you. It shows the '
          'money you have paid in, the returns we have credited, the loans we '
          'have disbursed to you and everything you have moved out.',
        ),
        const LegalNote(
          '${AppConfig.legalEntity} is not a bank. Your wallet is not a bank '
          'account, and money held in it is not insured by the Nigeria Deposit '
          'Insurance Corporation. The account number shown in the app '
          'identifies your Kudi9ja profile; it is not a bank account that can '
          'be paid into from outside Kudi9ja.',
          title: 'Read this twice',
          tone: LegalTone.caution,
        ),
        LegalText(
          'Customer money paid in is held in our collection account at '
          '${s.companyBank} in the name of ${s.companyAccountName}. We keep '
          'our own records of which part of that balance belongs to which '
          'customer.',
        ),
        const LegalText(
          'We do not pay interest on money that is simply sitting in your '
          'wallet. Returns are earned by placing money into a savings plan.',
        ),
      ]),

      LegalSection('Paying money in', [
        LegalText(
          'You fund your wallet, open a savings plan or repay a loan by '
          'transferring from your own bank account to our collection account '
          '(${s.companyBank}, ${s.companyAccountNumber}, '
          '${s.companyAccountName}), quoting the reference the app gives you, '
          'and then telling us in the app that you have paid, attaching the '
          'receipt from your bank.',
        ),
        const LegalText('So that your money reaches you and not somebody else:'),
        const LegalList([
          'transfer only from a bank account **in your own name** — third '
              'party transfers may be returned to source;',
          'quote **the exact reference** shown in the app on that transfer;',
          'submit the claim in the app with a legible receipt; and',
          'submit **one claim per transfer**.',
        ]),
        const LegalText(
          'Nothing is credited on your word alone. Our team matches your claim '
          'against the collection account statement first. Claims received on '
          'a working day are normally reviewed within **one working day**, and '
          'we will always tell you the outcome in the app.',
        ),
        const LegalText(
          'If a payment reaches us but cannot be matched to a customer, we '
          'will hold it and try to trace it. If we still cannot identify the '
          'sender after **30 days**, we will return it to the account it came '
          'from.',
        ),
        const LegalNote(
          'Submitting a receipt for a transfer you did not make, or altering '
          'one, is attempted fraud. We will freeze the account, keep the '
          'evidence and report it to the police and to your bank.',
          tone: LegalTone.caution,
        ),
      ]),

      LegalSection('Taking money out', [
        const LegalText(
          'You can ask to withdraw available wallet funds to a Nigerian bank '
          'account in your own name. When you make the request the amount '
          'leaves your wallet immediately, so it cannot be spent twice while '
          'we check it.',
        ),
        const LegalList([
          'Requests are reviewed and, where approved, paid out within **one '
              'working day**. Bank processing may add to that.',
          'If we decline a request, the full amount goes straight back to your '
              'wallet and we tell you why.',
          'You are responsible for the destination account details. We cannot '
              'recall money sent to an account you typed incorrectly, though '
              'we will help you pursue it.',
          'Money committed to a running savings plan or a thrift circle is not '
              'available to withdraw.',
        ]),
        LegalText(
          'Transfers between Kudi9ja customers are instant and free, and are '
          'capped at **${s.dailyTransferLimit.asNairaFlat} per day**. We may '
          'adjust that limit for your account where the law, our risk rules or '
          'your verification tier require it.',
        ),
      ]),

      LegalSection('Fixed Savings', [
        LegalText(
          'A Fixed Savings plan locks a sum of money for a period you choose, '
          'from ${s.minLockMonths} month to ${s.maxLockMonths ~/ 12} years, '
          'and pays **${s.savingsRatePct.toStringAsFixed(0)}% per annum**, '
          'pro-rated for the term.',
        ),
        LegalList([
          'The minimum amount is ${s.minSavingsAmount.asNairaFlat}.',
          'The return is calculated on the amount locked, for the number of '
              'months locked, and **paid into your wallet at the moment the '
              'plan is created** rather than at maturity.',
          'The rate that applies to your plan is the rate displayed when you '
              'create it. Later rate changes do not touch a running plan.',
          'On maturity, the principal is returned to your wallet in full.',
        ]),
        const LegalNote(
          'A Fixed Savings plan cannot be broken before maturity. You are paid '
          'the return upfront precisely because the money stays where it is, '
          'so choose a lock period you can live with.',
          title: 'Fixed means fixed',
          tone: LegalTone.caution,
        ),
        const LegalText(
          'If you die or become permanently incapacitated during a lock '
          'period, the plan is released early, in full and without penalty, to '
          'you or to whoever is legally entitled to it, on production of the '
          'documents the law requires.',
        ),
      ]),

      LegalSection('Target Savings', [
        LegalText(
          'A Target Savings plan is a goal you fund over time, either manually '
          'or by an automatic schedule you set. The minimum term is '
          '**${s.minTargetMonths} months**, and a month counts as 30 days.',
        ),
        const LegalText(
          'A bonus is paid on the final day of the term, calculated on the '
          'total you actually saved, at a rate that depends on how long you '
          'committed for:',
        ),
        LegalDefs([
          ('3 to 5 months', '${s.targetShortPct.toStringAsFixed(1)}% bonus'),
          ('6 to 11 months', '${s.targetMediumPct.toStringAsFixed(1)}% bonus'),
          (
            '12 months and above',
            '${s.targetLongPct.toStringAsFixed(1)}% bonus',
          ),
        ]),
        const LegalText(
          'You may end a Target Savings plan early. If you do, **every naira '
          'you saved comes back to your wallet in full**, and the bonus is '
          'forfeited. We do not charge a break fee and we do not keep any part '
          'of your principal.',
        ),
        const LegalText(
          'If you turn on automatic saving, you are instructing us to move the '
          'scheduled amount from your wallet on each due date. Where the '
          'wallet is short, the run is skipped, we tell you, and we try again '
          'on the next scheduled date. Repeated shortfalls will leave you '
          'short of your goal — the bonus is paid on what you saved, not on '
          'what you intended to save.',
        ),
      ]),

      LegalSection('Thrift circles (ajo, esusu, adashe)', [
        const LegalText(
          'A thrift circle is a rotating savings group. Every member '
          'contributes the same amount each cycle and one member collects the '
          'whole pot each round, until everyone has had a turn.',
        ),
        const LegalNote(
          'In a thrift circle we are the record-keeper and the rails, not a '
          'guarantor. We do not underwrite the members of your circle, and we '
          'do not make good a round that another member fails to pay into.',
          title: 'What our role is',
        ),
        const LegalList([
          'By joining a circle you commit to contributing on every round of '
              'that circle, including the rounds that come after you have '
              'already collected.',
          'Collection order is set when the circle is created and is visible '
              'to every member.',
          'If you leave a circle, or stop contributing, before you have paid '
              'into every round, you may forfeit contributions already made, '
              'and we may recover what you owe the circle from your wallet.',
          'Only invite people you actually know and trust. A circle is only as '
              'sound as the people in it.',
        ]),
      ]),

      LegalSection('Loans', [
        LegalText(
          'We lend from ${s.minLoanAmount.asNairaFlat} to '
          '${s.maxLoanAmount.asNairaFlat}, over any period from **1 month to '
          '${s.maxLoanTenureMonths} months**. Interest is a single flat charge '
          'on the amount borrowed, and every one of those tenures carries its '
          'own published rate — ${s.loanRateLabelFor(1)} over 1 month, '
          '${s.loanRateLabelFor(3)} over 3, '
          '${s.loanRateLabelFor(s.maxLoanTenureMonths)} over '
          '${s.maxLoanTenureMonths}. The rate for the tenure you pick is shown '
          'before you borrow, and is fixed for the life of that loan.',
        ),
        const LegalText(
          'Everything else about borrowing — the processing fee, how a loan is '
          'repaid, what happens if you do not repay, and the rights you have — '
          'is in the **Lending Agreement**, which you accept separately each '
          'time you take a loan.',
        ),
        const LegalText(
          'Applying does not entitle you to a loan. We decide whether to lend, '
          'how much, and for how long, and we may decline without giving '
          'reasons.',
        ),
      ]),

      LegalSection('Fees, charges and tax', [
        const LegalText(
          'We publish every charge in the app before you commit to anything. '
          'The charges that exist today are:',
        ),
        LegalDefs([
          ('Opening an account', 'Free'),
          ('Wallet maintenance', 'Free'),
          ('Kudi9ja to Kudi9ja transfers', 'Free'),
          ('Withdrawals to your bank', 'Free'),
          ('Opening or breaking a savings plan', 'Free'),
          (
            'Loan processing fee (management fee)',
            'Flat ${s.flatProcessingFee.asNairaFlat} on loans up to and '
                'including ${s.processingFeeThreshold.asNairaFlat}; above '
                'that, ${s.feeRatePct.toStringAsFixed(0)}% of the whole amount '
                'borrowed. Always deducted from the disbursement, never added '
                'to what you owe.',
          ),
        ]),
        const LegalText(
          'Your own bank may charge you for transfers to us. That charge is '
          'theirs, not ours.',
        ),
        const LegalText(
          'Where Nigerian tax law requires it, we will deduct withholding tax '
          'or any other statutory levy from returns we pay you, and remit it '
          'to the relevant authority. Anything you owe us is payable free of '
          'any deduction you might otherwise make.',
        ),
        const LegalText(
          'We will give you at least **30 days\' notice** in the app and by '
          'email before introducing a new charge or increasing an existing '
          'one. A change never applies retrospectively to a plan or a loan '
          'already running.',
        ),
      ]),

      LegalSection('Bonuses and promotions', [
        const LegalText(
          'From time to time we run promotions — a welcome credit, a referral '
          'reward, a seasonal bonus. These are discretionary, are subject to '
          'whatever specific rules we publish for them, and can be withdrawn '
          'at any time for the future.',
        ),
        const LegalText(
          'Bonuses are for real customers using the app in the ordinary way. '
          'If you obtain one through duplicate accounts, false referrals or '
          'any other manipulation, we may reverse it, withhold it, and close '
          'the accounts involved.',
        ),
      ]),

      LegalSection('Keeping your account secure', [
        const LegalText(
          'Your account is protected by a sign-in passcode, a separate '
          'transaction PIN and, if you enable it, your device biometrics. '
          'These are yours alone.',
        ),
        const LegalText('You agree to:'),
        const LegalList([
          'keep your passcode, PIN, password and one-time codes secret — we '
              'will **never** ask you for any of them, and anybody who does is '
              'not from Kudi9ja;',
          'not choose an obvious code, and not reuse one from elsewhere;',
          'keep your phone locked, keep its software up to date, and not '
              'install Kudi9ja on a rooted or jailbroken device;',
          'only enable biometric sign-in on a device where **your** biometrics '
              'are the only ones enrolled; and',
          'tell us **immediately** — by phone, WhatsApp or '
              '${AppConfig.supportEmail} — if your phone is lost or stolen, or '
              'if you think somebody else knows your codes or has used your '
              'account.',
        ]),
        const LegalText(
          'Until you tell us, transactions authorised with your codes are '
          'treated as authorised by you. Once you have told us we will freeze '
          'the account promptly, and you are not responsible for what happens '
          'after that, unless you acted fraudulently or shared your codes '
          'deliberately.',
        ),
        const LegalText(
          'If you report an unauthorised transaction, we will investigate and '
          'come back to you within **10 working days** with what we found and '
          'what we are doing about it.',
        ),
      ]),

      LegalSection('How we talk to each other', [
        const LegalText(
          'We communicate with you in the app, by email, by SMS and, where you '
          'have used it to reach us, on WhatsApp. Notices about your account, '
          'your money and these Terms are sent that way and are treated as '
          'received when sent to the details we hold for you. Keep them '
          'current.',
        ),
        const LegalText(
          'You can opt out of marketing at any time without affecting your '
          'account. You cannot opt out of service messages — a repayment '
          'reminder or a security alert has to reach you.',
        ),
      ]),

      LegalSection('What you must not do', [
        const LegalText('You must not use Kudi9ja to:'),
        const LegalList([
          'launder money, finance terrorism, or move the proceeds of any '
              'crime;',
          'impersonate anybody, or open an account for somebody else;',
          'run a business account, a betting float, or any deposit-taking '
              'scheme of your own through your wallet;',
          'defraud us or another customer, including by disputing a payment '
              'you did make;',
          'break, probe, overload, reverse-engineer or automate access to the '
              'app, or interfere with anybody else\'s use of it; or',
          'do anything unlawful, or anything these Terms prohibit.',
        ]),
      ]),

      LegalSection('When we can freeze, restrict or close an account', [
        const LegalText(
          'We may suspend an account, hold a transaction, or refuse to act on '
          'an instruction where we reasonably believe that:',
        ),
        const LegalList([
          'the account is being used fraudulently or unlawfully;',
          'somebody other than you is operating it;',
          'we are required to act by a law, a regulator or a court order;',
          'the information we hold about you is materially wrong or out of '
              'date and you have not corrected it after we asked; or',
          'there is a genuine dispute over who is entitled to the money.',
        ]),
        const LegalText(
          'Where we are legally allowed to tell you, we will explain what has '
          'happened, what we need from you, and how to get the restriction '
          'lifted. Some legal orders forbid us from saying anything at all; in '
          'that case our silence is not a choice.',
        ),
        const LegalText(
          'We may **set off** money in your wallet, and money released from a '
          'matured savings plan, against any amount you owe us that is due and '
          'unpaid. We will tell you when we do.',
        ),
        const LegalText(
          'We may close your account on **30 days\' notice**, or without notice '
          'where you have breached these Terms seriously, where we must do so '
          'by law, or where continuing to serve you would expose us or other '
          'customers to real risk. Closing an account does not cancel what you '
          'owe us, and does not cancel what we owe you.',
        ),
      ]),

      LegalSection('Closing your account yourself', [
        const LegalText(
          'You can close your account at any time, provided you have no '
          'running loan and no unfinished obligation to a thrift circle. Any '
          'balance goes back to a bank account in your own name.',
        ),
        const LegalText(
          'Deleting the app does not close your account. Ask us at '
          '${AppConfig.supportEmail}, or use the option in the app.',
        ),
        const LegalText(
          'After closure we keep your records for as long as the law requires '
          '— generally **five years** — as explained in the Privacy Policy.',
        ),
      ]),

      LegalSection('Dormant accounts and unclaimed money', [
        const LegalText(
          'If your account has no activity for **12 months** we will treat it '
          'as dormant, tell you, and stop it from being used until you get in '
          'touch and confirm your identity. Dormancy costs you nothing; we do '
          'not charge dormancy fees.',
        ),
        const LegalText(
          'Money left unclaimed will be dealt with as Nigerian law directs, '
          'and we will make reasonable efforts to reach you first.',
        ),
      ]),

      LegalSection('The service itself', [
        const LegalText(
          'We work to keep Kudi9ja available, accurate and fast, but we do not '
          'promise it will never be interrupted. We carry out maintenance, we '
          'depend on banks, telecom networks and identity services we do not '
          'control, and any of those can fail.',
        ),
        const LegalText(
          'We may change, add to, or discontinue features. Where a change '
          'materially reduces what you get, we will give you at least **30 '
          'days\' notice**, and you may close your account if you do not want '
          'to continue.',
        ),
        const LegalText(
          'Calculators, projections, credit scores and insights in the app are '
          'estimates to help you plan. They are not financial advice and they '
          'are not a promise of any outcome. If you need advice on your own '
          'situation, speak to a licensed adviser.',
        ),
      ]),

      LegalSection('What we are responsible for, and what we are not', [
        const LegalText(
          'We are responsible for losses you suffer because we broke this '
          'agreement or failed to use reasonable care and skill.',
        ),
        const LegalText('We are not responsible for:'),
        const LegalList([
          'loss caused by you giving us wrong details, sharing your codes, or '
              'acting on instructions from somebody pretending to be us;',
          'the failure or delay of a bank, card scheme, telecom network, '
              'identity service or other third party we do not control;',
          'loss of profit, loss of opportunity, or loss that was not a '
              'reasonably foreseeable result of what went wrong; or',
          'events outside our reasonable control — power failure, network '
              'outage, flood, fire, epidemic, civil unrest, strike, act of '
              'government or war. While such an event lasts our obligations '
              'are paused, not cancelled, and we will tell you what is '
              'happening and restore service as soon as we can.',
        ]),
        const LegalText(
          'Except where the law does not allow a limit, our total liability to '
          'you for any claim, or series of connected claims, is capped at the '
          'greater of **the amount directly lost** and **the total fees you '
          'paid us in the 12 months before the claim arose**.',
        ),
        const LegalText(
          'Nothing in these Terms limits our liability for fraud, for our own '
          'wilful misconduct, or for anything that cannot lawfully be limited.',
        ),
        const LegalText(
          'You will cover us against loss we suffer because you used Kudi9ja '
          'unlawfully, broke these Terms deliberately, or gave us information '
          'you knew to be false.',
        ),
      ]),

      LegalSection('If something goes wrong: complaints', [
        const LegalText('Tell us first. Most things are fixed the same day.'),
        const LegalDefs([
          (
            'Step 1',
            'Contact support in the app, on WhatsApp, by phone, or at '
                '${AppConfig.supportEmail}. We acknowledge every complaint '
                'within 24 hours and give you a reference number.',
          ),
          (
            'Step 2',
            'We investigate and give you a written answer within 10 working '
                'days. Where a matter is genuinely complex we will tell you '
                'why, and resolve it within 30 days.',
          ),
          (
            'Step 3',
            'If you are not satisfied, ask for the complaint to be escalated '
                'to our management at ${AppConfig.legalEmail}.',
          ),
          (
            'Step 4',
            'If we still have not resolved it, you may take the matter to the '
                'appropriate regulator — the Central Bank of Nigeria consumer '
                'protection department, the Federal Competition and Consumer '
                'Protection Commission, or, for a data matter, the Nigeria '
                'Data Protection Commission.',
          ),
        ]),
        const LegalText(
          'Nothing here stops you from going to court, or to a regulator, '
          'whenever you choose.',
        ),
      ]),

      LegalSection('Disputes, governing law and jurisdiction', [
        const LegalText(
          'These Terms, and any dispute arising out of them, are governed by '
          'the laws of the **Federal Republic of Nigeria**.',
        ),
        const LegalText(
          'If a dispute cannot be settled through our complaints process, '
          'either of us may refer it to arbitration by a single arbitrator '
          'under the Arbitration and Mediation Act 2023. The seat is **Lagos, '
          'Nigeria**, the language is English, and the award is final. If we '
          'cannot agree on who the arbitrator should be within 14 days, either '
          'of us may ask the Lagos Court of Arbitration to appoint one.',
        ),
        const LegalText(
          'This does not stop either of us from asking a court for urgent '
          'protective relief, and it does not stop you from bringing a small '
          'claim, or a complaint to a regulator, instead. The courts of Lagos '
          'State have jurisdiction over anything not sent to arbitration.',
        ),
      ]),

      LegalSection('Changes to these Terms', [
        const LegalText(
          'We may update these Terms — to reflect a change in the law, a new '
          'feature, or a clearer way of saying something.',
        ),
        const LegalList([
          'For a change that affects your rights or your costs, we give you at '
              'least **30 days\' notice** in the app and by email, and we tell '
              'you plainly what is changing.',
          'For a correction, or a change that is purely in your favour, the '
              'new version applies as soon as we publish it.',
          'If you do not accept a change, you may close your account before it '
              'takes effect, at no cost. Continuing to use Kudi9ja after that '
              'date means you accept the new version.',
        ]),
        const LegalText(
          'Every version is dated and numbered. The version in force is always '
          'the one in the app.',
        ),
      ]),

      LegalSection('The small print', [
        const LegalDefs([
          (
            'Transfer',
            'We may transfer our rights and obligations to another company, '
                'for example on a restructuring or a sale, provided your '
                'rights are not reduced. You may not transfer yours.',
          ),
          (
            'Waiver',
            'If we do not enforce a right straight away, we have not given it '
                'up.',
          ),
          (
            'Severance',
            'If any part of these Terms turns out to be unenforceable, the '
                'rest still stands.',
          ),
          (
            'Whole agreement',
            'These Terms, the Privacy Policy and — where you borrow — the '
                'Lending Agreement are the entire agreement between us, and '
                'replace anything said beforehand.',
          ),
          (
            'Third parties',
            'Nobody other than you and us has rights under this agreement.',
          ),
          (
            'Language',
            'This agreement is made in English. Any translation is a courtesy, '
                'and the English version governs.',
          ),
          (
            'Records',
            'Our records are the primary evidence of your transactions, unless '
                'you show them to be wrong.',
          ),
        ]),
      ]),
    ],
  );
}
