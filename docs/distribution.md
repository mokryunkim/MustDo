# MustDo 배포/실행 가이드

## 로컬 실행
```bash
cd /Users/rina/MustDo
swift run StickyMVP
```

## 앱 번들 생성
```bash
cd /Users/rina/MustDo
bash scripts/make_app_bundle.sh
```

생성 결과:
- `dist/MustDo.app`

실행:
```bash
open dist/MustDo.app
```

## 릴리즈 파일 생성 (DMG/PKG)
```bash
cd /Users/rina/MustDo
bash scripts/make_release.sh
```

생성 결과:
- `dist/release/MustDo-0.1.0.dmg`
- `dist/release/MustDo-0.1.0.pkg`
