import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.roles,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleData = json['role'];
    final List<String> roles;
    
    if (roleData is List) {
      roles = roleData.map((r) => r.toString()).toList();
    } else if (roleData is String) {
      // Backward compatibility: if API returns single role string
      roles = [roleData];
    } else {
      roles = [];
    }
    
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      roles: roles,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': roles,
      };
}
