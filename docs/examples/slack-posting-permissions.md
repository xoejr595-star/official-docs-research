# Slack 공개 채널 알림 자동화의 권한 조사

## 업무 상황과 질문

고객이 지정한 공개 채널에 업무 알림을 보내는 봇을 구현하기 전에 필요한 권한을 조사한 사례다. Slack에 연결하거나 메시지를 보내는 기능을 구현한 것은 아니다.

고객의 Slack 공개 채널에 봇이 chat.postMessage로 메시지를 보내는 자동화를 설계한다. 봇이 이미 참여한 채널과 참여하지 않은 채널을 구분해 필요한 OAuth scope, 토큰 종류, 채널 접근 조건을 설명하고 최소 권한 구성을 제안해줘. 실제 메시지 전송은 하지 않는다.

## 실행과 검토 범위

- 실행일: 2026-10-08
- 실행 ID: `20261007T165302388Z-caef2027`
- 허용 도메인: docs.slack.dev
- 실행 상태: needs_review

검증자가 chat.postMessage, chat:write, chat:write.public, conversations.join과 토큰 문서를 별도로 확인했다. 참여 채널은 chat:write, 미참여 공개 채널은 chat:write와 chat:write.public이 필요하다는 핵심 설명을 대조했다. 초대 기반 구성을 권하는 부분은 설계 제안이다. 실제 고객 환경의 설치·관리자 정책이나 메시지 전송은 검증하지 않았다.

검색 이벤트는 남았지만 일부 웹 작업은 other로 기록돼 조사 실행의 본문 열람 성공을 로그만으로 확정할 수 없다. 아래 저장된 응답은 수정하지 않았다.

[검증 기록](../experiments.md)

## 저장된 응답

## 핵심 답변

고객 워크스페이스에 설치된 Slack 앱의 **봇 토큰(`xoxb-`)**을 사용하는 구성이 적절하다. 봇 토큰은 특정 사용자와 무관하게 설치된 앱의 봇을 대표하며, 필요한 scope만 개별 부여할 수 있다. 사용자 대신 게시할 필요가 없으므로 user token(`xoxp-`)은 불필요하다. [Tokens — Bot tokens](https://docs.slack.dev/authentication/tokens/)

- **봇이 이미 참여한 공개 채널**
  - Bot Token Scope는 **`chat:write`만** 필요하다.
  - 채널 ID를 `channel`에 전달해 `chat.postMessage`를 호출한다.
  - `chat.postMessage`는 bot token과 user token 모두 `chat:write`를 지원하지만, 일반적인 앱 메시지는 봇 토큰이 최소 권한 설계에 적합하다. [`chat.postMessage` — Facts](https://docs.slack.dev/reference/methods/chat.postMessage/)

- **봇이 참여하지 않은 공개 채널**
  - 가입하지 않은 상태로 바로 게시하려면 봇 토큰에 **`chat:write`와 `chat:write.public`**이 모두 필요하다.
  - `chat:write.public`은 앱이 구성원이 아닌 공개 채널에 메시지를 보내게 하며, 단독으로 사용할 수 없고 `chat:write`도 함께 요구한다. [`chat:write.public` — Usage info](https://docs.slack.dev/reference/scopes/chat.write.public/)
  - 이 권한은 특정 채널 하나가 아니라 **워크스페이스의 모든 공개 채널에 게시할 능력**을 부여한다. [`chat.postMessage` — Channel membership](https://docs.slack.dev/reference/methods/chat.postMessage/)

- **먼저 가입한 뒤 게시하는 대안**
  - 봇 토큰에 **`channels:join`과 `chat:write`**를 부여하고 `conversations.join`으로 공개 채널에 가입한 뒤 게시할 수 있다. `conversations.join`의 bot token scope는 `channels:join`이다. [`conversations.join` — Facts](https://docs.slack.dev/reference/methods/conversations.join/)
  - 또는 고객이 `/invite @앱`으로 봇을 필요한 채널에 직접 초대하면 `channels:join`도 필요하지 않다. [Creating an app — Requesting scopes](https://docs.slack.dev/app-management/quickstart-app-settings/)

### 최소 권한 제안

가장 엄격한 최소 권한 구성은 다음과 같다.

1. 고객이 자동화 대상 공개 채널에 봇을 명시적으로 초대한다.
2. 봇 토큰에는 **`chat:write`만** 부여한다.
3. 자동화 설정에 승인된 채널 ID를 저장하고 그 채널에만 게시한다.
4. 프로그램이 Slack에서 가입 채널을 직접 조회해야 할 때만 **`channels:read`**를 추가한다. `users.conversations`는 호출 주체가 참여한 채널을 나열할 수 있고, 공개 채널 조회에는 `channels:read`가 사용된다. [`users.conversations` — Usage info](https://docs.slack.dev/reference/methods/users.conversations/), [`channels:read` scope](https://docs.slack.dev/reference/scopes/channels.read/)

고객 요구가 “초대 절차 없이 임의의 공개 채널로 전송”이라면 차선으로 **`chat:write` + `chat:write.public`**을 사용한다. 대상 채널 ID를 이미 설정값으로 받는다면 `channels:read`는 필요 없다.

## 근거

- [`chat.postMessage` method](https://docs.slack.dev/reference/methods/chat.postMessage/)
  - **Facts**: bot token과 user token에 `chat:write`가 필요하다.
  - **Post to a public channel**: 공개 채널의 이름 또는 ID를 `channel`에 전달한다.
  - **Channel membership**: 새 앱은 기본적으로 모든 공개 채널에 게시할 수 없으며, 비가입 공개 채널 게시에는 `chat:write.public`이 필요하다.
  - **Errors**: 앱이 필요한 대화에 참여하지 않은 경우 `no_permission` 등이 발생할 수 있으며, 읽기 전용 채널이나 관리자 정책도 게시를 막을 수 있다.

- [`chat:write` scope](https://docs.slack.dev/reference/scopes/chat.write/)
  - **Facts / Usage info**: 앱 명의 메시지 전송 권한이며 bot·user token을 지원하고 `chat.postMessage`와 호환된다.

- [`chat:write.public` scope](https://docs.slack.dev/reference/scopes/chat.write.public/)
  - **Facts / Usage info**: 앱이 구성원이 아닌 채널에 게시하는 bot용 권한이며 `chat:write`를 함께 요구한다.

- [`Tokens`](https://docs.slack.dev/authentication/tokens/)
  - **Bot tokens / User tokens**: bot token은 설치된 앱의 봇을 대표하고 `xoxb-`로 시작한다. user token은 사용자를 대표하여 그 사용자 대신 동작한다.

- [`conversations.join` method](https://docs.slack.dev/reference/methods/conversations.join/)
  - **Facts / Usage info**: bot token의 `channels:join`으로 기존 공개 채널에 가입할 수 있다.

- [`users.conversations` method](https://docs.slack.dev/reference/methods/users.conversations/)
  - **Usage info**: 토큰에 연결된 앱 또는 봇이 참여한 채널 목록을 반환하여 가입 여부 구분에 사용할 수 있다.

## 한계

- 문서는 2026년 10월 8일 열람한 현재 Slack 개발자 문서이며 별도의 제품 버전 번호는 표시되지 않았다.
- `chat:write.public`이 있어도 보관된 채널, 읽기 전용 채널, 관리자 제한 등 워크스페이스 정책 때문에 전송이 거부될 수 있다.
- “`chat:write`만 사용하는 초대 기반 구성이 가장 엄격한 최소 권한”이라는 평가는 공식 scope의 효력을 비교한 설계상 판단이다.
- 실제 OAuth 설치, 채널 조회 또는 메시지 전송은 수행하지 않았다.