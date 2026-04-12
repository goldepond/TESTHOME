# Claude Code 스케줄 에이전트

자동으로 실행되는 원격 Claude Code 에이전트 목록.
Anthropic 클라우드에서 실행되며, 관리 페이지: https://claude.ai/code/scheduled

---

## 1. clean-code-refactor-daily

| 항목 | 값 |
|------|---|
| **이름** | clean-code-refactor-daily |
| **목적** | 전날 작성한 코드의 품질 점검 및 자동 개선 |
| **스케줄** | 매일 오전 7:00 KST (22:00 UTC) |
| **크론식** | `0 22 * * *` |
| **모델** | claude-sonnet-4-6 |
| **레포** | https://github.com/goldepond/MyHome |
| **환경** | claude-code-default |
| **상태** | 대기 중 (GitHub 연동 후 등록 예정) |

### 에이전트 프롬프트

```
당신은 Flutter/Dart 클린 코드 전문가입니다. goldepond/MyHome 프로젝트의 코드 품질을 점검하고 개선합니다.

작업 순서:
1. git log --since="24 hours ago" --name-only --pretty=format:"" 로 최근 24시간 변경된 .dart 파일 확인
2. 변경 파일이 없으면 "변경 사항 없음"으로 종료
3. 각 파일에 대해 다음을 점검하고 수정:
   - 불필요한 코드(미사용 import, 주석 처리된 코드, 빈 콜백) 삭제
   - 명명 규칙 개선 (축약 금지, boolean은 질문 형태)
   - 중첩 3단계 이상 → Early Return 가드 패턴으로 변환
   - const/final 누락 수정
   - async 작업 후 mounted 체크 누락 수정
   - 디자인 시스템 일관성 확보 (AirbnbColors, AppTypography, AppSpacing 사용)
   - 불필요한 Container 래핑 제거
4. dart analyze 실행하여 린트 에러 확인 및 수정
5. 변경사항을 커밋하고 PR 생성
```

### 선행 조건

- [ ] GitHub 연동 완료 (`/web-setup` 또는 GitHub App 설치)
- [ ] 스케줄 등록 완료 (RemoteTrigger API)

---

## 등록/관리 방법

### 새 스케줄 등록
```
/schedule create "스케줄 설명"
```

### 스케줄 목록 확인
```
/schedule list
```

### 스케줄 삭제
https://claude.ai/code/scheduled 에서 직접 삭제
