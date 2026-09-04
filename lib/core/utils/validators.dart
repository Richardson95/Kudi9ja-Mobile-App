abstract final class Validators {
  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? fullName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Full name is required';
    final parts = v.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return 'Enter your first and last name';
    if (parts.any((p) => p.length < 2)) return 'Each name needs 2+ letters';
    if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(v)) return 'Letters only, please';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email address is required';
    final ok = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]{2,}$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email address';
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 11 || !digits.startsWith('0')) {
      return 'Enter an 11-digit number e.g. 08031234567';
    }
    return null;
  }

  static String? bvn(String? v) {
    if (v == null || v.trim().isEmpty) return 'BVN is required';
    if (v.replaceAll(RegExp(r'[^0-9]'), '').length != 11) {
      return 'BVN must be exactly 11 digits';
    }
    return null;
  }

  static String? nin(String? v) {
    if (v == null || v.trim().isEmpty) return 'NIN is required';
    if (v.replaceAll(RegExp(r'[^0-9]'), '').length != 11) {
      return 'NIN must be exactly 11 digits';
    }
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Add an uppercase letter';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Add a lowercase letter';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Add a number';
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(v)) {
      return 'Add a special character';
    }
    return null;
  }

  /// 0-5 strength score powering the signup meter.
  static int passwordScore(String v) {
    var s = 0;
    if (v.length >= 8) s++;
    if (v.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[a-z]').hasMatch(v)) s++;
    if (RegExp(r'[0-9]').hasMatch(v)) s++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(v)) s++;
    return s;
  }

  static String? dateOfBirth(DateTime? d) {
    if (d == null) return 'Date of birth is required';
    final years = DateTime.now().difference(d).inDays / 365.25;
    if (years < 18) return 'You must be at least 18 years old';
    if (years > 100) return 'Please check the date entered';
    return null;
  }

  /// Rejects trivially guessable passcodes (repeats and straight runs).
  static String? passcodeStrength(String code) {
    if (code.split('').toSet().length == 1) {
      return 'Avoid repeating a single digit';
    }
    var ascending = true;
    var descending = true;
    for (var i = 1; i < code.length; i++) {
      final prev = int.parse(code[i - 1]);
      final cur = int.parse(code[i]);
      if (cur != prev + 1) ascending = false;
      if (cur != prev - 1) descending = false;
    }
    if (ascending || descending) return 'Avoid sequential digits';
    return null;
  }
}
