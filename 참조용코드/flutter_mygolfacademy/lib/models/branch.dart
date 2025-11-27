class Branch {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String? businessRegNo;
  final String? managerName;
  final String? managerPhone;

  Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.businessRegNo,
    this.managerName,
    this.managerPhone,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['branch_id']?.toString() ?? '',
      name: json['branch_name']?.toString() ?? '',
      address: json['branch_address']?.toString() ?? '',
      phone: json['branch_phone']?.toString() ?? '',
      businessRegNo: json['branch_business_reg_no']?.toString(),
      managerName: json['branch_director_name']?.toString(),
      managerPhone: json['branch_director_phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'branch_id': id,
      'branch_name': name,
      'branch_address': address,
      'branch_phone': phone,
      'branch_business_reg_no': businessRegNo,
      'branch_director_name': managerName,
      'branch_director_phone': managerPhone,
    };
  }
} 