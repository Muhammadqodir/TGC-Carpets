import '../../domain/entities/employee_entity.dart';

class EmployeeModel extends EmployeeEntity {
  const EmployeeModel({
    required super.id,
    required super.name,
    required super.email,
    super.phone,
    required super.roles,
    required super.createdAt,
    required super.updatedAt,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
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
    
    return EmployeeModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      roles: roles,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
