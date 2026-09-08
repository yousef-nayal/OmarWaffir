# Backend Open Questions

These items cannot be resolved from the current Flutter code and supplied API documentation without inventing backend behavior.

## Authentication and sessions

1. Does registration issue usable access/refresh tokens before OTP verification?
2. If OTP verification issues tokens, does `POST /auth/verify-otp` return an AuthResult or only a success message?
3. What is the exact response shape for `/auth/refresh`: root tokens or `{success,data}`?
4. Does refresh rotate the refresh token every time? What happens to the previous token?
5. What are access-token and refresh-token expirations?
6. Does logout revoke the refresh token server-side, or only invalidate the access token?
7. Are verify/resend OTP endpoints public, or do they accept a temporary registration token?
8. What are OTP expiry, retry limits, resend rate limits, and lockout rules?
9. Is reset-password really `PUT`, and is the OTP code the only reset credential?
10. Are admin login credentials accepted as phone, email, or both? The documentation says both; the current form is phone-oriented.
11. What exact password policy applies on the backend? The UI only enforces minimum lengths locally.

## Roles and authorization

12. What exactly do role values `0`, `1`, and `2` mean?
13. Can role `2` be assigned through the role endpoint? Current helper sends only `0` or `1`.
14. Which product/store/catalog endpoints are public, authenticated-user, admin, or super-admin only?
15. Is ordinary user store submission allowed, and is it stored as pending?
16. Does every admin endpoint independently enforce authorization and return 403 for insufficient role?
17. Does `/auth/login` ever return an admin role, or must admins use `/auth/admin/login`?
18. What is the canonical user status model for block/unblock: `is_active`, a separate table, or another mechanism?
19. Does `GET /admin/users?status=` support `active` and `blocked` values? This is implemented but absent from docs.

## Response and errors

20. Is `{success,message,data,pagination}` mandatory for every endpoint?
21. Which endpoints return `data: null` versus an empty object/list for successful actions?
22. Are 400, 409, and 429 returned with the same `message/errors` envelope?
23. Are validation errors always arrays of strings keyed by request field?
24. Are IDs JSON integers, strings, or both?
25. Are counters guaranteed JSON integers, or may they be numeric strings?
26. Are monetary values JSON numbers, decimal strings, or both?
27. Are malformed/missing required response fields possible, or should Laravel treat them as contract violations?

## Locations and relationships

28. Is `district` the canonical JSON key, with `area` only a legacy client alias?
29. Must Store responses include `location_id` and `sector_id` in addition to display names?
30. Is `landmark` a real Location field? Current create/update services do not send it.
31. Are area names unique globally, or only unique within a sector?
32. What is the delete behavior for a Location or Sector referenced by users/stores?
33. Are `brand_id` and `unit_id` mandatory on every Price, and can `brand_id` be null?
34. Is there an explicit `user_id` relationship on Price and Report, even though current projections expose only display names?

## Prices, reports, and history

35. Does Price have a persisted `status`? The model/mock code uses it, while documentation says the real table does not.
36. Does the `/prices` list support a `status` filter? Current service does not transmit it.
37. Is vote submission one vote per user per price? Can a user change a vote?
38. What happens when a user votes twice concurrently?
39. Is `description` rejected for report types other than `معلومات غير صحيحة`, or silently ignored?
40. Are report type values exactly the three Arabic strings, including spelling and encoding?
41. Is official-price history stored in a separate table or as append-only official-price rows?
42. What ordering does history use?
43. Are official prices unique per product/unit/amount combination or another key?

## Pagination and search

44. What are maximum allowed `per_page` values and server defaults?
45. Are `search` and `category` exact, partial, case-insensitive, or localized matches?
46. Does Store `sector` filter by name, ID, or another value?
47. Does any endpoint support sorting even though Flutter sends no sort parameters?
48. Are list responses always paginated, including catalog and detail-price/history lists?

## Files and dates

49. Is there a real file-upload endpoint? If yes, what field name, MIME types, maximum size, and authentication apply?
50. Should receipt upload be part of `POST /prices` or a separate endpoint?
51. Which timezone and ISO-8601 precision must all timestamps use?
52. Are `submitted_at`, `reported_at`, `updated_at`, `created_at`, and `changed_at` always present?

## Database lifecycle and operations

53. Are deletes hard deletes or soft deletes?
54. What are foreign-key cascade/restrict rules?
55. Which fields are unique, especially phone, product names, unit names, brand names, and location names?
56. What decimal precision and scale are required for prices and amounts?
57. How are dashboard counters and growth percentages calculated?
58. Are activity records persisted or generated from other tables?
59. What rate limits apply to login, OTP, refresh, votes, reports, and list endpoints?
60. What CORS origins, HTTPS requirements, and production hostnames should be used?
