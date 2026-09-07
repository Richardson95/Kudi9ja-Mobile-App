/// The banks a customer can be paid out to, as a fallback.
///
/// **The server owns this list.** It is fetched from `/banks` and this copy is
/// only what the picker shows before the first response arrives, or when the
/// phone is offline.
///
/// It exists as a copy at all because a customer opening the app on a bad
/// connection should still see something to choose from. It is deliberately the
/// server's exact names, not friendlier short ones: the server matches the bank
/// by name when it validates a payout account, so "OPay" and "GTBank" — which
/// is what this list used to say — were refused with "Choose a bank from the
/// list" on a screen where the customer had just chosen one from the list.
///
/// Six of the fourteen names here were wrong that way. If you edit this list,
/// copy the names from `GET /banks` rather than typing what the bank calls
/// itself on its own app.
const kFallbackBanks = <String>[
  'Access Bank',
  'Access Bank (Diamond)',
  'ALAT by Wema',
  'ASO Savings and Loans',
  'Citibank Nigeria',
  'Ecobank Nigeria',
  'Ekondo Microfinance Bank',
  'Fidelity Bank',
  'First Bank of Nigeria',
  'First City Monument Bank',
  'FSDH Merchant Bank',
  'Globus Bank',
  'Guaranty Trust Bank',
  'Heritage Bank',
  'Jaiz Bank',
  'Keystone Bank',
  'Kuda Microfinance Bank',
  'Carbon',
  'Parallex Bank',
  'Polaris Bank',
  'Providus Bank',
  'Stanbic IBTC Bank',
  'Standard Chartered Bank',
  'Sterling Bank',
  'Suntrust Bank',
  'Titan Trust Bank',
  'Union Bank of Nigeria',
  'United Bank for Africa',
  'Unity Bank',
  'Wema Bank',
  'Zenith Bank',
  'Moniepoint Microfinance Bank',
  'CEMCS Microfinance Bank',
  'PalmPay',
  'OPay Digital Services',
];
