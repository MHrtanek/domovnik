abstract class Validators {
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'E-mail je povinný';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Zadajte platný e-mail';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Heslo je povinné';
    }
    if (value.length < 6) {
      return 'Heslo musí mať aspoň 6 znakov';
    }
    return null;
  }

  static String? required(String? value, {String fieldName = 'Toto pole'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName je povinné';
    }
    return null;
  }

  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Meno a priezvisko je povinné';
    }
    if (value.trim().length < 3) {
      return 'Meno musí mať aspoň 3 znaky';
    }
    return null;
  }

  static String? buildingName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Názov budovy je povinný';
    }
    return null;
  }

  static String? buildingAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Adresa budovy je povinná';
    }
    return null;
  }

  static String? pollOption(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Možnosť nemôže byť prázdna';
    }
    return null;
  }
}
