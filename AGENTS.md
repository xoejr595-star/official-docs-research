# 개발 가이드

## 수정 위치

- `research.ps1`: 입력 검증, Codex CLI 호출, 응답·로그 저장.
- `agents/research.md`: 조사 역할과 답변 작성 지침.
- `skills/official-docs-search/SKILL.md`: 공식 출처 검색과 본문 확인 절차.
- `tests/smoke.ps1`: 가짜 Codex CLI로 실행 스크립트의 저장·오류 처리 검증.

조사 지침을 바꿀 때는 해당 Markdown을 수정한다. 실행 스크립트가 두 파일을 읽으므로 같은 지침을 스크립트에 중복 작성하지 않는다.

## 실행 코드 수정 시

- PowerShell 7 이상을 기준으로 한다. 파일 경로는 실행 위치가 아닌 `$PSScriptRoot`를 기준으로 계산한다.
- 질문은 표준 입력으로 전달한다. 질문을 셸 명령 문자열에 이어 붙이거나 `Invoke-Expression`으로 실행하지 않는다.
- `-DryRun`은 프롬프트만 출력해야 한다. CLI 호출이나 실행 폴더 생성을 추가하지 않는다.
- 실행마다 별도 `runs/` 하위 폴더를 사용해 이전 결과를 덮어쓰지 않는다.
- CLI 오류나 빈 응답은 `failed`로 기록한다. 응답을 받았을 때의 `needs_review`는 내용 검증을 통과했다는 뜻이 아니다.
- `runs/`와 인증 파일은 Git 추적 대상에서 제외한다.

## 검증

실행 코드를 변경하면 저장소 루트에서 다음 명령을 실행한다.

```powershell
pwsh -NoProfile -File ./tests/smoke.ps1
git diff --check
```

스모크 테스트는 외부 서비스를 호출하지 않는다. 조사 지침을 수정한 경우에는 실제 질문으로 실행하고 검색·본문 열람 기록과 답변의 근거를 별도로 확인한다.
