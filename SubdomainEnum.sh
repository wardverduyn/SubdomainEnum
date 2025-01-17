#!/bin/bash

# Ensure a domain is given as an argument
if [ -z "$1" ]; then
  echo "ERROR: No domain provided!"
  exit 1
fi

DOMAIN="$1"
VERBOSE=false
BRUTEFORCE=false
if [ "$2" == "--verbose" ]; then
  VERBOSE=true
elif [ "$2" == "--bruteforce" ]; then
  BRUTEFORCE=true
elif [ "$3" == "--bruteforce" ]; then
  BRUTEFORCE=true
fi

# Colors
LOG_COLOR='\033[0;32m' # Green
TOOL_OUTPUT_COLOR='\033[0;34m' # Blue
NO_COLOR='\033[0m' # No color

# Function to log messages
log() {
  echo -e "${LOG_COLOR}[SCRIPT LOG]${NO_COLOR} $1" # Always show script logs
}

# Function to run a command and optionally show its output
run_tool() {
  local tool_name="$1"
  local command="$2"

  log "Running $tool_name..."
  if [ "$VERBOSE" = true ]; then
    echo -e "${TOOL_OUTPUT_COLOR}[TOOL OUTPUT]${NO_COLOR} $tool_name:"
    eval "$command"
  else
    eval "$command" >/dev/null 2>&1
  fi

  if [ $? -eq 0 ]; then
    log "$tool_name completed successfully."
  else
    log "ERROR: $tool_name failed."
    exit 1
  fi
}

# Validate the domain format
if ! echo "$DOMAIN" | grep -E -q '^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$'; then
  echo "ERROR: Invalid domain format!"
  exit 1
fi

# Log domain being enumerated
log "Enumerating subdomains for domain: $DOMAIN, with bruteforce: $BRUTEFORCE"

# Check the number of dots in the given domain
countdots=$(echo "$DOMAIN" | grep -o "\." | wc -l)

# Prepare directory
rm -rf /tmp/"$DOMAIN" 2>/dev/null
mkdir -p /tmp/"$DOMAIN"

# Variables
if [ "$countdots" -eq 1 ]; then
  domain1=$(echo "$DOMAIN" | cut -d'.' -f1)
  extension=$(echo "$DOMAIN" | cut -d'.' -f2)
elif [ "$countdots" -eq 2 ]; then
  domain1=$(echo "$DOMAIN" | cut -d'.' -f1)
  domain2=$(echo "$DOMAIN" | cut -d'.' -f2)
  extension=$(echo "$DOMAIN" | cut -d'.' -f3)
else
  echo "ERROR: Invalid domain format!"
  exit 1
fi

# Running tools

## Amass

run_tool "Amass (Passive)" "/root/go/bin/amass enum -passive -d \"$DOMAIN\" -v -o /tmp/\"$DOMAIN\"/amass_passive.txt"

run_tool "Amass (Active)" "/root/go/bin/amass enum -active -d \"$DOMAIN\" -v -o /tmp/\"$DOMAIN\"/amass_active.txt"

if [ "$BRUTEFORCE" = true ]; then
  run_tool "Amass (Bruteforce)" "/root/go/bin/amass enum -brute -d \"$DOMAIN\" -v -o /tmp/\"$DOMAIN\"/amass_bruteforce.txt"
fi

## Subfinder

if [ "$BRUTEFORCE" = true ]; then
  run_tool "Subfinder" "/root/go/bin/subfinder -d \"$DOMAIN\" -all -v -o /tmp/\"$DOMAIN\"/subfinder.txt"
else
  run_tool "Subfinder" "/root/go/bin/subfinder -d \"$DOMAIN\" -v -o /tmp/\"$DOMAIN\"/subfinder.txt"
fi

## Assetfinder

run_tool "Assetfinder" "/root/go/bin/assetfinder \"$DOMAIN\" > /tmp/\"$DOMAIN\"/assetfinder.txt"

## Findomain

run_tool "Findomain" "findomain -t \"$DOMAIN\" --external-subdomains -v -u /tmp/\"$DOMAIN\"/findomain.txt"

## Sublist3r

if [ "$BRUTEFORCE" = true ]; then
  run_tool "Sublist3r" "sublist3r -d \"$DOMAIN\" -v -b -o /tmp/\"$DOMAIN\"/sublist3r.txt"
else
  run_tool "Sublist3r" "sublist3r -d \"$DOMAIN\" -v -o /tmp/\"$DOMAIN\"/sublist3r.txt"
fi

## DNSRecon

if [ "$BRUTEFORCE" = true ]; then
  run_tool "DNSRecon" "dnsrecon -d \"$DOMAIN\" -v -t brt -D /root/SubdomainEnum/files/subdomains.txt -x /tmp/\"$DOMAIN\"/dnsrecon.txt"
fi

## Shuffledns

if [ "$BRUTEFORCE" = true ]; then
  run_tool "Shuffledns" "/root/go/bin/shuffledns -d \"$DOMAIN\" -v -mode bruteforce -w /root/SubdomainEnum/files/subdomains.txt -r /root/SubdomainEnum/files/resolvers.txt -o /tmp/\"$DOMAIN\"/shuffledns.txt"
fi

# Merge and clean results
log "Merging results..."
cat /tmp/"$DOMAIN"/*.txt | sort -u > /tmp/"$DOMAIN"/results_merged.tmp 2>/dev/null

: '

# Cleaning duplicates
log "Cleaning and deduplicating results..."
tr '<BR>' '\n' < /tmp/"$DOMAIN"/results1.tmp | sed '/^$/d' | sed 's/\r//' | awk '!a[$0]++' > /tmp/"$DOMAIN"/results2.tmp

# Remove false positives
if [ "$countdots" -eq 1 ]; then
  grep "${domain1}\.${extension}" /tmp/"$DOMAIN"/results2.tmp > /tmp/"$DOMAIN"/subdomains.txt
elif [ "$countdots" -eq 2 ]; then
  grep "${domain1}\.${domain2}\.${extension}" /tmp/"$DOMAIN"/results2.tmp > /tmp/"$DOMAIN"/subdomains.txt
fi

# Display enumerated subdomains
log "---------------------- ENUMERATED SUBDOMAINS ----------------------"
cat /tmp/"$DOMAIN"/subdomains.txt | sort -u

# Run httprobe
run_tool "httprobe" "cat /tmp/\"$DOMAIN\"/subdomains.txt | /root/go/bin/httprobe -c 50 > /tmp/\"$DOMAIN\"/http-subdomains.txt"

# Run ResponseChecker
run_tool "ResponseChecker" "/root/go/bin/ResponseChecker /tmp/\"$DOMAIN\"/http-subdomains.txt | tee /tmp/\"$DOMAIN\"/responsecodes.txt"

# Run httpx
run_tool "httpx" "cat /tmp/\"$DOMAIN\"/subdomains.txt | /root/go/bin/httpx -title -tech-detect -status-code -follow-redirects > /tmp/\"$DOMAIN\"/httpx.txt"

log "---------------------------- FINISHED -----------------------------"

'