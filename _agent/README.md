# Claude Code Agent 설정

이 폴더는 MyHome 프로젝트에서 운영 중인 **Claude Code 자동화 에이전트** 관련 문서입니다.
실제 Flutter 앱 코드와는 무관하며, 개발 보조 도구입니다.

---

## 구성 요소

### 1. 자동 권한 승인 (bypassPermissions)

위치: `.claude/settings.local.json`

```json
{
  "permissions": {
    "defaultMode": "bypassPermissions"
  }
}
```

모든 도구 실행(파일 읽기/쓰기, Bash 명령, 웹 검색 등)이 자동 승인됩니다.
git으로 커밋이 주기적으로 쌓이므로 되돌리기 가능합니다.

---

### 2. 슬래시 커맨드

위치: `.claude/commands/`

| 커맨드 | 파일 | 설명 |
|--------|------|------|
| `/code-review` | `code-review.md` | 변경된 .dart 파일 심층 리뷰 (10분 루프용) |
| `/review` | `review.md` | 프로젝트 전체 종합 검수 (수동 실행용) |

---

### 3. dart analyze + 코드 리뷰 자동 루프 (세션 내 임시)

세션 시작 후 아래 명령으로 활성화:

```
/loop 10m dart analyze를 d:/Project에서 실행하고 error/warning이 있으면 보고해줘. 없으면 "✅ 이상 없음"만 출력해줘.
```

```
/loop 10m /code-review
```

- 10분마다 자동 실행
- **세션 종료 시 자동 소멸** (디스크에 저장 안 됨)
- 7일 후 자동 만료

---

## 세션 재시작 방법

Claude Code 세션이 끊기면(VSCode 재시작, 컨텍스트 만료 등) 아래 순서로 복구합니다.

### 빠른 복구 (복붙용)

```
이전 세션 복구: bypassPermissions는 .claude/settings.local.json에 이미 적용됨. 루프만 재시작해줘.
```

그 다음 각각 입력:

```
/loop 10m dart analyze를 d:/Project에서 실행하고 error/warning이 있으면 보고해줘. 없으면 "✅ 이상 없음"만 출력해줘.
```

```
/loop 10m /code-review
```

### 단계별 설명

1. **bypassPermissions** — `.claude/settings.local.json`에 저장되어 있으므로 **자동 유지**. 별도 작업 불필요.

2. **`/review` 커맨드** — `.claude/commands/review.md`에 저장되어 있으므로 **자동 유지**. 별도 작업 불필요.

3. **루프** — 세션 메모리에만 존재하므로 **재실행 필요**:
   ```
   /loop 10m dart analyze를 d:/Project에서 실행하고 error/warning이 있으면 보고해줘. 없으면 "✅ 이상 없음"만 출력해줘.
   ```
   ```
   /loop 10m /code-review
   ```

4. **컨텍스트 요약 확인** — 세션이 길어지면 Claude가 자동으로 이전 대화를 요약합니다. 중요한 미해결 이슈는 아래 "현재 미해결 이슈" 섹션을 참고하세요.

---

## 현재 미해결 이슈 (2026-03-22 기준)

우선순위 순으로 정리:

| 우선순위 | 파일 | 이슈 |
|----------|------|------|
| 🔴 높음 | `firestore.rules` | `mlsProperties/{id}/visitRequests` 서브컬렉션 보안 규칙 누락 |
| 🔴 높음 | `lib/api_request/fcm_service.dart` | 로그아웃/탈퇴 시 `removeToken()` 미호출 |
| 🟡 중간 | `lib/api_request/google_sign_in_native.dart` | `reauthenticate()` timeout 없음, idToken null 체크 없음 |
| 🟡 중간 | `lib/screens/broker/mls_broker_dashboard_page.dart` | 방문 요청 버튼 중복 탭 방지 없음 |

---

## 파일 구조

```
d:\Project\
├── .claude/
│   ├── settings.json          # 팀 공유 설정 (git 추적)
│   ├── settings.local.json    # 개인 설정 (bypassPermissions 포함, git 미추적 권장)
│   └── commands/
│       ├── code-review.md     # /code-review 슬래시 커맨드 (루프용)
│       └── review.md          # /review 슬래시 커맨드 (종합 검수용)
└── _agent/
    └── README.md              # 이 파일
```

> `.claude/settings.local.json`은 개인 설정이므로 `.gitignore`에 추가하는 것을 권장합니다.
