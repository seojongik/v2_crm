class User {
  final String id;
  final String name;
  final String phone;
  final String? nickname;
  final String? gender;
  final String? address;
  final String? birthday;
  final String? memo;
  final String? email;
  final String? profileImage;
  final String? branchId;

  User({
    required this.id,
    required this.name,
    required this.phone,
    this.nickname,
    this.gender,
    this.address,
    this.birthday,
    this.memo,
    this.email,
    this.profileImage,
    this.branchId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] != null ? json['id'].toString() : '',
      name: json['name'] != null ? json['name'] : '',
      phone: json['phone'] != null ? json['phone'] : '',
      nickname: json['nickname'],
      gender: json['gender'],
      address: json['address'],
      birthday: json['birthday'],
      memo: json['memo'],
      email: json['email'],
      profileImage: json['profileImage'],
      branchId: json['branchId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      if (nickname != null) 'nickname': nickname,
      if (gender != null) 'gender': gender,
      if (address != null) 'address': address,
      if (birthday != null) 'birthday': birthday,
      if (memo != null) 'memo': memo,
      if (email != null) 'email': email,
      if (profileImage != null) 'profileImage': profileImage,
      if (branchId != null) 'branchId': branchId,
    };
  }
} 