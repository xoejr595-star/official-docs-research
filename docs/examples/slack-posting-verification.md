# Slack 업무 알림의 성공 판단 기준 조사

## 업무 상황과 질문

고객 업무 알림의 완료 기준을 설계하기 위해 API 성공, 게시, 사용자 확인을 구분한 조사다. 실제 Slack 연동이나 메시지 전송 실험은 아니다.

Slack chat.postMessage를 이용한 고객 업무 알림 자동화에서 HTTP 상태 200만으로 전송 성공을 판단해도 되는가? 응답의 ok, error, channel, ts와 message 이벤트가 각각 무엇을 확인하는지 설명하고 API 요청 성공, 메시지 게시, 사용자의 읽음 여부를 구분해 검증 기준을 제안해줘. 실제 API 호출이나 메시지 전송은 하지 않는다.

## 실행과 검토 범위

- 실행일: 2026-10-08
- 실행 ID: `20261007T165403220Z-bef3f32d`
- 허용 도메인: docs.slack.dev
- 실행 상태: needs_review

검증자가 Web API의 Evaluating responses, chat.postMessage의 Response와 Errors, message 이벤트, Conversation 객체와 conversations.info 문서를 별도로 확인했다. ok, channel, ts의 의미와 message 이벤트가 특정 사용자의 읽음 증거가 아니라는 핵심 설명을 대조했다. 권장 검증 기준과 명시적 사용자 확인 제안은 설계상 판단이며 실제 고객 환경에서 검증하지 않았다.

### 검토 메모

- 타임아웃은 성공 응답을 받지 못했다는 뜻이다. 서버에서 메시지가 게시되지 않았다는 뜻으로 단정하면 안 된다.
- 응답을 받지 못하면 channel과 ts를 확보하지 못할 수 있다. 업무 알림 ID도 저장만 해서는 중복 전송을 방지하지 못한다. 대조와 재시도 정책을 별도로 구현해야 한다.
- 이벤트 수신 확인은 추가 구독과 권한이 필요한 선택적 검증이다. 게시 성공 판정에 이벤트 수신을 항상 필수로 두지는 않는다.
- last_read 비교는 조건부 추론이며, 읽기 지점이 지났다고 해당 내용을 실제로 읽고 이해했다고 증명하지는 않는다.

검색 이벤트는 남았지만 일부 웹 작업은 other로 기록돼 조사 실행의 본문 열람 성공을 로그만으로 확정할 수 없다. 아래 저장된 응답은 내용을 유지하고 Markdown 줄바꿈 형식만 정리했다.

[검증 기록](../experiments.md)

## 저장된 응답

## 핵심 답변

아니다. `HTTP 200`만으로 전송 성공을 판단하면 안 된다. Slack Web API는 HTTP 요청이 정상적으로 처리됐더라도 응답 본문에 `{"ok": false, "error": "..."}`를 반환할 수 있다. 따라서 최소 성공 조건은 **HTTP 응답 수신 + JSON 파싱 성공 + `ok == true`**여야 한다. `ok == false`이면 `error`를 실패 사유로 기록해야 한다. [`Evaluating responses`](https://docs.slack.dev/apis/web-api/#evaluating-responses)

각 값이 확인하는 범위는 다음과 같다.

| 값 | 확인할 수 있는 것 | 확인할 수 없는 것 |
|---|---|---|
| HTTP `200` | Slack Web API가 HTTP 수준의 응답을 반환함 | API 메서드 성공, 메시지 게시, 사용자 열람 |
| `ok` | 해당 Web API 메서드의 성공 또는 실패 | 사용자의 읽음 여부 |
| `error` | `ok:false`일 때의 기계 판독용 실패 코드. 예: `channel_not_found`, `too_many_attachments` | 성공 여부를 단독으로 증명하지 않음 |
| `channel` | 메시지가 게시된 실제 대화의 ID | 사용자가 그 대화를 열어봤는지 |
| `ts` | 게시된 메시지의 채널 내 고유 timestamp ID | 읽은 시각이나 수신 확인 |
| 응답의 `message` 객체 | Slack 서버가 파싱·정규화한 게시 메시지. 링크나 첨부 등이 요청값과 달라질 수 있음 | 사용자 화면 표시 또는 읽음 여부 |
| Events API의 `message` 이벤트 | 구독·권한 범위 안에서 해당 대화에 메시지가 나타났음을 비동기로 관찰 | 특정 사용자의 읽음 여부 |

`chat.postMessage`의 성공 예시는 `ok:true`, `channel`, `ts`, `message`를 함께 반환하며, 공식 문서는 `channel`을 게시 위치, `ts`를 메시지의 timestamp ID로 설명한다. [`chat.postMessage` — Response](https://docs.slack.dev/reference/methods/chat.postMessage/#response) 실패 응답은 같은 HTTP 교환에서도 `ok:false`와 `error`를 가질 수 있다. [`chat.postMessage` — Errors](https://docs.slack.dev/reference/methods/chat.postMessage/#errors)

`message` 이벤트의 `channel`은 메시지가 게시된 대화 ID이고 `ts`는 채널별 고유 timestamp다. 공개 채널·비공개 채널·DM·그룹 DM별 이벤트 구독과 권한이 다르며, 앱이 게시한 메시지는 `bot_message` 하위 유형일 수 있다. 따라서 이 이벤트는 별도의 비동기 게시 관찰이나 감사 로그에는 쓸 수 있지만 읽음 확인은 아니다. [`message` event](https://docs.slack.dev/reference/events/message/)

### 권장 검증 기준

1. **API 요청 성공**

   - 네트워크 오류·타임아웃이 없어야 한다.
   - HTTP 응답과 JSON 본문을 정상적으로 받아야 한다.
   - `ok:true`여야 한다.
   - `ok:false`라면 HTTP 200이어도 실패 처리하고 `error`를 저장한다.
   - `warning`이 있으면 성공과 별도로 기록한다. Slack은 `ok:true`와 경고를 함께 반환할 수 있다. [`Evaluating responses`](https://docs.slack.dev/apis/web-api/#evaluating-responses)

2. **메시지 게시 성공**

   - 기본 판정: `ok:true`이며 `channel`, `ts`, `message`가 존재하고, 반환된 `channel`이 의도한 대상과 일치하는지 확인한다.
   - 추적 키는 `(channel, ts)`로 저장한다. `ts`만 사용하면 채널 간 고유성이 보장되지 않는다.
   - 더 강한 감사가 필요하면 동일한 `(channel, ts)`의 `message` 이벤트를 비동기적으로 대조할 수 있다. 다만 이벤트 구독 누락·권한·전달 지연 때문에 이벤트 미수신만으로 게시 실패라고 단정해서는 안 된다.
   - 불확실한 타임아웃에서 무조건 재전송하면 중복 알림 위험이 있으므로 `(channel, ts)` 또는 애플리케이션의 업무 알림 ID를 기준으로 중복을 통제해야 한다.

3. **사용자의 읽음 여부**

   - `chat.postMessage` 응답과 `message` 이벤트로는 검증할 수 없다.
   - Conversation 객체의 `last_read`는 **API를 호출한 사용자**가 마지막으로 읽은 메시지의 timestamp일 뿐이다. 또한 문서상 일부 메서드·대화 유형에서만 제공될 수 있다. [`Conversation object — Other conversation-related attributes`](https://docs.slack.dev/reference/objects/conversation-object/#other-conversation-related-attributes)
   - 따라서 봇 토큰에서 보이는 `last_read`를 고객의 읽음으로 간주하면 안 된다.
   - 고객이 승인한 사용자 문맥에서 그 고객의 `last_read >= 게시 메시지 ts`를 얻을 수 있다면 “해당 사용자의 읽기 지점이 메시지를 지났다”는 보조 지표로 추론할 수 있다. 그러나 일반 채널의 여러 수신자 전체에 대한 개별 읽음 영수증으로 취급할 근거는 확인되지 않았다.
   - 확실한 업무 확인이 필요하면 버튼 클릭, 양식 제출, 스레드 답변 등 사용자의 명시적 acknowledgment를 별도 성공 기준으로 설계하는 것이 적절하다.

## 근거

- [Slack Web API](https://docs.slack.dev/apis/web-api/)\
  관련 절: **Evaluating responses**\
  모든 Web API 응답에는 최상위 `ok`가 있으며, 실패 시 `error`, 성공했지만 문제가 있으면 `warning`이 포함될 수 있다고 설명한다.

- [`chat.postMessage` method](https://docs.slack.dev/reference/methods/chat.postMessage/)\
  관련 절: **Response**, **Errors**\
  성공 응답의 `channel`, `ts`, 서버가 파싱한 `message` 객체와 실패 응답의 `ok:false`, `error` 형식을 제시한다.

- [`message` event](https://docs.slack.dev/reference/events/message/)\
  관련 절: **Usage info**, **Message events in the Events API**, **Message subtypes**\
  `channel`과 채널별 고유 `ts`의 의미, 대화 유형별 구독, 통합이 게시한 `bot_message` 하위 유형을 설명한다.

- [Conversation object](https://docs.slack.dev/reference/objects/conversation-object/)\
  관련 절: **Other conversation-related attributes**\
  `last_read`가 “호출한 사용자”가 해당 채널에서 마지막으로 읽은 메시지의 timestamp라고 정의한다.

- [`conversations.info` method](https://docs.slack.dev/reference/methods/conversations.info/)\
  관련 절: **Response**\
  1:1 DM 예시에서 `last_read`, `latest.ts`, `unread_count`를 보여주며, 일부 필드는 DM에만 포함된다고 명시한다.

## 한계

- 조사는 2026년 10월 8일 현재 `docs.slack.dev`의 영문 문서만 대상으로 했다. 각 페이지에 별도의 고정 제품 버전은 표시되지 않았다.
- 공식 문서에서 `chat.postMessage` 응답이나 `message` 이벤트를 사용자 읽음 영수증으로 정의한 근거는 확인되지 않았다.
- `last_read >= message.ts`에 의한 판정은 문서의 필드 정의에서 도출한 **추론**이며, 대상 사용자 문맥의 데이터에 접근할 수 있을 때만 성립한다. 모든 채널 구성원에 대한 공식적인 개별 읽음 확인 기능이라는 뜻은 아니다.
- 실제 API 호출이나 메시지 전송은 수행하지 않았다.