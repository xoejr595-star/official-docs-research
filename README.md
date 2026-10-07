# Official Docs Research — v0.1

**질문 하나를 입력하면 공식 문서를 검색·열람하고, 근거 링크가 있는 한국어 조사 결과를 파일로 남기는 자동화 MVP.**

사람이 반복하던 검색어 작성, 문서 선택, 본문 확인, 답변 정리와 저장을 한 번의 실행으로 연결한다. 사용자가 중간에 문서를 찾아 복사할 필요가 없는 것이 목표다. 결과의 정확성 확인과 사용 여부 판단은 사람에게 남아 있다.

현재는 최소 구현과 로컬 동작 검증을 마쳤지만, 개발 환경의 Codex 설정 폴더 접근 문제로 **실제 모델의 검색부터 저장까지 실행은 아직 검증하지 못했다.** 검증 상태는 [실험 기록](docs/experiments.md)에 남긴다. 완료된 조사 사례나 정확도 개선 수치를 주장하지 않는다.

## 첫 버전의 범위

```text
기술 질문 + 공식 도메인
    → Research Agent 1개
        → Official Docs Search Skill 1개
        → 실제 웹 검색 / 문서 본문 열람
        → 한국어 답변 + 근거 + 한계
    → response.md + 실행 기록
```

- 에이전트: 검색어와 읽을 문서를 선택하고 답변한다. `agents/research.md`.
- 스킬: 공식 출처 선택과 본문 확인 절차를 재사용한다. `skills/official-docs-search/SKILL.md`. 검색 도구 자체와는 다르다.
- 실행 환경(harness): 모델과 도구 실행은 Codex CLI가 제공한다. `research.ps1`은 역할·스킬을 읽어 전달하고 결과·로그를 저장하는 작은 실행 래퍼다. 독자적인 에이전트 플랫폼을 구현했다고 주장하지 않는다.
- Sub-agent와 Reviewer는 아직 없다. 검증 결과에 따라 재조사하는 workflow도 아직 없다.

## 실행

필요 환경: PowerShell 7 이상, 웹 검색을 지원하는 Codex CLI와 로그인.
모델은 사용자의 Codex 설정을 따른다. 별도 라이브러리 설치나 별도 API 키는 요구하지 않지만 Codex 이용 권한과 사용량이 필요하다.

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

실행마다 `runs/<UTC시각-고유번호>/`에 다음을 저장한다.

| 파일 | 용도 |
| --- | --- |
| request.json / prompt.md | 실제 질문, 도메인, 전달된 역할·스킬 |
| response.md | 모델이 남긴 최종 응답. 정확성이 보장된 보고서가 아님 |
| events.jsonl / stderr.log | 도구 사용과 실행 오류 확인 |
| run.json | 실행 상태·시각. 응답을 받으면 needs_review, 실행 오류는 failed |

`runs/`는 Git에서 제외한다. 실행 기록의 JSON은 로그 형식일 뿐, 답변에 structured output을 적용한 것은 아니다.

## 첫 실험의 완료 기준

위 Python 질문을 실제 실행하고 다음을 확인한다.

1. 이벤트 기록에 실제 검색과 본문 열람 흔적이 있다.
2. 응답의 모든 근거 호스트가 지정 범위 안에 있다.
3. 링크를 열었을 때 관련 절이 실제로 주장을 뒷받침한다.
4. 문서를 수동으로 찾아 넣지 않아도 응답 파일이 생성된다.

응답 파일이 생긴 것만으로 조사 성공이라고 판단하지 않는다. 실패도 지우지 않고 기록한다.
동작 검증: `pwsh -File ./tests/smoke.ps1` (가짜 실행기로 저장·오류 처리만 검사, 실제 AI 품질 테스트 아님).

## 알려진 한계와 다음 변경

공식 도메인 제한, 본문 열람, 검색 횟수는 현재 **모델 지침**이다. 코드로 강제하거나 인용의 정확성을 자동 검증하지 않는다. 사용자 Codex의 추가 도구·설정도 완전히 격리하지 않는다. 셸 도구와 멀티에이전트는 실행 옵션으로 끄고 파일 작업은 읽기 전용으로 제한한다.

실제 실패를 관찰한 뒤 [개선 계획](docs/roadmap.md)에 따라 필요한 변경만 추가한다. 최초 버전부터 직접 API 서버, 벡터 DB, Docker, 다중 에이전트는 넣지 않는다. Codex 내부 서비스 호출과 나중에 직접 구현할 API 연동은 구분한다.

## 참고

- [Codex 비대화형 실행과 이벤트 기록](https://learn.chatgpt.com/docs/non-interactive-mode)
- [Codex 설정: 웹 검색과 도구 옵션](https://learn.chatgpt.com/docs/config-file/config-reference)
- [스킬 작성](https://learn.chatgpt.com/docs/build-skills)

스킬은 실행 스크립트가 직접 읽어 문맥에 포함한다. 전역 설치나 자동 발견에 의존하지 않는다. 향후 ClawPod 같은 다른 실행 환경에 옮길 때는 역할·스킬을 재사용하고 실행 연결부를 검증한다. 현재 ClawPod 연동은 구현하지 않았다.
