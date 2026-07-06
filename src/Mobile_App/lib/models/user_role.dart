import 'package:flutter/foundation.dart';

enum UserRole {
  admin,
  technician,
}

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.technician:
        return 'Technician';
    }
  }

  bool get isAdmin => this == UserRole.admin;
  bool get isTechnician => this == UserRole.technician;
}

class UserRoleController extends ChangeNotifier {
  UserRole _role = UserRole.admin;

  UserRole get role => _role;
  bool get isAdmin => _role.isAdmin;
  bool get isTechnician => _role.isTechnician;

  void setRole(UserRole role) {
    if (_role == role) return;
    _role = role;
    notifyListeners();
  }
}
