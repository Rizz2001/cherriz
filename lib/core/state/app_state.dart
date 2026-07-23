class AppState {
  static Map<String, dynamic>? currentUserProfile;

  static String? get role => currentUserProfile?['role'];
  static String? get companyId => currentUserProfile?['company_id'];
  static String? get fullName => currentUserProfile?['full_name'];
  static String? get employeeId => currentUserProfile?['id'];
  
  static bool get isAdmin => role == 'ADMIN';
  static bool get isManager => role == 'MANAGER';
  static bool get isCashier => role == 'CASHIER';

  static void clear() {
    currentUserProfile = null;
  }
}
