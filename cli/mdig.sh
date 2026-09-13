#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Description: Multi-dig: Check A records (via IPv4) and AAAA records (via IPv6) at once.
# Usage: mdig [domain]
# Example: mdig 'is1-ssl.mzstatic.com'

# 1. Check arguments
DOMAIN="${1:-}"
if [[ -z "$DOMAIN" ]]; then
  echo "mdig: Multi-dig: Check DNS records on different DNS servers at once." >&2
  echo "Usage: mdig [domain]" >&2
  echo "       mdig 'is1-ssl.mzstatic.com'" >&2
  exit 1
fi

# 2. Check required tools
for cmd in dig; do
  command -v "$cmd" &>/dev/null || {
    echo "Error: $cmd is not installed" >&2
    exit 1
  }
done

# 3. Query DNS servers in parallel
DNS_SERVERS=(
  "Google|8.8.8.8|2001:4860:4860::8888"
  "Cloudflare|1.1.1.1|2606:4700:4700::1111"
  "Hinet|168.95.192.1|2001:b000:168::1"
  "Hinet|168.95.1.1|2001:b000:168::2"
  "System|"
)

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

for i in "${!DNS_SERVERS[@]}"; do
  (
    IFS='|' read -ra ADDR <<<"${DNS_SERVERS[$i]}"
    SERVER_NAME="${ADDR[0]}"
    IPV4_IP="${ADDR[1]:-}"
    IPV6_IP="${ADDR[2]:-}"

    # Run A (via IPv4) and AAAA (via IPv6) queries in parallel
    if [[ "$SERVER_NAME" == "System" ]]; then
      dig "$DOMAIN" A +noclass +nottl +noall +answer +stats +time=2 +tries=1 2>/dev/null >"$TEMP_DIR/a_$i" &
      dig "$DOMAIN" AAAA +noclass +nottl +noall +answer +stats +time=2 +tries=1 2>/dev/null >"$TEMP_DIR/aaaa_$i" &
    else
      dig "@$IPV4_IP" "$DOMAIN" A +noclass +nottl +noall +answer +stats +time=2 +tries=1 2>/dev/null >"$TEMP_DIR/a_$i" &
      dig "@$IPV6_IP" "$DOMAIN" AAAA +noclass +nottl +noall +answer +stats +time=2 +tries=1 2>/dev/null >"$TEMP_DIR/aaaa_$i" &
    fi
    wait || true

    OUTPUT_A=$(<"$TEMP_DIR/a_$i")
    OUTPUT_AAAA=$(<"$TEMP_DIR/aaaa_$i")

    # Extract A records (sorted) and time
    A_IPS=$(printf '%s' "$OUTPUT_A" | awk '$2 == "A" {print $3}' | sort | paste -sd "," -)
    A_TIME=$(printf '%s' "$OUTPUT_A" | awk '/Query time/ {print $4}')

    # Extract AAAA records (sorted) and time
    AAAA_IPS=$(printf '%s' "$OUTPUT_AAAA" | awk '$2 == "AAAA" {print $3}' | sort | paste -sd "," -)
    AAAA_TIME=$(printf '%s' "$OUTPUT_AAAA" | awk '/Query time/ {print $4}')

    # Build A grouping key
    if [[ -z "$OUTPUT_A" ]]; then
      A_KEY="[A timeout]"
    elif [[ -z "$A_IPS" ]]; then
      A_KEY="[no A record]"
    else
      A_KEY="${A_IPS}"
    fi

    # Build AAAA grouping key
    if [[ -z "$OUTPUT_AAAA" ]]; then
      AAAA_KEY="[AAAA timeout]"
    elif [[ -z "$AAAA_IPS" ]]; then
      AAAA_KEY="[no AAAA record]"
    else
      AAAA_KEY="${AAAA_IPS}"
    fi

    # Write fields to separate files
    printf '%s' "$SERVER_NAME" >"$TEMP_DIR/${i}_name"
    printf '%s' "$IPV4_IP" >"$TEMP_DIR/${i}_ipv4"
    printf '%s' "$IPV6_IP" >"$TEMP_DIR/${i}_ipv6"
    printf '%s' "$A_KEY" >"$TEMP_DIR/${i}_a_key"
    printf '%s' "$AAAA_KEY" >"$TEMP_DIR/${i}_aaaa_key"
    printf '%s' "$A_TIME" >"$TEMP_DIR/${i}_a_time"
    printf '%s' "$AAAA_TIME" >"$TEMP_DIR/${i}_aaaa_time"
  ) &
done

wait

# 4. Group DNS records
declare -A a_groups
declare -a a_order

for i in "${!DNS_SERVERS[@]}"; do
  key=$(<"$TEMP_DIR/${i}_a_key")
  if [[ -z "${a_groups["$key"]:-}" ]]; then
    a_order+=("$key")
  fi
  a_groups["$key"]+="$i "
done

declare -A aaaa_groups
declare -a aaaa_order

for i in "${!DNS_SERVERS[@]}"; do
  key=$(<"$TEMP_DIR/${i}_aaaa_key")
  if [[ -z "${aaaa_groups["$key"]:-}" ]]; then
    aaaa_order+=("$key")
  fi
  aaaa_groups["$key"]+="$i "
done

# 5. Print DNS records
print_records() {
  local value="$1"
  if [[ "$value" == \[* ]]; then
    printf '%s\n' "$value"
  else
    IFS=',' read -ra ips <<<"$value"
    for ip in "${ips[@]}"; do
      printf '%s\n' "$ip"
    done
  fi
}

printf '── A Records ──\n'
for key in "${a_order[@]}"; do
  print_records "$key"
  for idx in ${a_groups["$key"]}; do
    name=$(<"$TEMP_DIR/${idx}_name")
    ipv4=$(<"$TEMP_DIR/${idx}_ipv4")
    a_time=$(<"$TEMP_DIR/${idx}_a_time")

    desc="$name"
    [[ -n "$ipv4" ]] && desc="$name ($ipv4)"

    if [[ -n "$a_time" ]]; then
      printf "  - %s [%s ms]\n" "$desc" "$a_time"
    else
      printf "  - %s\n" "$desc"
    fi
  done
  echo ""
done

printf '── AAAA Records ──\n'
for key in "${aaaa_order[@]}"; do
  print_records "$key"
  for idx in ${aaaa_groups["$key"]}; do
    name=$(<"$TEMP_DIR/${idx}_name")
    ipv6=$(<"$TEMP_DIR/${idx}_ipv6")
    aaaa_time=$(<"$TEMP_DIR/${idx}_aaaa_time")

    desc="$name"
    [[ -n "$ipv6" ]] && desc="$name ($ipv6)"

    if [[ -n "$aaaa_time" ]]; then
      printf "  - %s [%s ms]\n" "$desc" "$aaaa_time"
    else
      printf "  - %s\n" "$desc"
    fi
  done
  echo ""
done
