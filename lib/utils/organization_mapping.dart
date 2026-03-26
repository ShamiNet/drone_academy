String normalizeOrganizationValue(dynamic value) {
  return value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
}

String affiliationFromDivision(dynamic division) {
  switch (normalizeOrganizationValue(division)) {
    case 'اللواء الأول':
    case 'الأول':
    case 'الأولى':
      return 'first';
    case 'اللواء الثاني':
    case 'الثاني':
    case 'الثانية':
      return 'second';
    case 'اللواء الثالث':
    case 'الثالث':
    case 'الثالثة':
      return 'third';
    case 'اللواء الرابع':
    case 'الرابع':
    case 'الرابعة':
      return 'fourth';
    case 'المدفعية':
      return 'artillery';
    case 'المركزية':
      return 'central';
    case 'إداري':
      return 'administrative';
    default:
      return '';
  }
}

String divisionFromAffiliation(dynamic affiliation) {
  switch (normalizeOrganizationValue(affiliation).toLowerCase()) {
    case 'first':
      return 'اللواء الأول';
    case 'second':
      return 'اللواء الثاني';
    case 'third':
      return 'اللواء الثالث';
    case 'fourth':
      return 'اللواء الرابع';
    case 'artillery':
      return 'المدفعية';
    case 'central':
      return 'المركزية';
    case 'administrative':
      return 'إداري';
    default:
      return '';
  }
}

String divisionLabelFromUser(Map<String, dynamic> user) {
  final division = normalizeOrganizationValue(user['division']);
  if (division.isNotEmpty) {
    return division;
  }

  return divisionFromAffiliation(user['affiliation']);
}
