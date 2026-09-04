import '../../core/constants/app_config.dart';
import 'legal_models.dart';

/// The Privacy Policy, written against the Nigeria Data Protection Act 2023.
///
/// It describes only what the app genuinely does: the fields collected at
/// sign-up, the receipt images attached to deposit claims, the passcode and
/// PIN hashes held on the device, and the biometric check that never leaves
/// the phone.
LegalDocument privacyPolicy() => LegalDocument(
  id: 'privacy',
  title: 'Privacy Policy',
  shortTitle: 'Privacy Policy',
  summary:
      'What personal data Kudi9ja collects, why we are allowed to hold it, '
      'who we share it with, how long we keep it, and the rights you have '
      'over it.',
  version: '1.0',
  effective: DateTime(2026, 9, 4),
  readMinutes: 14,
  sections: [
    LegalSection('Who is responsible for your data', [
      const LegalText(
        '**${AppConfig.legalEntity}** (**${AppConfig.rcNumber}**), the company '
        'behind Kudi9ja, is the **data controller** for the personal data '
        'described here. That means we decide what is collected and why, and '
        'we answer for it.',
      ),
      const LegalText(
        'We are registered in Nigeria at ${AppConfig.registeredAddress} and we '
        'process personal data under the **Nigeria Data Protection Act 2023 '
        '(NDPA)** and the regulations made under it.',
      ),
      const LegalDefs([
        ('Data protection contact', AppConfig.privacyEmail),
        ('Legal and contractual questions', AppConfig.legalEmail),
        ('General support', AppConfig.supportEmail),
        ('Phone', AppConfig.supportPhone),
        ('WhatsApp', '+234 805 679 1426 or +234 803 630 0582'),
        ('Post', AppConfig.registeredAddress),
      ]),
      const LegalText(
        'Write to ${AppConfig.privacyEmail} with anything at all about your '
        'data — a question, a correction, a request, or a complaint. That '
        'inbox reaches the person accountable for privacy at Kudi9ja.',
      ),
    ]),

    LegalSection('The short version', [
      const LegalList([
        'We collect what we need to open your account, keep it safe, obey the '
            'law and run the products you asked for. Nothing beyond that.',
        'We **never sell your personal data**, and we never rent it out for '
            'somebody else\'s marketing.',
        'We **never read your contacts, your photo gallery, your messages or '
            'your call log**, and we never contact your friends or family '
            'about a debt.',
        'Your passcode, PIN and password are stored only as one-way hashes. '
            'Nobody at Kudi9ja can read them.',
        'Your fingerprint or face is checked by your phone. It never reaches '
            'us.',
        'You can ask for a copy of your data, ask us to correct it, or ask us '
            'to delete it, at any time.',
      ]),
      const LegalText(
        'The rest of this policy sets all of that out properly.',
      ),
    ]),

    LegalSection('What we collect', [
      const LegalText(
        'We group the data into the categories below. Not all of it applies to '
        'every customer — what we hold depends on what you use.',
      ),
      const LegalDefs([
        (
          'Identity data',
          'Your full name, date of birth, gender, Bank Verification Number '
              '(BVN) and National Identification Number (NIN).',
        ),
        (
          'Contact data',
          'Your email address, mobile number, home address and state of '
              'residence.',
        ),
        (
          'Account data',
          'Your Kudi9ja customer reference, verification tier, the date you '
              'joined, and your notification and display preferences.',
        ),
        (
          'Financial data',
          'Your wallet balance, savings plans, target goals, thrift circle '
              'membership and contributions, loans, repayments, credit score '
              'and the full history of your transactions.',
        ),
        (
          'Payment evidence',
          'The receipt or screenshot you attach when you tell us you have paid '
              'into our collection account, the name on the sending account, '
              'and the reference quoted.',
        ),
        (
          'Bank details',
          'The bank and account number you nominate for payouts, and any '
              'other account of your own you ask us to withdraw to. Kudi9ja '
              'issues no account numbers of its own.',
        ),
        (
          'Security data',
          'One-way hashes of your password, sign-in passcode and transaction '
              'PIN, whether biometric sign-in is switched on, your security '
              'question and answer, and the one-time codes we issue.',
        ),
        (
          'Technical data',
          'Device model, operating system version, app version, and the '
              'in-app events we log to keep the service working and to detect '
              'fraud.',
        ),
        (
          'Communications data',
          'Your emails, WhatsApp messages, calls and in-app chats with our '
              'support team, and the notes we make on them.',
        ),
      ]),
      const LegalNote(
        'We do not collect your contact list, your photo library, your text '
        'messages, your call history or your location. If a future feature '
        'ever needs one of those, we will ask you first, explain why, and you '
        'will be free to say no.',
        title: 'What we deliberately do not collect',
        tone: LegalTone.positive,
      ),
      const LegalText(
        'Your fingerprint or face is never collected by us. When you turn on '
        'biometric sign-in, your phone performs the check in its own secure '
        'hardware and tells the app nothing more than "yes" or "no". No '
        'biometric template is ever sent to or stored by Kudi9ja.',
      ),
    ]),

    LegalSection('Where the data comes from', [
      const LegalList([
        '**From you** — when you sign up, verify your identity, transact, '
            'attach a receipt or contact support.',
        '**From your device** — the technical data above, generated as you use '
            'the app.',
        '**From verification partners** — the institutions that issued your '
            'BVN and NIN confirm to us that the number you gave matches the '
            'name and date of birth on record.',
        '**From banks and payment partners** — confirmation that a transfer '
            'reached our collection account, and that a payout to you '
            'succeeded.',
        '**From licensed credit bureaux** — your credit history, where you '
            'have applied to borrow.',
        '**From public and official sources** — sanctions lists, politically '
            'exposed person lists and public registers we are required to '
            'screen against.',
      ]),
    ]),

    LegalSection('Why we use it, and what allows us to', [
      const LegalText(
        'Under the NDPA we must have a lawful basis for every use. Ours are '
        'set out here, purpose by purpose.',
      ),
      const LegalDefs([
        (
          'Opening and running your account',
          'Basis: performance of our contract with you. Without this data '
              'there is no account.',
        ),
        (
          'Verifying your identity, screening for money laundering and '
              'terrorist financing, and reporting where required',
          'Basis: compliance with a legal obligation — including the Money '
              'Laundering (Prevention and Prohibition) Act 2022 and the '
              'know-your-customer rules that apply to us.',
        ),
        (
          'Processing your payments in and out, and running your savings, '
              'thrift and loan products',
          'Basis: performance of our contract with you.',
        ),
        (
          'Assessing whether to lend to you, and on what terms',
          'Basis: steps taken at your request before entering a contract, and '
              'our legitimate interest in lending responsibly.',
        ),
        (
          'Preventing, detecting and investigating fraud, and keeping accounts '
              'secure',
          'Basis: our legitimate interest in protecting you, other customers '
              'and ourselves — and, in places, a legal obligation.',
        ),
        (
          'Recovering money you owe us',
          'Basis: performance of our contract, and our legitimate interest in '
              'being repaid.',
        ),
        (
          'Answering your questions and handling complaints',
          'Basis: performance of our contract, and our legitimate interest in '
              'running a service people can rely on.',
        ),
        (
          'Improving the app, fixing faults and measuring how features are '
              'used',
          'Basis: our legitimate interest in a product that works. We use '
              'aggregated or de-identified data for this wherever we can.',
        ),
        (
          'Sending you marketing about Kudi9ja products',
          'Basis: your consent, which you can withdraw at any time.',
        ),
        (
          'Establishing, exercising or defending legal claims',
          'Basis: our legitimate interest, and compliance with a legal '
              'obligation.',
        ),
      ]),
      const LegalText(
        'Where we rely on a legitimate interest, we have weighed it against '
        'your rights and interests first. You can ask us to explain that '
        'balancing, and you can object to it.',
      ),
    ]),

    LegalSection('Credit scoring and automated decisions', [
      const LegalText(
        'When you apply for a loan we score your application using information '
        'we already hold — your repayment history with us, your savings '
        'behaviour, how long you have been a customer, how complete your '
        'verification is — together with data from licensed credit bureaux.',
      ),
      const LegalText(
        'Part of that assessment is automated. It can result in a smaller '
        'limit, a shorter tenure, or a decline.',
      ),
      const LegalNote(
        'If an automated decision goes against you, you have the right to be '
        'told the main reasons, to ask a member of our team to look at it '
        'again, to give us more information, and to contest the outcome. Write '
        'to ${AppConfig.privacyEmail} or ${AppConfig.supportEmail} and a human '
        'being will review it.',
        title: 'Your right to a human review',
        tone: LegalTone.positive,
      ),
      const LegalText(
        'Your credit score in the app is our own view, built for your benefit. '
        'It is not the score a credit bureau holds on you, and it is not a '
        'promise that we will lend.',
      ),
    ]),

    LegalSection('Who we share it with', [
      const LegalText(
        'We share personal data only where it is necessary, and only with '
        'people who are bound to protect it.',
      ),
      const LegalDefs([
        (
          'Identity verification providers',
          'To confirm your BVN and NIN against the records of the '
              'institutions that issued them.',
        ),
        (
          'Banks and payment partners',
          'To receive your transfers, to pay your withdrawals, and to trace a '
              'payment that has gone astray.',
        ),
        (
          'Licensed credit bureaux',
          'We report the existence, performance and settlement of your loan, '
              'as lenders are expected to. Repaying on time helps your record; '
              'not repaying harms it.',
        ),
        (
          'Regulators, law enforcement and courts',
          'Where we are required to report or to respond — for example to a '
              'court order, or to a financial intelligence request.',
        ),
        (
          'Technology suppliers',
          'Hosting, storage, messaging, error reporting and analytics '
              'providers who process data strictly on our written '
              'instructions.',
        ),
        (
          'Professional advisers',
          'Lawyers, auditors and insurers, under a duty of confidence.',
        ),
        (
          'Debt recovery partners',
          'Only where a loan is in default, only firms bound by our conduct '
              'standards, and never anybody who would contact people other '
              'than you.',
        ),
        (
          'A buyer or successor',
          'If our business is reorganised, merged or sold, under confidentiality '
              'and with your rights unchanged.',
        ),
      ]),
      const LegalNote(
        'We do not sell your personal data. We do not share it for anybody '
        'else\'s advertising. We do not disclose your borrowing to your '
        'employer, your family or your contacts.',
        tone: LegalTone.positive,
      ),
    ]),

    LegalSection('Sending data outside Nigeria', [
      const LegalText(
        'Some of the technology suppliers we use store data on servers outside '
        'Nigeria. Where that happens we transfer data only to a country the '
        'Nigeria Data Protection Commission recognises as providing adequate '
        'protection, or under a written contract that imposes the same '
        'standards this policy sets out — or with your explicit consent.',
      ),
      const LegalText(
        'You can ask us at ${AppConfig.privacyEmail} where your data is held '
        'and what safeguards apply.',
      ),
    ]),

    LegalSection('How long we keep it', [
      const LegalDefs([
        (
          'While you are a customer',
          'For as long as your account is open, plus the periods below.',
        ),
        (
          'Identity and transaction records',
          'At least **five years** after your relationship with us ends. '
              'Anti-money-laundering law requires this, and we cannot delete '
              'them earlier even if you ask.',
        ),
        (
          'Loan records',
          'At least five years after the loan is settled or written off.',
        ),
        (
          'Payment receipts you attach',
          'Five years, as part of the transaction record.',
        ),
        (
          'Support conversations',
          'Two years after the matter is closed, or longer if it concerns a '
              'live dispute.',
        ),
        (
          'Marketing preferences',
          'Until you withdraw consent, and then a minimal record of the '
              'withdrawal so we honour it.',
        ),
        (
          'Technical logs',
          'Up to 12 months, unless kept longer for a fraud or security '
              'investigation.',
        ),
      ]),
      const LegalText(
        'When a retention period ends, we delete the data or anonymise it '
        'beyond recovery.',
      ),
    ]),

    LegalSection('Data held on your phone', [
      const LegalText(
        'Kudi9ja stores your profile, balances, plans, loans, transaction '
        'history and preferences on your device so the app works quickly and '
        'without a connection. Your passcode, PIN and password are stored '
        'there only as one-way hashes.',
      ),
      const LegalText(
        'Anyone who can unlock your phone and get past your Kudi9ja passcode '
        'can see that data. Keep a screen lock on your device, keep your codes '
        'to yourself, and sign out on a device you no longer use. Deleting the '
        'app removes the local copy; it does not close your account or delete '
        'the records we hold.',
      ),
    ]),

    LegalSection('How we protect it', [
      const LegalList([
        'Passwords, passcodes and PINs are stored as salted one-way hashes and '
            'are never held or transmitted in readable form.',
        'Data in transit is encrypted.',
        'Access inside Kudi9ja is restricted by role, so staff see only what '
            'their job requires, and administrative actions are written to an '
            'audit log.',
        'Sensitive numbers such as your BVN and NIN are masked in the app and '
            'in our internal tools.',
        'Sign-in is protected by a passcode, transactions by a separate PIN, '
            'and the app locks itself after a short period of inactivity.',
        'Staff are trained on data protection, and are bound by '
            'confidentiality obligations that outlast their employment.',
      ]),
      const LegalText(
        'No system is perfect. If a breach occurs that is likely to put your '
        'rights at risk we will report it to the Nigeria Data Protection '
        'Commission within **72 hours** of becoming aware of it, and tell you '
        'without undue delay, in plain language, along with what we are doing '
        'and what you should do.',
      ),
    ]),

    LegalSection('Your rights', [
      const LegalText('Under the NDPA you have the right to:'),
      const LegalDefs([
        (
          'Be informed',
          'To know what we hold and what we do with it — that is what this '
              'policy is for.',
        ),
        ('Access', 'To get a copy of the personal data we hold about you.'),
        (
          'Rectification',
          'To have data that is wrong corrected, and data that is incomplete '
              'completed.',
        ),
        (
          'Erasure',
          'To have data deleted where we no longer have a lawful reason to '
              'keep it. Records the law requires us to retain are the '
              'exception.',
        ),
        (
          'Restriction',
          'To ask us to pause using your data while a dispute about it is '
              'sorted out.',
        ),
        (
          'Objection',
          'To object to processing based on our legitimate interests, and to '
              'stop direct marketing at any time, no reason needed.',
        ),
        (
          'Portability',
          'To receive the data you gave us in a structured, machine-readable '
              'format, and to have it sent to another provider where that is '
              'technically feasible.',
        ),
        (
          'Withdraw consent',
          'Where we rely on consent, to withdraw it at any time. That does not '
              'undo processing already carried out lawfully.',
        ),
        (
          'Human review',
          'To ask a person to review a decision made about you by automated '
              'means.',
        ),
        (
          'Complain',
          'To lodge a complaint with the Nigeria Data Protection Commission.',
        ),
      ]),
      const LegalText(
        'To exercise any of these, write to **${AppConfig.privacyEmail}**. We '
        'may need to confirm your identity first, so that we do not hand your '
        'data to somebody else. We answer within **30 days**; if a request is '
        'complex we will tell you why and how much longer we need.',
      ),
      const LegalText(
        'Exercising your rights is free. We only charge where a request is '
        'manifestly unfounded or repetitive, and we tell you before we do.',
      ),
    ]),

    LegalSection('Marketing', [
      const LegalText(
        'We will only send you marketing where you have agreed to it. Every '
        'marketing message carries a way to stop it, and you can turn it off '
        'in the app or by writing to ${AppConfig.privacyEmail}.',
      ),
      const LegalText(
        'Opting out of marketing does not stop the messages we must send about '
        'your account — a repayment reminder, a maturity notice, a security '
        'alert or a change to these documents.',
      ),
    ]),

    LegalSection('Children', [
      const LegalText(
        'Kudi9ja is for adults. We do not knowingly collect data about anybody '
        'under 18. If we learn that an account belongs to a child, we will '
        'close it and delete the data, except anything the law requires us to '
        'keep. If you believe a child has given us data, tell us at '
        '${AppConfig.privacyEmail}.',
      ),
    ]),

    LegalSection('Our website and cookies', [
      const LegalText(
        'The Kudi9ja app does not use advertising cookies or third-party '
        'trackers. Our website uses cookies that are strictly necessary to '
        'make it work, and — only with your consent — cookies that help us '
        'understand which pages are useful. You can refuse the optional ones '
        'without losing access to anything.',
      ),
    ]),

    LegalSection('Changes to this policy', [
      const LegalText(
        'We will update this policy as the law, our products or our suppliers '
        'change. Every version is dated and numbered.',
      ),
      const LegalText(
        'Where a change materially affects how we use your data, we will tell '
        'you in the app and by email at least **30 days** before it takes '
        'effect, and where the law requires your consent we will ask for it '
        'rather than assume it.',
      ),
    ]),

    LegalSection('Contact and complaints', [
      const LegalText(
        'Talk to us first — most concerns are resolved quickly. Write to '
        '**${AppConfig.privacyEmail}** and we will acknowledge within 24 hours '
        'and respond substantively within 30 days.',
      ),
      const LegalText(
        'If you are not satisfied with our answer, you may complain to the '
        '**Nigeria Data Protection Commission**, the supervisory authority for '
        'data protection in Nigeria. You do not need our permission, and you '
        'do not have to come to us first.',
      ),
    ]),
  ],
);
