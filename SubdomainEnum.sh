#!/bin/bash

# Ensure a domain is given as an argument
if [ -z "$1" ]; then
  echo "ERROR: No domain provided!"
  exit 1
fi

DOMAIN="$1"
VERBOSE=false
if [ "$2" == "--verbose" ]; then
  VERBOSE=true
fi

# Function to log messages
log() {
  echo "[SCRIPT LOG] $1" # Always show script logs
}

# Function to run a command and optionally show its output
run_tool() {
  local tool_name="$1"
  local command="$2"

  log "Running $tool_name..."
  if [ "$VERBOSE" = true ]; then
    echo "[TOOL OUTPUT] $tool_name:"
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
log "Enumerating subdomains for domain: $DOMAIN"

# Check the number of dots in the given domain
countdots=$(echo "$DOMAIN" | grep -o "\." | wc -l)

# Prepare directory
rm -rf /tmp/"$DOMAIN" 2>/dev/null
rm -rf /var/tmp/OneForAll/results/* 2>/dev/null
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
run_tool "Amass" "/root/go/bin/amass enum -d \"$DOMAIN\" -active -timeout 20 -norecursive -o /tmp/\"$DOMAIN\"/amass.tmp"

run_tool "Turbolist3r" "python3 /var/tmp/Turbolist3r/turbolist3r.py -d \"$DOMAIN\" -o /tmp/\"$DOMAIN\"/turbolist3r.tmp"

run_tool "Assetfinder" "/root/go/bin/assetfinder \"$DOMAIN\" > /tmp/\"$DOMAIN\"/assetfinder.tmp"

run_tool "OneForAll" "python3 /var/tmp/OneForAll/oneforall.py --target \"$DOMAIN\" --fmt json --brute False run"

if [ -n "$CHAOS_API_KEY" ]; then
  run_tool "Chaos" "CHAOS_KEY=\"$CHAOS_API_KEY\" /root/go/bin/chaos -d \"$DOMAIN\" -silent -o /tmp/\"$DOMAIN\"/chaos.tmp"
else
  log "Skipping Chaos as no API key is provided."
  touch /tmp/"$DOMAIN"/chaos.tmp
fi

run_tool "Subfinder" "/root/go/bin/subfinder -d \"$DOMAIN\" -o /tmp/\"$DOMAIN\"/subfinder.tmp"

# Merge and clean results
log "Merging results..."
cat /tmp/"$DOMAIN"/amass.tmp /tmp/"$DOMAIN"/chaos.tmp /tmp/"$DOMAIN"/turbolist3r.tmp \
    /tmp/"$DOMAIN"/assetfinder.tmp /tmp/"$DOMAIN"/subfinder.tmp /var/tmp/OneForAll/results/temp/*.txt \
    > /tmp/"$DOMAIN"/results1.tmp 2>/dev/null

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
