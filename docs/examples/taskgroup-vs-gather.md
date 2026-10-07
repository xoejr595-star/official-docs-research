# TaskGroup과 gather의 예외 처리 비교

## 실행 정보

- 실행일: 2026-10-07
- 실행 ID: `20261007T015857102Z-a5a92e30`
- 허용 도메인: docs.python.org
- 실행 상태: needs_review (응답 수신, 내용 검증 통과를 뜻하지 않음)

## 질문

Python asyncio.TaskGroup과 asyncio.gather는 자식 작업 하나가 예외로 실패했을 때 나머지 작업을 어떻게 처리하며, 예외를 호출자에게 어떻게 전달하는가?

## 검토 범위

질문만 입력해 조사와 답변 저장까지 진행한 사례다. 일부 기술적 주장에는 바로 뒤 근거 링크가 빠져 있다.

핵심 설명은 검증 단계에서 공식 원문과 대조했다. 웹 작업의 일부가 other로 기록돼, 조사 에이전트의 본문 열람 성공을 이벤트 로그만으로 확정할 수는 없다. 아래는 저장된 응답을 수정 없이 옮긴 것이다. 응답의 본문 열람 보고와 검증자가 독립적으로 확인한 범위를 구분해서 읽어야 한다.

[검증 기록](../experiments.md) · [현재 평가](../current-results.md)

## 저장된 응답

## 핵심 답변

- `asyncio.TaskGroup`: 자식 작업 하나가 `CancelledError` 이외의 예외로 실패하면 나머지 작업을 취소하고 모두 종료될 때까지 기다립니다. 이후 발생한 비취소 예외들을 `ExceptionGroup` 또는 `BaseExceptionGroup`으로 묶어 호출자에게 발생시킵니다. 단, `KeyboardInterrupt`와 `SystemExit`은 그룹으로 묶지 않고 원래 예외를 다시 발생시킵니다. [Python 문서 — Task groups](https://docs.python.org/3/library/asyncio-task.html#task-groups)
- `asyncio.gather(..., return_exceptions=False)`: 기본 설정에서는 처음 발생한 예외를 `gather()`를 기다리는 호출자에게 즉시 전달합니다. 다른 작업들은 취소하지 않으며 계속 실행됩니다. 예외 전달 후 이미 완료 상태가 된 `gather()`를 취소해도 남은 작업은 취소되지 않습니다. [Python 문서 — asyncio.gather](https://docs.python.org/3/library/asyncio-task.html#asyncio.gather)
- `asyncio.gather(..., return_exceptions=True)`: 예외를 호출자에게 발생시키지 않고 정상 반환값과 함께 결과 목록에 넣습니다. [Python 문서 — asyncio.gather](https://docs.python.org/3/library/asyncio-task.html#asyncio.gather)

따라서 실패 시 나머지 관련 작업까지 정리해야 한다면 `TaskGroup`이 더 강한 안전 보장을 제공합니다. 반면 `gather()`의 기본 동작은 첫 예외만 즉시 전달하고 다른 작업의 실행은 유지합니다.

## 근거

- **Coroutines and tasks — Python 3.14.8 documentation**
  - URL: https://docs.python.org/3/library/asyncio-task.html
  - **Task groups**: 첫 비취소 예외가 발생하면 나머지 작업을 취소하고 기다린 뒤, 비취소 예외들을 예외 그룹으로 발생시킨다고 명시합니다.
  - **Running tasks concurrently / `asyncio.gather`**: 기본값에서는 첫 예외를 즉시 전파하지만 다른 awaitable은 취소하지 않는다고 명시합니다. `return_exceptions=True`이면 예외를 결과 목록에 포함합니다.
  - 문서는 `TaskGroup`이 예외 발생 시 나머지 작업을 취소하지만 `gather()`는 그러지 않는다고 직접 비교합니다.

## 한계

- 확인한 `/3/` 문서는 현재 Python **3.14.8** 문서입니다. `TaskGroup`은 Python 3.11에 추가됐으며, 이전 Python에는 존재하지 않습니다.
- 위 비교는 자식 작업의 일반적인 비취소 예외를 중심으로 합니다. `gather()` 자체가 외부에서 취소되면 아직 끝나지 않은 작업들도 취소됩니다.
- “`TaskGroup`이 실패 작업의 형제 작업을 정리하는 데 더 적합하다”는 결론은 문서가 명시한 동작 차이에 따른 판단이며, 구체적인 API 선택은 작업 간 의존성에 따라 달라집니다.