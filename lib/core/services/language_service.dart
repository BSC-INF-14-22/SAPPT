import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  english,
  chichewa,
}

class LanguageService {
  static const _languageKey = 'selected_language';
  static final ValueNotifier<AppLanguage> languageNotifier =
      ValueNotifier<AppLanguage>(AppLanguage.english);

  static Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(_languageKey);
    languageNotifier.value = _fromStorageValue(savedValue);
  }

  static Future<void> setLanguage(AppLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.storageValue);
    languageNotifier.value = language;
  }

  static AppLanguage get currentLanguage => languageNotifier.value;

  static bool get isChichewa => currentLanguage == AppLanguage.chichewa;

  static String text({
    required String english,
    required String chichewa,
  }) {
    return isChichewa ? chichewa : english;
  }

  static String cropNameForCurrentLanguage(String cropName) {
    return cropNameForLanguage(cropName, currentLanguage);
  }

  static String cropNameForLanguage(String cropName, AppLanguage language) {
    if (language != AppLanguage.chichewa) return cropName;

    final normalized = _normalizeCropName(cropName);
    final spaced = normalized.replaceAll('-', ' ');
    final compact = spaced.replaceAll(RegExp(r'\s+'), ' ');

    return _chichewaCropNames[normalized] ??
        _chichewaCropNames[spaced] ??
        _chichewaCropNames[compact] ??
        cropName;
  }

  static String _normalizeCropName(String cropName) {
    return cropName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\)]'), '')
        .replaceAll(RegExp(r'[_/]+'), '-')
        .replaceAll(RegExp(r'\s*-\s*'), '-')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static AppLanguage _fromStorageValue(String? value) {
    return AppLanguage.values.firstWhere(
      (language) => language.storageValue == value,
      orElse: () => AppLanguage.english,
    );
  }

  static const Map<String, String> _chichewaCropNames = {
    'maize': 'Chimanga',
    'corn': 'Chimanga',
    'beans': 'Nyemba',
    'bean': 'Nyemba',
    'rice': 'Mpunga',
    'rice-polished': 'Mpunga wopukutidwa',
    'rice polished': 'Mpunga wopukutidwa',
    'rice-unpolished': 'Mpunga wosapukutidwa',
    'rice unpolished': 'Mpunga wosapukutidwa',
    'groundnuts': 'Mtedza',
    'groundnut': 'Mtedza',
    'peanuts': 'Mtedza',
    'peanut': 'Mtedza',
    'soybeans': 'Soya',
    'soybean': 'Soya',
    'soya beans': 'Soya',
    'sorghum': 'Mapira',
    'millet': 'Mapira',
    'cassava': 'Chinangwa',
    'cassava-dried': 'Chinangwa chowuma',
    'cassava dried': 'Chinangwa chowuma',
    'cassava wet': 'Chinangwa chonyowa',
    'cassava-wet': 'Chinangwa chonyowa',
    'irish potatoes': 'Mbatata ya Irish',
    'irish potato': 'Mbatata ya Irish',
    'sweet potatoes': 'Mbatata',
    'sweet potato': 'Mbatata',
    'potatoes': 'Mbatata',
    'potato': 'Mbatata',
    'tomatoes': 'Matimati',
    'tomato': 'Matimati',
    'onions': 'Anyezi',
    'onion': 'Anyezi',
    'garlic': 'Adyo',
    'cabbage': 'Kabichi',
    'pumpkins': 'Maungu',
    'pumpkin': 'Dzungu',
    'cotton': 'Thonje',
    'tobacco': 'Fodya',
    'sunflower': 'Mpendadzuwa',
    'wheat': 'Tirigu',
    'bananas': 'Nthochi',
    'banana': 'Nthochi',
    'mangoes': 'Mango',
    'mango': 'Mango',
    'peas': 'Nandolo',
    'pea': 'Nandolo',
    'cowpeas': 'Khobwe',
    'cowpea': 'Khobwe',
  };
}

extension AppLanguageText on AppLanguage {
  String get storageValue {
    switch (this) {
      case AppLanguage.english:
        return 'english';
      case AppLanguage.chichewa:
        return 'chichewa';
    }
  }

  String get displayName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.chichewa:
        return 'Chichewa';
    }
  }

  String get localName {
    switch (this) {
      case AppLanguage.english:
        return 'English';
      case AppLanguage.chichewa:
        return 'Chichewa';
    }
  }
}
