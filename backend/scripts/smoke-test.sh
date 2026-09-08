#!/usr/bin/env bash
#
# End-to-end smoke test against a RUNNING Waffir backend.
#
#   ./scripts/smoke-test.sh [base-url]
#
# Default base url: http://127.0.0.1:8000/api/v1
#
# It exercises, in order: health, locations, register + OTP verification,
# login, me, products (with a location filter), stores, price submission,
# voting, reporting, admin login, dashboard stats and logout.
#
# Only curl, sed and grep are required - no jq.

set -u

BASE_URL="${1:-http://127.0.0.1:8000/api/v1}"
USER_PHONE="0990000001"
USER_PASSWORD="Password123!"
ADMIN_USERNAME="admin@waffir.local"
ADMIN_PASSWORD="Password123!"
OTP_CODE="${OTP_TEST_CODE:-123456}"

PASS=0
FAIL=0

green() { printf '\033[32m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }

# json_value <json> <key> - first value of a top-level-ish string/number key.
json_value() {
  printf '%s' "$1" | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p" | head -1
}

json_number() {
  printf '%s' "$1" | sed -n "s/.*\"$2\":\([0-9.]*\).*/\1/p" | head -1
}

check() {
  local label="$1" body="$2"
  if printf '%s' "$body" | grep -q '"success":true'; then
    green "  PASS  $label"
    PASS=$((PASS + 1))
  else
    red "  FAIL  $label"
    printf '        %s\n' "$(printf '%s' "$body" | head -c 300)"
    FAIL=$((FAIL + 1))
  fi
}

req() {
  # req METHOD PATH [DATA] [TOKEN]
  local method="$1" path="$2" data="${3:-}" token="${4:-}"
  local args=(-s -X "$method" "$BASE_URL$path" -H 'Accept: application/json' -H 'Accept-Language: ar')

  if [ -n "$data" ]; then
    args+=(-H 'Content-Type: application/json' -d "$data")
  fi

  if [ -n "$token" ]; then
    args+=(-H "Authorization: Bearer $token")
  fi

  curl "${args[@]}"
}

echo "Waffir smoke test against $BASE_URL"
echo

# 1. health -------------------------------------------------------------------
BODY=$(req GET /health)
check "health" "$BODY"
if ! printf '%s' "$BODY" | grep -q '"database":"up"'; then
  red "  FAIL  database is not reachable"
  FAIL=$((FAIL + 1))
fi
if ! printf '%s' "$BODY" | grep -q '"database_driver":"pgsql"'; then
  red "  FAIL  the backend is not using PostgreSQL"
  FAIL=$((FAIL + 1))
else
  green "  PASS  database driver is pgsql"
  PASS=$((PASS + 1))
fi

# 2. public reference data ----------------------------------------------------
BODY=$(req GET /locations)
check "locations" "$BODY"
LOCATION_ID=$(json_value "$BODY" id)

BODY=$(req GET /sectors); check "sectors" "$BODY"
BODY=$(req GET /units);   check "units" "$BODY"
UNIT_ID=$(json_value "$BODY" id)
BODY=$(req GET /brands);  check "brands" "$BODY"
BRAND_ID=$(json_value "$BODY" id)

# 3. register + verify a brand new account ------------------------------------
NEW_PHONE="09$(date +%H%M%S)$(( RANDOM % 90 + 10 ))"
NEW_PHONE="${NEW_PHONE:0:10}"

BODY=$(req POST /auth/register "{\"name\":\"Smoke Test\",\"phone_number\":\"$NEW_PHONE\",\"password\":\"Password123!\",\"password_confirmation\":\"Password123!\",\"location_id\":\"$LOCATION_ID\"}")
check "register ($NEW_PHONE)" "$BODY"

if printf '%s' "$BODY" | grep -q '"access_token"'; then
  red "  FAIL  register must NOT issue tokens before verification"
  FAIL=$((FAIL + 1))
else
  green "  PASS  register issues no tokens before verification"
  PASS=$((PASS + 1))
fi

BODY=$(req POST /auth/verify-otp "{\"phone_number\":\"$NEW_PHONE\",\"code\":\"$OTP_CODE\"}")
check "verify-otp" "$BODY"
NEW_TOKEN=$(json_value "$BODY" access_token)

if [ -n "$NEW_TOKEN" ]; then
  green "  PASS  tokens issued after verification"
  PASS=$((PASS + 1))
else
  red "  FAIL  no tokens issued after verification"
  FAIL=$((FAIL + 1))
fi

# 4. login as the seeded development user -------------------------------------
BODY=$(req POST /auth/login "{\"phone_number\":\"$USER_PHONE\",\"password\":\"$USER_PASSWORD\"}")
check "login" "$BODY"
TOKEN=$(json_value "$BODY" access_token)
REFRESH=$(json_value "$BODY" refresh_token)

BODY=$(req GET /auth/me "" "$TOKEN")
check "me" "$BODY"

# 5. refresh rotation ---------------------------------------------------------
BODY=$(req POST /auth/refresh "{\"refresh_token\":\"$REFRESH\"}")
check "refresh" "$BODY"
TOKEN=$(json_value "$BODY" access_token)
NEW_REFRESH=$(json_value "$BODY" refresh_token)

BODY=$(req POST /auth/refresh "{\"refresh_token\":\"$REFRESH\"}")
if printf '%s' "$BODY" | grep -q '"success":false'; then
  green "  PASS  old refresh token is rejected after rotation"
  PASS=$((PASS + 1))
else
  red "  FAIL  old refresh token still works after rotation"
  FAIL=$((FAIL + 1))
fi
REFRESH="$NEW_REFRESH"

# 6. catalogue ----------------------------------------------------------------
BODY=$(req GET "/products?per_page=5")
check "products" "$BODY"
PRODUCT_ID=$(json_value "$BODY" id)

BODY=$(req GET "/products?per_page=5&location_id=$LOCATION_ID")
check "products (location filtered)" "$BODY"

BODY=$(req GET "/products/$PRODUCT_ID")
check "product detail" "$BODY"

BODY=$(req GET "/products/$PRODUCT_ID/prices")
check "product prices" "$BODY"

BODY=$(req GET /official-prices)
check "official prices" "$BODY"
OFFICIAL_ID=$(json_value "$BODY" id)

BODY=$(req GET "/official-prices/$OFFICIAL_ID/history")
check "official price history" "$BODY"

BODY=$(req GET "/stores?per_page=5")
check "stores" "$BODY"
STORE_ID=$(json_value "$BODY" id)

# 7. authenticated writes -----------------------------------------------------
BODY=$(req POST /prices "{\"product_id\":\"$PRODUCT_ID\",\"store_id\":\"$STORE_ID\",\"unit_id\":\"$UNIT_ID\",\"brand_id\":\"$BRAND_ID\",\"amount\":1,\"price\":12345}" "$TOKEN")
check "submit price" "$BODY"
PRICE_ID=$(json_value "$BODY" id)

# The submitting user may not rate their own price, so vote with the account
# registered at the start of this run.
BODY=$(req POST "/prices/$PRICE_ID/vote" '{"is_up":true}' "$NEW_TOKEN")
check "vote on price" "$BODY"

BODY=$(req POST "/prices/$PRICE_ID/vote" '{"is_up":false}' "$NEW_TOKEN")
check "change vote" "$BODY"

BODY=$(req POST "/prices/$PRICE_ID/vote" '{"is_up":true}' "$TOKEN")
if printf '%s' "$BODY" | grep -q '"success":false'; then
  green "  PASS  self-vote is rejected"
  PASS=$((PASS + 1))
else
  red "  FAIL  self-vote was accepted"
  FAIL=$((FAIL + 1))
fi

# The report type is one of the three Arabic literals the database CHECK
# constraint allows. It is written with \u escapes so the request body survives
# shells whose locale would otherwise mangle the UTF-8 argument.
REPORT_TYPE_OVERPRICED='\u0633\u0639\u0631 \u0645\u0628\u0627\u0644\u063a \u0641\u064a\u0647'

BODY=$(req POST /reports "{\"price_id\":\"$PRICE_ID\",\"type\":\"$REPORT_TYPE_OVERPRICED\"}" "$NEW_TOKEN")
check "submit report" "$BODY"

BODY=$(req POST /stores "{\"location_id\":\"$LOCATION_ID\",\"name\":\"Smoke Test Store\",\"address\":\"Smoke Test Address\"}" "$TOKEN")
check "suggest store" "$BODY"
if printf '%s' "$BODY" | grep -q '"is_verified":false'; then
  green "  PASS  user-submitted store starts unverified"
  PASS=$((PASS + 1))
else
  red "  FAIL  user-submitted store is not unverified"
  FAIL=$((FAIL + 1))
fi

BODY=$(req GET /notifications "" "$TOKEN")
check "notifications" "$BODY"

# 8. authorisation boundary ---------------------------------------------------
BODY=$(req GET /admin/dashboard-stats "" "$TOKEN")
if printf '%s' "$BODY" | grep -q '"success":false'; then
  green "  PASS  normal user cannot reach admin endpoints"
  PASS=$((PASS + 1))
else
  red "  FAIL  normal user reached an admin endpoint"
  FAIL=$((FAIL + 1))
fi

# 9. admin --------------------------------------------------------------------
BODY=$(req POST /auth/admin/login "{\"username\":\"$ADMIN_USERNAME\",\"password\":\"$ADMIN_PASSWORD\"}")
check "admin login" "$BODY"
ADMIN_TOKEN=$(json_value "$BODY" access_token)

BODY=$(req POST /auth/admin/login "{\"username\":\"$USER_PHONE\",\"password\":\"$USER_PASSWORD\"}")
if printf '%s' "$BODY" | grep -q '"success":false'; then
  green "  PASS  normal user cannot use the admin login"
  PASS=$((PASS + 1))
else
  red "  FAIL  normal user logged in through the admin endpoint"
  FAIL=$((FAIL + 1))
fi

BODY=$(req GET /admin/dashboard-stats "" "$ADMIN_TOKEN")
check "dashboard stats" "$BODY"

BODY=$(req GET /admin/recent-activity "" "$ADMIN_TOKEN")
check "recent activity" "$BODY"

BODY=$(req GET "/admin/users?per_page=5" "" "$ADMIN_TOKEN")
check "admin users list" "$BODY"

BODY=$(req GET "/prices?per_page=5" "" "$ADMIN_TOKEN")
check "admin price review" "$BODY"

BODY=$(req GET "/reports?per_page=5" "" "$ADMIN_TOKEN")
check "admin reports" "$BODY"

BODY=$(req DELETE "/prices/$PRICE_ID" "" "$ADMIN_TOKEN")
check "admin deletes the test price" "$BODY"

# 10. logout ------------------------------------------------------------------
BODY=$(req POST /auth/logout "" "$TOKEN")
check "logout" "$BODY"

BODY=$(req GET /auth/me "" "$TOKEN")
if printf '%s' "$BODY" | grep -q '"success":false'; then
  green "  PASS  access token is dead after logout"
  PASS=$((PASS + 1))
else
  red "  FAIL  access token still works after logout"
  FAIL=$((FAIL + 1))
fi

echo
echo "-------------------------------------"
echo "passed: $PASS   failed: $FAIL"
echo "-------------------------------------"

[ "$FAIL" -eq 0 ]
