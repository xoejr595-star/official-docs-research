# 문서 접근 실패 후 TaskGroup 대체 문서 조사

## 실행 정보

- 실행일: 2026-10-07
- 실행 ID: `20261007T061215699Z-416f3a4d`
- 허용 도메인: docs.python.org
- 실행 상태: needs_review (응답 수신, 내용 검증 통과를 뜻하지 않음)

## 질문

Python asyncio.TaskGroup에서 자식 작업 하나가 ValueError로 실패하면 나머지 작업과 호출자에게 어떤 일이 일어나는가? 참고 문서 주소는 https://docs.python.org/3/library/asyncio-task-missing-verification.html 이다. 먼저 이 주소의 본문을 확인해줘.

## 검토 범위

테스트용으로 접근할 수 없는 주소를 질문에 넣었다. 접근 실패 메시지 이후 대체 검색과 답변 저장을 계속한 사례다.

핵심 설명은 검증 단계에서 공식 원문과 대조했다. 웹 작업의 일부가 other로 기록돼, 조사 에이전트의 본문 열람 성공을 이벤트 로그만으로 확정할 수는 없다. 아래는 저장된 응답을 수정 없이 옮긴 것이다. 응답의 본문 열람 보고와 검증자가 독립적으로 확인한 범위를 구분해서 읽어야 한다.

[검증 기록](../experiments.md) · [현재 평가](../current-results.md)

## 저장된 응답

## 핵심 답변

자식 작업 하나가 `ValueError`로 실패하면 다음 순서로 처리됩니다.

1. `ValueError`는 `CancelledError`가 아니므로 `TaskGroup`은 아직 끝나지 않은 나머지 자식 작업에 취소를 요청하고, 이들이 종료될 때까지 기다립니다. 이후에는 그룹에 새 작업을 추가할 수 없습니다. [Python 3.14 — Task groups](https://docs.python.org/3/library/asyncio-task.html#task-groups)
2. `async with` 본문이 아직 실행 중이라면 그 본문을 실행하는 부모 작업도 내부적으로 취소됩니다. 이때 발생하는 `CancelledError`는 본문의 `await`를 중단하지만, `async with` 바깥으로 그대로 전파되지는 않습니다. [Python 3.14 — Task groups](https://docs.python.org/3/library/asyncio-task.html#task-groups)
3. 모든 자식 작업의 종료 처리가 끝나면, `TaskGroup`은 자식들의 비취소 예외를 `ExceptionGroup`으로 묶어 호출자에게 발생시킵니다. 따라서 실패가 `ValueError` 하나뿐이어도 호출자가 기본적으로 받는 것은 원본 `ValueError` 자체가 아니라 그 예외를 포함한 `ExceptionGroup`입니다. 보통 `except* ValueError`로 처리합니다. [Python 3.14 — Task groups](https://docs.python.org/3/library/asyncio-task.html#task-groups)

## 근거

- **Coroutines and tasks — Python 3.14.8 documentation**
  - URL: https://docs.python.org/3/library/asyncio-task.html
  - 관련 절: **Task groups**
  - 요지:
    - 최초의 비취소 예외가 발생하면 나머지 작업을 취소한다.
    - 활성 상태인 `async with` 본문의 부모 작업도 취소하지만, 그 과정의 `CancelledError`는 컨텍스트 관리자 밖으로 전파되지 않는다.
    - 모든 작업이 끝나면 비취소 예외들을 `ExceptionGroup` 또는 `BaseExceptionGroup`으로 묶어 발생시킨다.
    - `TaskGroup`은 Python 3.11에서 추가되었다.

- **Coroutines and tasks — Python 3.14.8 documentation**
  - URL: https://docs.python.org/3/library/asyncio-task.html#task-cancellation
  - 관련 절: **Task cancellation**
  - 요지: 작업 취소 시 다음 실행 기회에 `asyncio.CancelledError`가 작업 내부에서 발생하며, 정리 후에는 일반적으로 이를 다시 전파해야 한다.

## 한계

- 먼저 요청된 `https://docs.python.org/3/library/asyncio-task-missing-verification.html`은 열람 도구로 본문에 접근할 수 없었습니다. 따라서 그 주소 자체의 내용이나 실제 존재 여부는 확인하지 못했습니다.
- 대신 동일한 허용 도메인의 실제 공식 문서인 Python **3.14.8** `asyncio-task.html` 본문을 열어 확인했습니다.
- “호출자가 `ExceptionGroup`을 받는다”는 설명은 문서의 예외 그룹화 규칙을 `ValueError` 한 건에 적용한 결론입니다. 다른 자식이 취소 처리 중 별도의 비취소 예외를 발생시키면 그 예외도 같은 그룹에 포함될 수 있습니다.