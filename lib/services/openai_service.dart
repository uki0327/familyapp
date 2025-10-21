import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

class OpenAIService {
  static final OpenAIService _instance = OpenAIService._internal();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  factory OpenAIService() {
    return _instance;
  }

  OpenAIService._internal();

  Future<String?> getApiKey() async {
    return await _dbHelper.getSetting('openai_api_key');
  }

  Future<void> saveApiKey(String apiKey) async {
    await _dbHelper.saveSetting('openai_api_key', apiKey);
  }

  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    final apiKey = await getApiKey();

    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenAI API 키가 설정되지 않았습니다. 설정 화면에서 API 키를 입력해주세요.');
    }

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {
          'role': 'system',
          'content': 'You are a professional translator specializing in Korean and Lao languages. '
              'Translate the given text accurately and naturally. '
              'Only provide the translation without any explanation or additional text.'
        },
        {
          'role': 'user',
          'content': 'Translate the following text from $sourceLanguage to $targetLanguage:\n\n$text'
        }
      ],
      'temperature': 0.3,
    });

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final translatedText = data['choices'][0]['message']['content'].toString().trim();

        // 번역 기록 저장
        await _dbHelper.saveTranslation(
          sourceText: text,
          translatedText: translatedText,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        );

        return translatedText;
      } else {
        final error = jsonDecode(response.body);
        throw Exception('번역 실패: ${error['error']['message'] ?? response.body}');
      }
    } catch (e) {
      throw Exception('번역 중 오류 발생: $e');
    }
  }

  // 언어 감지 함수
  String detectLanguage(String text) {
    // 라오어 유니코드 범위: U+0E80 ~ U+0EFF
    final laoRegex = RegExp(r'[\u0E80-\u0EFF]');
    // 한글 유니코드 범위: U+AC00 ~ U+D7A3 (완성형 한글)
    final koreanRegex = RegExp(r'[\uAC00-\uD7A3]');

    if (laoRegex.hasMatch(text)) {
      return 'Lao';
    } else if (koreanRegex.hasMatch(text)) {
      return 'Korean';
    }

    // 기본값은 한국어로 설정
    return 'Korean';
  }

  Future<String> autoTranslate(String text) async {
    final sourceLanguage = detectLanguage(text);
    final targetLanguage = sourceLanguage == 'Korean' ? 'Lao' : 'Korean';

    return await translate(
      text: text,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
    );
  }
}
