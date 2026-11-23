# Godot Hub

고도 엔진 프로젝트와 에디터 버전을 한 곳에서 관리하는 런처입니다. Godot 4.7로 만들었어요.
화면은 고도 프로젝트 매니저와 같은 배치(위쪽 탭: 프로젝트 · 설치)이고, 색·폰트·아이콘도 고도 스타일을 씁니다.
기획 내용은 [PLAN.md](PLAN.md)에 있어요.

## 설치

[릴리즈 페이지](https://github.com/FORMAT-Hyun/godot-hub/releases/latest)에서 `GodotHub-<버전>-Setup.exe`를 받아 실행하세요.
관리자 권한 없이 내 계정에 설치되고, 시작 메뉴(선택하면 바탕화면)에 바로가기가 생겨요.
제거는 Windows 설정 > 앱에서 할 수 있어요. 설치 없이 쓰려면 `GodotHub-<버전>-portable.zip`을 받아 압축을 풀고 실행하세요.

설치 파일 만들기 (Inno Setup 6 필요):

```powershell
& "D:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path "D:\고도 허브" --export-release "Windows Desktop" "D:\고도 허브\build\GodotHub.exe"
```

```powershell
& "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" "D:\고도 허브\installer\GodotHub.iss"
```

## 소스에서 실행

1. Godot 4.7 에디터로 이 폴더를 열고 F5를 누릅니다.
   (처음 한 번은 에디터로 열거나 `--import`를 실행해야 클래스 이름이 등록돼요.)
2. 명령줄로 실행하려면:

```powershell
& "D:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe" --path "D:\고도 허브"
```

## 기능

- **프로젝트**: 폴더 추가, 하위 폴더 자동 탐색, 창에 드래그&드롭, 검색·정렬·즐겨찾기,
  프로젝트별 에디터 버전 지정, 더블클릭으로 열기, 버전이 다르면 열기 전에 경고.
  오른쪽 메뉴(고도 프로젝트 매니저와 같은 구성): 편집(자세한 로그 · 복구 모드 · 다른 버전),
  실행, 이름 바꾸기, 복제, 태그 설정(`tag:이름`으로 검색), 제거(폴더 휴지통 이동 선택), 누락된 부분 제거, 기부
- **설치**: GitHub(godotengine/godot-builds)에서 Stable / 프리릴리스 / 아카이브 버전 설치
  (표준 · .NET), 설치 경로 지정, 기존 exe 등록(위치 지정), 에디터 설정 열기(기본: 허브 안 설정 창 — 그 버전 에디터에서 목록 항목·범위·기본값·한국어 이름·단축키를
  읽어 와 고도와 같은 입력칸으로 보여 주고, 설정 파일이 없는 버전이면 처음 열 때 만들어 줌 /
  설정에서 "고도 에디터의 설정 창"으로 바꾸면 그 버전 에디터의 진짜 설정 창을 본창 없이 띄움),
  독립 모드(`._sc_`) 켜기/끄기, 제거(휴지통으로 이동).
  내보내기 템플릿은 고도 에디터의 "편집기 > 내보내기 템플릿 관리"에서 설치해요.
- **새 프로젝트**: Forward+ / Mobile / Compatibility 렌더러 선택, Git 초기화
- **설정**: 설치 경로, 새 프로젝트 기본 위치, 에디터 실행 후 허브 동작, 화면 배율, 에디터 설정 창 방식, GitHub 토큰

허브 데이터는 `%APPDATA%\GodotHub\hub_data`에, 에디터는 기본적으로
`%LOCALAPPDATA%\GodotHub\Editors`에 설치돼요.

## 개발용 옵션 (`--` 뒤에 붙임)

| 옵션 | 설명 |
|------|------|
| `--hub-data=<폴더>` | 실제 데이터 대신 테스트용 데이터 폴더 사용 |
| `--hub-page=installs` | 시작할 페이지 (projects / installs) |
| `--hub-dialog=new` | 시작하자마자 창 열기 (new / install / settings / editor-settings / properties) |
| `--hub-es-search=<검색어>` | `--hub-dialog=editor-settings`와 함께: 설정 창에 검색어를 넣어 둠 |
| `--hub-screenshot=<png>` | 화면을 PNG로 저장하고 종료 (`--hub-shot-delay=초`) |

다운로드 테스트:

```powershell
& "D:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe" --headless --path "D:\고도 허브" res://tests/test_download.tscn -- --hub-data=D:\temp\hubtest
```

## 구조

```
scripts/core/   Hub(데이터) · Releases(GitHub 목록) · Downloads(다운로드 큐) · 버전/프로젝트 파서
scripts/ui/     메인 화면 · 페이지 · 대화상자 · 테마 · 아이콘
tests/          다운로드 테스트 씬
```
