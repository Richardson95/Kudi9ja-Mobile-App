/// Everything collected across the signup wizard, held in one place until
/// the final step commits it to an account.
class SignupDraft {
  /// The server's draft this wizard is filling in, once the first step has
  /// created one.
  ///
  /// Sign-up is validated a step at a time rather than all at the end, so an
  /// email already in use is caught on the screen that asked for it instead of
  /// after the customer has typed a BVN, a bank account and three passcodes.
  /// An abandoned draft expires on the server; it never becomes a half-made
  /// account that can be neither finished nor signed into.
  String? draftId;

  String fullName = '';
  String email = '';
  String phone = '';
  DateTime? dateOfBirth;
  String gender = '';

  String bvn = '';
  String nin = '';
  String address = '';
  String stateOfResidence = '';

  /// The customer's own bank account — where Kudi9ja pays money out to.
  /// Kudi9ja issues no account numbers of its own.
  String payoutBank = '';
  String payoutAccountNumber = '';

  String password = '';
  String securityQuestion = '';
  String securityAnswer = '';

  String signInPasscode = '';
  String transactionPin = '';

  bool emailVerified = false;
  bool identityVerified = false;
  bool termsAccepted = false;
}

const kNigerianStates = <String>[
  'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue',
  'Borno', 'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu',
  'FCT - Abuja', 'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina',
  'Kebbi', 'Kogi', 'Kwara', 'Lagos', 'Nasarawa', 'Niger', 'Ogun', 'Ondo',
  'Osun', 'Oyo', 'Plateau', 'Rivers', 'Sokoto', 'Taraba', 'Yobe', 'Zamfara',
];

const kSecurityQuestions = <String>[
  'What was the name of your first school?',
  'What is your mother’s maiden name?',
  'What city were you born in?',
  'What was the name of your first pet?',
  'What is your favourite childhood meal?',
];

const kGenders = <String>['Female', 'Male', 'Prefer not to say'];
