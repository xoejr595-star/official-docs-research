# Official Docs Research — v0.1

기술 질문을 받아 공식 문서를 조사하고 한국어 답변과 출처를 저장하는 도구.

사람이 반복하던 검색어 작성, 문서 선택, 본문 확인, 답변 정리와 저장을 한 번의 실행으로 연결한다. 사용자가 중간에 문서를 찾아 복사할 필요가 없는 것이 목표다. 결과의 정확성 확인과 사용 여부 판단은 사람에게 남아 있다.

## 구성

```text
기술 질문 + 공식 도메인 → 조사 → 한국어 답변·출처 저장
```

- 에이전트: Official Docs Search Skill의 절차에 따라 검색어와 읽을 문서를 선택하고 답변한다. `agents/research.md`.
- 스킬: 조사에 사용하는 지침으로, 공식 출처 선택과 본문 확인 절차를 담는다. `skills/official-docs-search/SKILL.md`.
- 실행 스크립트: `research.ps1`이 역할·스킬과 질문을 Codex CLI에 전달하고 응답과 로그를 저장한다. 모델과 웹 도구 실행은 Codex CLI가 담당한다.

## 설치와 실행

필요 환경: PowerShell 7 이상, 웹 검색을 지원하는 Codex CLI와 로그인.
모델은 사용자의 Codex 설정을 따른다. 별도 라이브러리 설치나 별도 API 키는 요구하지 않지만 Codex 이용 권한과 사용량이 필요하다.

1. [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)과 [Codex CLI](https://developers.openai.com/codex/cli)를 설치한다.
2. `research.ps1`이 있는 폴더에서 PowerShell 7을 연다. 아래 명령은 그 폴더에서 실행한다.
3. Codex에 로그인하고 질문을 실행한다.

```powershell
codex login
pwsh -File ./research.ps1 -Question 'Python asyncio.TaskGroup과 gather의 예외 처리 차이는?'
```

기본 범위는 Python 공식 문서 `docs.python.org`다. 다른 기술은 해당 공식 호스트를 지정한다. 여러 도메인은 PowerShell 안에서 배열로 전달한다.

```powershell
./research.ps1 -Question 'Node.js fetch의 사용 조건을 설명해줘' -Domains @('nodejs.org')
./research.ps1 -Question 'Python과 Node.js의 비동기 실행 비교' -Domains @('docs.python.org', 'nodejs.org') -DryRun
```

`-DryRun`은 전달할 지침과 질문만 출력한다. 모델·검색·파일 저장은 실행하지 않는다.
질문과 검색어는 모델·검색 서비스로 전송되므로 실제 실행에는 공유 가능한 질문을 사용한다.

실행마다 `runs/<날짜-시간_질문제목_고유번호>/`에 다음을 저장한다. 날짜·시간은 실행 환경의 현지 시각이며, 질문 앞부분을 최대 48자로 줄이고 파일명에 쓸 수 없는 문자를 정리해 제목으로 사용한다. 예: `20261007-105857_Python-TaskGroup과-gather-예외처리_a5a92e30`. `run.json`의 실행 ID와 기록 시각은 기존처럼 UTC를 사용한다.

| 파일 | 용도 |
| --- | --- |
| request.json / prompt.md | 실제 질문, 도메인, 전달된 역할·스킬 |
| response.md | 한국어 답변, 근거 링크, 확인하지 못한 사항 |
| events.jsonl / stderr.log | 도구 사용과 실행 오류 확인 |
| run.json | 실행 상태·시각. 응답을 받으면 needs_review, 실행 오류는 failed |

`runs/`는 Git에서 제외한다. 저장된 답변의 근거는 사용자가 원문과 대조해 확인한다.
Codex를 찾지 못한 경우에는 `run.json`에 오류가 기록된다. CLI가 시작되기 전에 실패하면 응답과 CLI 로그 파일은 생성되지 않는다.

## 테스트

저장과 오류 처리 테스트:

```powershell
pwsh -File ./tests/smoke.ps1
```

이 테스트는 가짜 CLI를 사용하며 모델과 검색 서비스를 호출하지 않는다.
실제 조사 결과는 다음 항목으로 확인한다.

1. 이벤트 기록에 실제 검색과 본문 열람 흔적이 있다.
2. 응답의 모든 근거 호스트가 지정 범위 안에 있다.
3. 링크를 열었을 때 관련 절이 실제로 주장을 뒷받침한다.
4. 문서를 수동으로 찾아 넣지 않아도 응답 파일이 생성된다.

실행 결과와 오류는 [실험 기록](docs/experiments.md)에 정리한다.

## 조사 결과 예시

- [Slack 업무 알림에 필요한 권한](docs/examples/slack-posting-permissions.md)
- [Slack 업무 알림의 성공 판단 기준](docs/examples/slack-posting-verification.md)
- [TaskGroup과 gather의 예외 처리 비교](docs/examples/taskgroup-vs-gather.md)
- [문서 접근 실패 후 대체 문서 조사](docs/examples/taskgroup-alternative-document.md)

실제 저장된 답변에 질문과 검토 범위를 덧붙인 예시다. 핵심 설명은 원문과 대조했지만, 본문 열람 성공을 로그만으로 확정할 수 없는 한계가 있다. 잘 동작한 점과 남은 개선사항은 [현재 평가](docs/current-results.md)에 정리했다.

## 참고

- [Codex 비대화형 실행과 이벤트 기록](https://learn.chatgpt.com/docs/non-interactive-mode)
- [Codex 설정: 웹 검색과 도구 옵션](https://learn.chatgpt.com/docs/config-file/config-reference)
- [스킬 작성](https://learn.chatgpt.com/docs/build-skills)

스킬은 실행 스크립트가 파일을 읽어 전달하므로 별도 설치가 필요하지 않다.
