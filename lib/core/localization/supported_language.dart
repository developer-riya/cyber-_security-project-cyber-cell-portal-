/// A language recognized by the Cyber Uday language selector.
///
/// The Eighth Schedule languages are represented here even before their ARB
/// bundles are translated. This keeps language metadata out of the widgets
/// and lets each locale become available incrementally.
class SupportedLanguage {
  const SupportedLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.locale,
    required this.isTranslated,
    required this.isAvailable,
    this.isPrimary = false,
    this.isRtl = false,
  });

  final String code;
  final String nativeName;
  final String englishName;
  final String locale;
  final bool isTranslated;
  final bool isAvailable;
  final bool isPrimary;
  final bool isRtl;

  static const List<SupportedLanguage> all = <SupportedLanguage>[
    SupportedLanguage(
      code: 'en',
      nativeName: 'English',
      englishName: 'English',
      locale: 'en',
      isTranslated: true,
      isAvailable: true,
      isPrimary: true,
    ),
    SupportedLanguage(
      code: 'hi',
      nativeName: 'हिन्दी',
      englishName: 'Hindi',
      locale: 'hi',
      isTranslated: true,
      isAvailable: true,
      isPrimary: true,
    ),
    SupportedLanguage(
      code: 'mr',
      nativeName: 'मराठी',
      englishName: 'Marathi',
      locale: 'mr',
      isTranslated: true,
      isAvailable: true,
      isPrimary: true,
    ),
    SupportedLanguage(
      code: 'as',
      nativeName: 'অসমীয়া',
      englishName: 'Assamese',
      locale: 'as',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'bn',
      nativeName: 'বাংলা',
      englishName: 'Bengali',
      locale: 'bn',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'brx',
      nativeName: 'बड़ो',
      englishName: 'Bodo',
      locale: 'brx',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'doi',
      nativeName: 'डोगरी',
      englishName: 'Dogri',
      locale: 'doi',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'gu',
      nativeName: 'ગુજરાતી',
      englishName: 'Gujarati',
      locale: 'gu',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'kn',
      nativeName: 'ಕನ್ನಡ',
      englishName: 'Kannada',
      locale: 'kn',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'ks',
      nativeName: 'کٲشُر',
      englishName: 'Kashmiri',
      locale: 'ks',
      isTranslated: false,
      isAvailable: false,
      isRtl: true,
    ),
    SupportedLanguage(
      code: 'kok',
      nativeName: 'कोंकणी',
      englishName: 'Konkani',
      locale: 'kok',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'ml',
      nativeName: 'മലയാളം',
      englishName: 'Malayalam',
      locale: 'ml',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'mni',
      nativeName: 'মৈতৈলোন',
      englishName: 'Manipuri',
      locale: 'mni',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'mai',
      nativeName: 'मैथिली',
      englishName: 'Maithili',
      locale: 'mai',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'ne',
      nativeName: 'नेपाली',
      englishName: 'Nepali',
      locale: 'ne',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'or',
      nativeName: 'ଓଡ଼ିଆ',
      englishName: 'Odia',
      locale: 'or',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'pa',
      nativeName: 'ਪੰਜਾਬੀ',
      englishName: 'Punjabi',
      locale: 'pa',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'sa',
      nativeName: 'संस्कृतम्',
      englishName: 'Sanskrit',
      locale: 'sa',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'sat',
      nativeName: 'ᱥᱟᱱᱛᱟᱲᱤ',
      englishName: 'Santali',
      locale: 'sat',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'sd',
      nativeName: 'سنڌي',
      englishName: 'Sindhi',
      locale: 'sd',
      isTranslated: false,
      isAvailable: false,
      isRtl: true,
    ),
    SupportedLanguage(
      code: 'ta',
      nativeName: 'தமிழ்',
      englishName: 'Tamil',
      locale: 'ta',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'te',
      nativeName: 'తెలుగు',
      englishName: 'Telugu',
      locale: 'te',
      isTranslated: false,
      isAvailable: false,
    ),
    SupportedLanguage(
      code: 'ur',
      nativeName: 'اردو',
      englishName: 'Urdu',
      locale: 'ur',
      isTranslated: false,
      isAvailable: false,
      isRtl: true,
    ),
  ];

  static List<SupportedLanguage> get primary => all
      .where((SupportedLanguage language) => language.isPrimary)
      .toList(growable: false);

  static SupportedLanguage? fromCode(String? code) {
    for (final SupportedLanguage language in all) {
      if (language.code == code) return language;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is SupportedLanguage && other.code == code;

  @override
  int get hashCode => code.hashCode;
}
