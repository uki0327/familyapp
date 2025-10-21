# Family App

Flutter로 개발된 가족 관리 애플리케이션입니다. 웹, 안드로이드, iOS를 모두 지원합니다.

## 기능

- 가족 구성원 관리
- Material Design 3 적용
- 다크 모드 지원
- 반응형 UI

## 개발 환경

- Flutter 3.35.6
- Dart 3.9.2

## 실행 방법

### 웹 실행
```bash
export PATH="$PATH:/home/user/flutter/bin"
flutter run -d chrome
```

### 웹 빌드
```bash
export PATH="$PATH:/home/user/flutter/bin"
flutter build web
```

빌드된 파일은 `build/web` 디렉토리에 생성됩니다.

### 안드로이드 빌드
```bash
export PATH="$PATH:/home/user/flutter/bin"
flutter build apk
```

### iOS 빌드 (macOS에서만 가능)
```bash
export PATH="$PATH:/home/user/flutter/bin"
flutter build ios
```

## 프로젝트 구조

```
lib/
  main.dart          # 메인 애플리케이션 코드
web/                 # 웹 플랫폼 파일
android/             # 안드로이드 플랫폼 파일
ios/                 # iOS 플랫폼 파일
```

## 개발 시작하기

1. Flutter SDK 설치 확인
```bash
flutter doctor
```

2. 의존성 설치
```bash
flutter pub get
```

3. 개발 서버 실행
```bash
flutter run
```

## 빌드 결과

- 웹 빌드: `build/web/`
- 안드로이드 빌드: `build/app/outputs/flutter-apk/`
- iOS 빌드: `build/ios/iphoneos/`
