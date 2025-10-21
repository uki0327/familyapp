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
    try {
      print('[OpenAIService] getApiKey 호출');
      final apiKey = await _dbHelper.getSetting('openai_api_key');
      print('[OpenAIService] API 키 조회 결과: ${apiKey != null ? "존재함 (길이: ${apiKey.length})" : "없음"}');
      return apiKey;
    } catch (e, stackTrace) {
      print('[OpenAIService] getApiKey 에러: $e');
      print('[OpenAIService] 스택 트레이스: $stackTrace');
      rethrow;
    }
  }

  Future<void> saveApiKey(String apiKey) async {
    try {
      print('[OpenAIService] saveApiKey 호출 - API 키 길이: ${apiKey.length}');

      if (apiKey.trim().isEmpty) {
        print('[OpenAIService] 빈 API 키는 저장하지 않음');
        return;
      }

      await _dbHelper.saveSetting('openai_api_key', apiKey);
      print('[OpenAIService] API 키 저장 성공');

      // 저장 검증
      final savedKey = await getApiKey();
      if (savedKey == apiKey) {
        print('[OpenAIService] API 키 저장 및 검증 완료');
      } else {
        print('[OpenAIService] 경고: 저장된 키가 입력한 키와 다름');
        throw Exception('API 키 저장 검증 실패');
      }
    } catch (e, stackTrace) {
      print('[OpenAIService] saveApiKey 에러: $e');
      print('[OpenAIService] 스택 트레이스: $stackTrace');
      rethrow;
    }
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
