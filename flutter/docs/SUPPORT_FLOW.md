# Support tickets migration contract

This flow was inspected against `app/src/main/java/pynith/apps/nextel/views/us/SupportActivity.kt`, its `activity_support.xml`, and the existing Flutter `NextelApi` envelope client. The UI/API port lives in `features/support` and remains unverified on a device because the Flutter/Android toolchain is unavailable here.

## API contract

All requests use the configured `/api/v1/` client and `Authorization: Bearer <token>`; response data is read from the existing `{success, message, data}` envelope.

| Operation | Request | Consumed response fields |
|---|---|---|
| List tickets | `GET support-tickets` | `data.user.{name,email}`, `data.tickets[]` |
| Create ticket | `POST support-tickets` with `subject`, `category`, `message` | `data.user`, `data.ticket.id` |
| Open conversation | `GET support-tickets/{id}` | `data.ticket`, `data.messages[]` |
| Reply | `POST support-tickets/{id}/messages` with `message` | On success reloads the conversation. |

Ticket IDs are URL-component encoded before being placed in a path. Category keys remain `general`, `account`, `payments`, and `technical`.

## Session and validation behavior

- Dashboard passes the current secure bearer token in the in-memory GoRouter extra. A suspended-account route may instead pass its short-lived `support_token`; if no route token is present, Support reads the current `SessionStore` token.
- On the first `401`, if the secure store contains a different current token, Support retries the same operation once with that token. A subsequent `401` clears the local API/WebView session and routes to Login, matching the old activity's token-refresh fallback while avoiding plaintext persistence.
- Opening tickets requires a trimmed subject of 4–160 characters and a message of 5–5000 characters. Replies require a non-empty trimmed body of at most 5000 characters. Field-level Laravel errors are displayed when available.
- The ticket list, empty/loading/retry states, account summary, conversation bubbles, back-to-ticket-list behavior, and reply flow correspond to the existing Android screen. Android double-back behavior remains owned by the Dashboard.

No backend responses are mocked in production code. Confirm the deployed server's ticket/status/message fields and verify the full flow on-device before marking this phase complete.
