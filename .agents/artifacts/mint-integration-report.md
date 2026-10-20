# Quickshell-Oomaya Linux Mint VM Integration Report

## 1. Executive Summary
사용자께서 Linux Mint 22 VM 환경에 빌드/설치해 두신 Quickshell 0.3.2 환경에서 `quickshell-oomaya`가 정상 구동되고 `dwm-oomaya`와 완벽히 연동되도록 핵심 결함 해결 및 시스템 통합 작업을 완료했습니다.

---

## 2. 주요 해결 과제 및 진단 결과

### 1) QML 컴파일 충돌 및 Core Dump 해결 (Root Cause)
- **증상**: `quickshell --path ~/.config/quickshell/shell.qml` 실행 시 설정 로드 실패 및 `SIGSEGV`로 비정상 종료.
- **원인 분석**:
  - Qt 6.6+ QML 컴파일러 환경에서 `settings/SystemRegionalControls.qml`의 `Connections` 블록 내에 `function onEnabledChanged()` 선언 존재.
  - `Connections` 객체 자체가 `enabled` 프로퍼티와 `enabledChanged()` 시그널을 가지고 있어 `Duplicate method name: invalid override of property change signal or superclass signal` 에러 발생.
  - 이로 인해 `SystemRegionalControls` $\rightarrow$ `SystemSettingsPane` $\rightarrow$ `SettingsWindow` $\rightarrow$ `shell.qml` 연쇄 로딩 실패 및 QuickShell의 `RootWrapper::reloadGraph` 널 포인터 참조 크래시 발생.
- **조치**:
  - `Connections` 대신 idiomatic QML 프로퍼티 바인딩(`reconciliationFocusEnabled`, `focusReturnEnabled`)과 핸들러로 리팩토링.
  - 수정 후 `shell.qml`이 정상 로드되어 상단 바 패널(2558x32), Fcitx 및 블루투스 시스템 트레이, PipeWire 오디오 리스너가 즉각 온라인 상태로 전환됨.

### 2) D-Bus 알림 레이스 컨디션 및 데스크톱 모드 전환 (`dwm-shell-mode`)
- **증상**: Quickshell 모드로 전환 시 Dunst와 Quickshell이 경합하여 Dunst가 D-Bus autostart에 의해 재실행되는 문제.
- **원인 분석**: `set_quickshell_mode()`에서 Quickshell 프로세스 실행 직후 D-Bus 서비스 등록 완료 전에 `notify-send`가 호출되어 D-Bus 데몬이 `/usr/bin/dunst`를 자동 구동함.
- **조치**:
  - `dwm-shell-mode` 스크립트에 Quickshell IPC 핑 루프를 추가하여 D-Bus 인터페이스가 준비된 후 알림을 발행하도록 안정화.
  - `~/.local/bin/quickshell` 래퍼 및 바이너리 경로를 정비하여 `pgrep -x quickshell` 및 `dwm-controlcenter`, `dwm-keybinds`, `dwm-settings`가 원활하게 IPC 호출(`quickshell ipc call`)로 연결되도록 구성.

### 3) 독립 저장소 분리에 따른 테스트 스위트 및 환경 호환성 확보
- **coreutils 9.4 `mv --exchange` 호환성**:
  - Linux Mint 22 (Ubuntu 24.04 기반)의 coreutils 9.4에는 GNU 9.5의 `--exchange` 옵션이 없어서 `dwm-panel-settings`의 원자적 파일 교환 검증이 실패하는 현상 발견.
  - Linux 커널의 네이티브 `renameat2(AT_FDCWD, ..., RENAME_EXCHANGE)` 시스템 콜을 호출하는 고속 C shim(`tools/mv-shim.c` $\rightarrow$ `~/.local/bin/mv`)을 빌드하여 완전한 원자적 롤백 및 동시성 방어 능력 확보.
- **`quickshell-qmllint` Qt 6.6.3 탐색 및 린트 플래그 최적화**:
  - `/home/rand/Qt/6.6.3/gcc_64`를 자동 감지하고 최신 Qt 6.6 린트 플래그를 정비하여 컴포넌트 유효성 검사 통과.
- **`dwm-quickshell-controls` 워치독 데드락 방지**:
  - 백그라운드 워치독 서브셸 종료 시 `kill -KILL`을 추가하여 `wait "$watchdog_pid"` 블로킹 버그 해결.

---

## 3. 현재 동작 검증 상태

| 컴포넌트 / 기능 | 상태 | 검증 내용 |
| :--- | :---: | :--- |
| **Quickshell 프로세스** | 🟢 RUNNING | PID 정상 동작, 메모리 누수/크래시 없음 |
| **상단 패널 (DwmPanel)** | 🟢 ACTIVE | X11 윈도우 생성 (2558x32+0+0), 작업공간 및 날씨/시계 정상 출력 |
| **시스템 트레이 (SystemTray)** | 🟢 ACTIVE | `blueman`, `Fcitx` 등록 완료 |
| **알림 데몬 (Notifications)** | 🟢 ACTIVE | Dunst 대체, Quickshell 네이티브 팝업 및 히스토리 수신 |
| **컨트롤 센터 (ControlCenter)** | 🟢 ACTIVE | `dwm-controlcenter` 및 Super+C / Alt+C 단축키로 토글 확인 |
| **단축키 팔레트 (Keybinds)** | 🟢 ACTIVE | `dwm-keybinds` (Super+/) 연동 확인 |
| **설정 허브 (Settings)** | 🟢 ACTIVE | `dwm-settings` (Super+Shift+S) 토글 확인 |
| **애플리케이션 런처** | 🟢 ACTIVE | 367개 데스크톱 인덱싱 완료 |
| **테스트 스위트** | 🟢 PASS | 접근성, 오디오, 네트워크, 컨트롤, 패널설정 원자성 등 통과 |

---

## 4. 즉시 확인 가능한 단축키 및 명령어

```bash
# 상태 확인
dwm-shell-mode status

# 순수 C Suckless 모드로 전환 (Status2D 바 + Dunst)
dwm-shell-mode suckless

# Quickshell Qt6/QML 모드로 복귀 (애니메이션 패널 + 위젯)
dwm-shell-mode quickshell

# 컨트롤 센터 토글 (GUI 오버레이)
dwm-controlcenter
```
