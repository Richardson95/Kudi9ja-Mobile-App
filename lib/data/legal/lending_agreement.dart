import '../../core/constants/app_config.dart';
import '../../core/utils/formatters.dart';
import '../models/models.dart';
import '../models/platform_settings.dart';
import 'legal_models.dart';

/// The Lending Agreement. Every figure in it is derived from [Finance], the
/// same code that prices a real loan, so the document cannot quote a cost the
/// app would not actually charge.
LegalDocument lendingAgreement() {
  final s = settings;

  return LegalDocument(
    id: 'lending',
    title: 'Lending Agreement',
    shortTitle: 'Lending Agreement',
    summary:
        'The contract for money you borrow from Kudi9ja: what it costs, how '
        'and when you repay it, what happens if you do not, and the standards '
        'we hold ourselves to while collecting.',
    version: '1.0',
    effective: DateTime(2026, 9, 4),
    readMinutes: 16,
    sections: [
      LegalSection('The parties, and what this document is', [
        const LegalText(
          'This Lending Agreement is between **${AppConfig.legalEntity}** '
          '(**${AppConfig.rcNumber}**) of ${AppConfig.registeredAddress}, '
          'trading as Kudi9ja — "the Lender", "we", "us" — and the customer '
          'who accepts it — "the Borrower", "you".',
        ),
        const LegalText(
          'It applies every time you take a loan through Kudi9ja. You accept '
          'it when you confirm a loan request with your transaction PIN. The '
          'specific amount, tenure, fee, interest and repayment dates shown to '
          'you on that confirmation screen are part of this agreement, and '
          'they are what you are agreeing to.',
        ),
        const LegalText(
          'Our Terms of Service and Privacy Policy also apply. Where they '
          'conflict with this document about your loan, this document wins.',
        ),
        const LegalNote(
          'Read the confirmation screen before you press confirm. It shows '
          'exactly what will reach your wallet, exactly what you will repay, '
          'and exactly when. Nothing is added afterwards.',
          title: 'Before you borrow',
        ),
      ]),

      LegalSection('Definitions', [
        const LegalDefs([
          (
            'Principal',
            'The amount of the loan, before the processing fee is taken off.',
          ),
          (
            'Processing fee',
            'Also called the **management fee**: a one-off charge for '
                'assessing and disbursing the loan, deducted from the '
                'disbursement. The two names mean the same charge.',
          ),
          (
            'Net disbursement',
            'What actually reaches your wallet: the principal less the '
                'processing fee.',
          ),
          (
            'Interest',
            'A single flat charge on the principal. It does not compound and '
                'it does not grow with time.',
          ),
          (
            'Total repayable',
            'Principal plus interest. This is the whole of what you owe, and '
                'it never increases.',
          ),
          (
            'Tenure',
            'The number of months over which the total repayable is spread.',
          ),
          (
            'Instalment',
            'The total repayable divided by the tenure, due one month apart '
                'from the day the loan was disbursed.',
          ),
          (
            'Outstanding',
            'The total repayable less everything you have paid so far.',
          ),
          (
            'Default',
            'Failing to pay an instalment in full by its due date, or any of '
                'the other events listed in this agreement.',
          ),
        ]),
      ]),

      LegalSection('What we lend, and to whom', [
        LegalText(
          'We lend from **${s.minLoanAmount.asNairaFlat}** to '
          '**${s.maxLoanAmount.asNairaFlat}**, over **1 to '
          '${s.maxLoanTenureMonths} months**, to verified Kudi9ja customers.',
        ),
        const LegalText(
          'A loan request is an offer from you. There is no loan until we '
          'accept it and the money reaches your wallet. We may approve less '
          'than you asked for, offer a different tenure, or decline outright — '
          'and we do not have to give reasons, though we will where we can.',
        ),
        const LegalText(
          'We assess affordability before lending. That means we may decline '
          'you even where you meet every published criterion, because we do '
          'not believe the repayments are sustainable for you. That is not a '
          'judgement about you; it is us lending responsibly.',
        ),
      ]),

      LegalSection('What a loan costs', [
        const LegalText(
          'Our pricing is deliberately simple. There are exactly two charges, '
          'both fixed at the moment you borrow:',
        ),
        LegalDefs([
          (
            'Interest',
            'A single **flat charge on the amount borrowed**, at the rate '
                'published for the tenure you choose. It does not compound, '
                'and it does not change once your loan has started.',
          ),
          (
            'Processing fee (management fee)',
            'A flat **${s.flatProcessingFee.asNairaFlat}** on every loan from '
                '${s.minLoanAmount.asNairaFlat} up to and including '
                '${s.processingFeeThreshold.asNairaFlat}. Above that figure — '
                'and ${(s.processingFeeThreshold + 1).asNairaFlat} is already '
                'above it — the fee is '
                '**${s.feeRatePct.toStringAsFixed(0)}% of the whole amount '
                'borrowed**, not of the part above the threshold. It is '
                'deducted from the money we send you, never added to what you '
                'owe.',
          ),
        ]),
        LegalText(
          'The interest rate depends **only on the tenure**, never on the '
          'amount. **Every month from 1 to ${s.maxLoanTenureMonths} is priced '
          'separately**, and the rate for the tenure you are looking at is '
          'shown in the app before you borrow. These are the rates at some of '
          'those points today:',
        ),
        LegalDefs([
          for (final months in _anchorTenures(s.maxLoanTenureMonths))
            (
              months == 1 ? 'Over 1 month' : 'Over $months months',
              '**${s.loanRateLabelFor(months)} flat** — the equivalent of '
                  '${(s.loanRatePctFor(months) / months).toStringAsFixed(2)}% '
                  'a month. Borrow ${_naira(200000)} and you repay '
                  '${_naira(Finance.loanTotal(200000, months))}.',
            ),
        ]),
        LegalText(
          'The tenures not listed above sit between these points and are '
          'published in the app in exactly the same way. The rate that binds '
          'you is the one displayed on the screen you confirm, and it is fixed '
          'for the life of that loan — a later change to our rate card never '
          'touches a loan already running.',
        ),
        const LegalNote(
          'Each tenure is priced separately, so compare the cost per month as '
          'well as the total — the table above gives you both, and the app '
          'shows the exact figures for your own loan before you confirm.',
          title: 'Compare the tenures',
        ),
        const LegalText(
          'There is nothing else. Specifically, we do not charge:',
        ),
        const LegalList([
          'an application fee, an insurance premium or a "management" charge;',
          'a fee for repaying early — early settlement earns you a **rebate**, '
              'not a penalty;',
          'penalty interest or a late fee if you miss a due date; or',
          'any charge that was not on the screen you confirmed.',
        ]),
        const LegalNote(
          'The total repayable is fixed on the day you borrow. However long '
          'the loan is outstanding, and whatever happens afterwards, the debt '
          'itself does not grow. Interest never accrues on top of interest.',
          title: 'Your debt cannot grow',
          tone: LegalTone.positive,
        ),
      ]),

      LegalSection('The cost, in figures', [
        const LegalText(
          'Flat interest is easy to understand but easy to underestimate, so '
          'here is the same pricing expressed several ways. The **equivalent '
          'annual rate** shows what the loan would cost if you borrowed at the '
          'same cost per month for a whole year — it is the fairest way to '
          'compare us against any other lender.',
        ),
        _example(s.minLoanAmount, 1),
        for (final months in _exampleTenures(s.maxLoanTenureMonths))
          _example(200000, months),
        _example(s.maxLoanAmount, s.maxLoanTenureMonths),
        const LegalText(
          'These are illustrations. Before you confirm anything, the app shows '
          'you the exact figures for the amount and tenure you actually chose.',
        ),
        const LegalNote(
          'Short-term credit is expensive credit. The processing fee weighs '
          'most heavily on the smallest, shortest loans, which is why their '
          'equivalent annual rate is the highest of all. Borrow only what you '
          'need, for only as long as you need it, and only when a cheaper '
          'option is not open to you.',
          title: 'Be honest with yourself about this',
          tone: LegalTone.caution,
        ),
      ]),

      LegalSection('Disbursement', [
        const LegalText(
          'Once approved, we credit the net disbursement to your Kudi9ja '
          'wallet, usually within minutes. From your wallet you can spend it, '
          'transfer it, or withdraw it to your bank account.',
        ),
        const LegalText(
          'We may withhold disbursement, or cancel an approval before the '
          'money leaves, if something material changes between approval and '
          'payout — for example we discover the information you gave us was '
          'wrong, or your account is frozen for a fraud check.',
        ),
      ]),

      LegalSection('How you repay', [
        LegalText(
          'The total repayable is divided into **${s.maxLoanTenureMonths} or '
          'fewer equal monthly instalments**, depending on the tenure you '
          'chose. The first falls due one month after disbursement, and each '
          'one after it a month later. Your schedule, with every date and '
          'amount, is in the app from the moment the loan starts.',
        ),
        const LegalText('You can repay in either of two ways:'),
        const LegalList([
          '**From your wallet** — the fastest way, and it settles '
              'immediately.',
          '**By bank transfer** to our collection account, quoting the '
              'reference the app gives you and submitting the claim with your '
              'receipt. Your loan is reduced once our team has matched the '
              'transfer.',
        ]),
        const LegalText(
          'Payments are applied to the oldest amount due first, and then to '
          'the rest of the outstanding balance. You may pay more than an '
          'instalment, or clear the whole thing, whenever you like.',
        ),
        const LegalText(
          'Where you have asked us to collect repayments automatically, you '
          'authorise us to debit your wallet for the instalment on each due '
          'date. If the wallet is short we take what is there, tell you, and '
          'you remain responsible for the rest. You can turn automatic '
          'collection off at any time; doing so does not change what you owe.',
        ),
        const LegalText(
          'We remind you before every due date, in the app and by email.',
        ),
      ]),

      LegalSection('Paying off early', [
        const LegalText(
          'You may settle a loan in full at any time, and you will pay less '
          'for doing so.',
        ),
        const LegalText(
          'On early settlement we give back **half of the interest '
          'attributable to the months of your tenure that have not yet '
          'started**. The rebate is taken off your outstanding balance, and '
          'the app shows you the exact settlement figure before you confirm.',
        ),
        _payoffExample(),
        const LegalText(
          'There is no charge for early settlement, and settling early is '
          'recorded on your account as good performance.',
        ),
      ]),

      LegalSection('Cancelling a loan you have just taken', [
        const LegalNote(
          'If you change your mind, you may cancel a loan within **24 hours** '
          'of disbursement by returning the full amount that reached your '
          'wallet, plus the processing fee. We charge **no interest at all** '
          'on a loan cancelled this way, and the loan is removed from your '
          'record as though it never happened.',
          title: 'A 24-hour change of mind',
          tone: LegalTone.positive,
        ),
        const LegalText(
          'Tell us in the app or at ${AppConfig.supportEmail} within the 24 '
          'hours and make sure the money is in your wallet. After that window, '
          'the ordinary early-settlement terms apply instead.',
        ),
      ]),

      LegalSection('If you cannot pay', [
        const LegalText(
          'Talk to us **before** the due date. Difficulty is common and it is '
          'not shameful; what makes it worse is silence.',
        ),
        const LegalText(
          'Where you are in genuine difficulty we will look at your situation '
          'and, where we reasonably can, agree a way forward — a revised '
          'schedule, a short pause, or a reduced settlement. Any arrangement '
          'we reach will be confirmed to you in writing.',
        ),
        const LegalText(
          'We will not agree to something we can see you cannot afford, and '
          'entering an arrangement does not by itself write off what you owe. '
          'But we would far rather restructure a loan than pursue one.',
        ),
      ]),

      LegalSection('Default, and what follows it', [
        const LegalText('You are in default if:'),
        const LegalList([
          'an instalment is not paid in full by its due date;',
          'you gave us information in your application that was false or '
              'materially misleading;',
          'you become insolvent, or a court orders your assets to be seized; '
              'or',
          'you breach the Terms of Service in a way that seriously affects our '
              'ability to be repaid.',
        ]),
        const LegalText('If you are in default, we may:'),
        const LegalList([
          'demand the whole outstanding balance immediately, rather than by '
              'instalments;',
          '**set off** what you owe against money in your wallet, and against '
              'money released from a savings plan when it matures;',
          'suspend your access to further credit;',
          'report the default to licensed credit bureaux, which will affect '
              'your ability to borrow anywhere in Nigeria;',
          'instruct a recovery partner, or take legal action; and',
          'recover the reasonable costs we actually incur in enforcing this '
              'agreement, which we will evidence to you.',
        ]),
        const LegalNote(
          'Even in default, **the amount you owe does not increase**. There is '
          'no penalty interest and no late fee. What you owed on the due date '
          'is what you owe, plus only such enforcement costs as we can '
          'actually evidence.',
          tone: LegalTone.positive,
        ),
        const LegalText(
          'We will always contact you and give you a reasonable chance to put '
          'things right before we escalate.',
        ),
      ]),

      LegalSection('How we will treat you when collecting', [
        const LegalText(
          'Debt collection in Nigeria has a bad reputation, much of it '
          'deserved. These are commitments, not aspirations, and they bind our '
          'staff and every partner acting for us.',
        ),
        const LegalList([
          'We will **never contact your friends, family, employer or phone '
              'contacts** about your debt. Your borrowing is between you and '
              'us.',
          'We will never post about you, publish your name or photograph, or '
              'shame you on any platform.',
          'We will never threaten you, abuse you, or claim powers of arrest we '
              'do not have.',
          'We will never impersonate a court, the police or a regulator, or '
              'send a document dressed up to look official when it is not.',
          'We will contact you only between **8am and 8pm**, and not on public '
              'holidays, unless you ask us to call at another time.',
          'We will not contact you repeatedly in a way designed to distress '
              'you.',
          'Every collections call is logged, and every partner acting for us '
              'is contractually bound by these same rules.',
        ]),
        const LegalNote(
          'If anybody collecting a Kudi9ja debt breaks any of this, report it '
          'to **${AppConfig.legalEmail}**. We will investigate, tell you what '
          'we found, and end our relationship with a partner who does it. You '
          'may also complain to the Federal Competition and Consumer '
          'Protection Commission.',
          title: 'Hold us to it',
          tone: LegalTone.positive,
        ),
      ]),

      LegalSection('Credit reporting', [
        const LegalText(
          'You agree that we may share information about this loan — that it '
          'exists, how it is performing, and how it ended — with credit '
          'bureaux licensed by the Central Bank of Nigeria, and that we may '
          'obtain your credit report from them when assessing you.',
        ),
        const LegalText(
          'This cuts both ways. Repaying on time builds a record that helps '
          'you borrow more cheaply, from us and from anybody else. Defaulting '
          'follows you.',
        ),
        const LegalText(
          'If you believe something we reported about you is wrong, tell us at '
          '${AppConfig.supportEmail}. We will check it, correct it if we are '
          'wrong, and ask the bureau to update its record.',
        ),
      ]),

      LegalSection('Your promises to us', [
        const LegalText('Each time you take a loan, you confirm that:'),
        const LegalList([
          'the information in your application is true, complete and current;',
          'you are borrowing for yourself, not for anybody else, and not for '
              'any unlawful purpose;',
          'you have told us about any other loan you are currently repaying;',
          'you have read the schedule and reasonably expect to be able to meet '
              'it; and',
          'the phone number and email in your profile reach you, and you will '
              'update them if they change.',
        ]),
        const LegalText(
          'You also undertake to tell us promptly if your circumstances change '
          'in a way that will make repayment difficult.',
        ),
      ]),

      LegalSection('Set-off and recovery from your Kudi9ja balances', [
        const LegalText(
          'You authorise us, where an amount is due and unpaid, to apply '
          'against it:',
        ),
        const LegalList([
          'money in your Kudi9ja wallet;',
          'money released from a Target Savings plan you end early; and',
          'the principal of a Fixed Savings plan **when it matures** — not '
              'before.',
        ]),
        const LegalText(
          'We will tell you before or at the time we do this, and we will '
          'leave your wallet no worse than the debt requires. We will not '
          'break a Fixed Savings plan early to recover a debt.',
        ),
      ]),

      LegalSection('Death and incapacity', [
        const LegalText(
          'If you die or become permanently incapacitated while a loan is '
          'outstanding, we will not pursue your family for the shortfall '
          'beyond what your estate can meet under Nigerian law. Your estate '
          'may settle the outstanding balance, and any early-settlement rebate '
          'still applies.',
        ),
      ]),

      LegalSection('Our right to transfer this loan', [
        const LegalText(
          'We may transfer, assign or sell our rights under this agreement to '
          'another party, provided your rights and the cost of your loan do '
          'not change, and provided the transferee is bound by the collections '
          'standards above. We will tell you if this happens. You may not '
          'transfer your obligations to anybody else.',
        ),
      ]),

      LegalSection('Complaints and disputes', [
        const LegalText(
          'If something about your loan is wrong — a payment not credited, a '
          'schedule that looks incorrect, a collections contact that crossed a '
          'line — raise it with support in the app, on WhatsApp, or at '
          '${AppConfig.supportEmail}. We acknowledge within 24 hours and answer '
          'within 10 working days.',
        ),
        const LegalText(
          'Unresolved matters can be escalated to ${AppConfig.legalEmail}, and '
          'then to the Federal Competition and Consumer Protection Commission '
          'or the Central Bank of Nigeria consumer protection department.',
        ),
        const LegalText(
          'This agreement is governed by the laws of the **Federal Republic of '
          'Nigeria**. Disputes are resolved as set out in the Terms of Service '
          '— arbitration seated in Lagos, with the courts of Lagos State '
          'having jurisdiction over anything not arbitrated. Nothing here '
          'prevents you from complaining to a regulator at any time.',
        ),
      ]),

      LegalSection('Acceptance and record', [
        const LegalText(
          'You accept this agreement electronically, by confirming your loan '
          'request with your transaction PIN. That act carries the same legal '
          'weight as a signature on paper.',
        ),
        const LegalText(
          'We record the version of this agreement you accepted, the loan '
          'terms displayed to you, and the date and time of acceptance. A copy '
          'of your schedule stays in the app for as long as the loan exists, '
          'and we will send you a copy of this agreement on request at any '
          'time.',
        ),
        const LegalNote(
          'By confirming a loan you are saying: I have read what this loan '
          'costs, I have seen every repayment date and amount, nobody has '
          'pressured me, and I intend to repay.',
          title: 'Borrower\'s declaration',
        ),
      ]),
    ],
  );
}

/// The tenures the rate table is illustrated at. Listing all 24 would bury
/// the reader; these are the points a borrower actually reasons in.
List<int> _anchorTenures(int max) =>
    [1, 2, 3, 6, 12, 18, 24].where((m) => m <= max).toList()
      ..addAll(max > 24 ? [max] : const []);

/// The tenures the worked examples cover — the short end, a year, and the
/// longest loan we write.
List<int> _exampleTenures(int max) =>
    {1, 3, if (max >= 12) 12, max}.where((m) => m <= max).toList()..sort();

/// Naira, with kobo shown only when there actually are any.
String _money(double v) => v == v.roundToDouble() ? v.asNairaFlat : v.asNaira;

/// Whole naira, for the round illustrative amounts in the rate table.
String _naira(double v) => v.asNairaFlat;

/// A worked cost example, priced by the same [Finance] code that prices a
/// real loan — so these figures cannot drift away from what we charge.
LegalExample _example(double principal, int months) {
  final fee = Finance.processingFee(principal);
  final net = Finance.netDisbursed(principal);
  final interest = Finance.loanInterest(principal, months);
  final total = Finance.loanTotal(principal, months);
  final instalment = Finance.loanMonthly(principal, months);
  final cost = interest + fee;
  final annualEquivalent = net <= 0 ? 0.0 : (cost / net) * (12 / months) * 100;
  final plural = months == 1 ? 'month' : 'months';

  return LegalExample(
    'Borrowing ${principal.asNairaFlat} over $months $plural',
    [
      ('Loan amount', principal.asNairaFlat),
      ('Less processing fee', '- ${fee.asNairaFlat}'),
      ('Reaches your wallet', net.asNairaFlat),
      ('Interest (flat)', interest.asNairaFlat),
      ('Total you repay', total.asNairaFlat),
      (
        'Repayment',
        months == 1
            ? 'One payment of ${_money(instalment)} after 1 month'
            : '$months monthly payments of ${_money(instalment)}',
      ),
      ('Total cost of the credit', cost.asNairaFlat),
      (
        'Cost over $months $plural',
        '${((cost / net) * 100).toStringAsFixed(1)}% of what you received',
      ),
      (
        'Equivalent annual rate',
        '${annualEquivalent.toStringAsFixed(0)}% per year',
      ),
    ],
  );
}

/// What settling early actually saves, on a worked case.
LegalExample _payoffExample() {
  const principal = 200000.0;
  const months = 3;
  final interest = Finance.loanInterest(principal, months);
  final total = Finance.loanTotal(principal, months);
  final instalment = Finance.loanMonthly(principal, months);

  // One month elapsed, so one of the three has not yet started — the same
  // arithmetic Finance.earlyPayoffRebate performs on a live loan.
  const remainingMonths = 1;
  final rebate = interest * (remainingMonths / months) * 0.5;
  final outstanding = total - instalment;

  return LegalExample(
    'Settling ${principal.asNairaFlat} over $months months, after the first '
        'payment',
    [
      ('Total repayable', _money(total)),
      ('Already paid', _money(instalment)),
      ('Outstanding', _money(outstanding)),
      ('Interest rebate', '- ${_money(rebate)}'),
      ('You pay to settle', _money(outstanding - rebate)),
      ('You save', _money(rebate)),
    ],
  );
}
