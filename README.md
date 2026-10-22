# 하늘 오피스

AI 에이전트 (Claude Code) 가 일하는 모습을 바탕화면 위 '하늘에 뜬 사무실' 로 보여 주는 게임. (지금은 **Claude Code 만** 지원)

## 설치 · 연결 · 제거 (사용자 안내)

1. **받기**: [릴리스 페이지](https://github.com/Dawnilove/Sky_Office/releases) 에서 `SkyOffice-버전-windows-x64.zip` 을 받아 **압축 풀기** (오른쪽 클릭 → 모두 압축 풀기)
2. **켜기**: 풀린 폴더의 `SkyOffice.exe` 를 두 번 클릭 → 회사 이름 · 직원 이름 정하기
3. **연결**: 사무실의 전화기 (또는 설정) 에서 **[개통하기]**
   - `claude 명령을 못 찾았어요` 가 뜨면 **[명령 복사]** → Claude Code 를 쓰는 **PowerShell** 에 붙여 넣고 Enter (2줄)
   - 열려 있던 Claude Code 는 **껐다 다시 켜기**
4. **확인**: Claude Code 에서 아무 일이나 시키면 직원이 움직여요
5. **제거**: 게임 설정 > 회사 탭 맨 아래 **폐업 정리** (플러그인 · 저장 · 자동 실행 지움). 게임 폴더는 직접 삭제
- 신호는 종류 · 도구 이름 · 폴더 끝 이름만 받고, 대화 · 파일 내용은 안 받아요. 저장은 내 PC 안에만 (`%USERPROFILE%\.skyoffice` · `%APPDATA%\SkyOffice`)

## 0.1.0 에 있는 것
- 하늘에 뜬 사무실: Claude Code 세션 하나 = 직원 한 명. 일하면 책상에서 일하고, **내 차례(허락 · 질문)** 가 오면 노랑 알림으로 불러요
- 명패(이름 · 작업 폴더), 호출 보드, 서브에이전트가 끝나면 날아오는 봉투
- 회사 성장: 근무일이 쌓이면 6단계(창업 → 스타트업)로 사무실이 커져요. 하루 = Claude 5시간 창 (낮 → 밤)
- 회사 생활: 아침 조회 · 점심 · 쉬는 직원의 잔잔한 움직임. 설정에서 **조용히 모드** 로 끌 수 있어요
- 게시판 큰 창, 합성 환경음, 자동 업데이트, **폐업 정리** (흔적 0)

## 다음 버전 목표
- 사장 → PM → 전문가 분업 (서브에이전트별 직원), 직원 배정 규칙 변경
- 밝은 사무실 마무리 (말풍선 · 그림자 · 캐릭터 · 소품), 새 배경음악
- (검토 중) 게임 안에서 명령 보내기, Claude Code 외 도구 지원

## 제한
- **Claude Code 만** 지원 · Windows 11 x64
- 신호는 종류 · 도구 이름 · 폴더 끝 이름만 받아요. 대화 · 파일 내용은 받지 않아요

## 개발자용
- Godot 4.7 .NET (`game/`), 개발 확인: `bash tools/offscreen_test.sh --scenario` (화면 없이 시험)
- 배포 빌드 `tools/build_release.sh` 는 서명 비밀 키가 있는 개발 PC 에서만 (공개 키 = `tools/signing/update_public.pem`)
- 에셋 출처 · 라이선스: [game/assets/LICENSES.md](game/assets/LICENSES.md)

## 라이선스
MIT ([LICENSE](LICENSE)). 포함된 제3자 자료 — Godot Engine (MIT, Copyright Juan Linietsky, Ariel Manzur and Godot Engine contributors) · 주아 글꼴 (OFL 1.1) · CC0 에셋은 `game/assets/LICENSES.md`
