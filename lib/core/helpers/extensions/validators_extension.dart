extension ValidatorsExtension on String {
  bool get isValidEmail {
    const pattern =
        r"(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'"
        r'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-'
        r'\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*'
        r'[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4]'
        r'[0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9]'
        r'[0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\'
        r'x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])';
    final regex = RegExp(pattern);

    if (!regex.hasMatch(this)) {
      return false;
    } else {
      return true;
    }
  }

  bool get isEnglishName {
    const pattern = r"^[a-zA-Z\s]+$";
    final regex = RegExp(pattern);

    return regex.hasMatch(this);
  }

  bool get hasNumbers {
    const pattern = r'[0-9]';
    final regex = RegExp(pattern);

    return regex.hasMatch(this);
  }

  bool get hasArabicCharacters {
    const pattern = r'[\u0600-\u06FF]';
    final regex = RegExp(pattern);

    return regex.hasMatch(this);
  }
}
