# 해먹노트 Flutter 앱

## 실행 환경 메모

현재 WSL에서 `/mnt/c/flutter/bin/flutter`를 직접 실행하면 Windows 줄바꿈 때문에
`/usr/bin/env: ‘bash\r’: Permission denied` 오류가 난다.

이 환경에서는 Windows Flutter를 `cmd.exe` 경유로 실행한다.

```bash
/mnt/c/Windows/System32/cmd.exe /c C:\\flutter\\bin\\flutter.bat analyze
/mnt/c/Windows/System32/cmd.exe /c C:\\flutter\\bin\\flutter.bat test
```

일반 Windows 터미널에서는 다음 명령을 사용한다.

```powershell
flutter analyze
flutter test
flutter run
```

## API 설정

로컬 기본 API 주소는 `http://localhost:8000/api`다.

필요하면 `.env`에 `API_BASE_URL`을 지정하고 다음처럼 실행한다.

```bash
flutter run --dart-define-from-file=.env
```
