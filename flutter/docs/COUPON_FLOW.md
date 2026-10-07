# Coupon verification migration contract

This phase was inspected against `CouponSearchActivity.kt`, `CouponVerification.kt`, `activity_coupon_search.xml`, `item_coupon_detail_row.xml`, and `coupon_strings.xml`. The Flutter implementation is in `features/coupon`; the feature remains unverified on-device because Flutter/Android tooling is unavailable in this environment.

## API and input contract

- The legacy feature calls the public `GET /api/v1/coupons/verify?code=...` endpoint without a bearer token. Flutter uses the same endpoint through `NextelApi.get` query parameters so the code is URL-encoded by the HTTP client.
- Trim the submitted code; reject an empty value and values shorter than three characters. The input limit is 100 characters and the keyboard hints uppercase/no-suggestions; the submitted value is otherwise preserved.
- On API failure, display the first `code` field error when provided, otherwise the shared Laravel error message or the legacy not-found fallback. No coupon data is fabricated.

## Result behavior

The result preserves the legacy validity card and details: code, type, status, price, region, special flag, used date, description, product/package or plan details, batch, issuer, and redeemer. Product precedence remains `package` → `additional_minute_plan` → `cloud_storage_plan`; missing nested product/person/batch cards remain hidden. `is_valid` drives the green/red result state, with `verification.message` used when present.

The model tolerates missing fields and converts the same scalar JSON values the old `JSONObject.stringish` model accepted. Verify valid/used coupons, field/server errors, nested product variants, dates, regions, and long codes against the deployed API before marking this phase complete.
