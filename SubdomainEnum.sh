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

run_tool "Subfinder" "/root/go/bin/subfinder -d \"$DOMAIN\" -o /tmp/\"$DOMAIN\"/subfinder.tmp"

run_tool "Assetfinder" "/root/go/bin/assetfinder \"$DOMAIN\" > /tmp/\"$DOMAIN\"/assetfinder.tmp"

run_tool "Findomain" "/root/go/bin/findomain -t \"$DOMAIN\" -o /tmp/\"$DOMAIN\"/findomain.txt"

run_tool "Knockpy" "knockpy \"$DOMAIN\" -o /tmp/\"$DOMAIN\"/knockpy.txt"

if [ "$BRUTEFORCE" = true ]; then
  run_tool "DNSRecon" "dnsrecon -d \"$DOMAIN\" -t brt -D /root/SubdomainEnum/files/subdomains.txt -o /tmp/\"$DOMAIN\"/dnsrecon.txt"

  run_tool "MassDNS" "massdns -r /root/SubdomainEnum/files/resolvers.txt -t A -o S -w /tmp/\"$DOMAIN\"/massdns.txt /tmp/\"$DOMAIN\"/subfinder.tmp"

  run_tool "Gobuster" "gobuster dns -d \"$DOMAIN\" -w /root/SubdomainEnum/files/subdomains.txt -o /tmp/\"$DOMAIN\"/gobuster.txt"

  run_tool "Shuffledns" "shuffledns -d \"$DOMAIN\" -w /root/SubdomainEnum/files/subdomains.txt -r /root/SubdomainEnum/files/resolvers.txt -o /tmp/\"$DOMAIN\"/shuffledns.txt"
fi

run_tool "TheHarvester" "theHarvester -d \"$DOMAIN\" -l 500 -b all -f /tmp/\"$DOMAIN\"/theharvester.html"

# Merge and clean results
log "Merging results..."
cat /tmp/"$DOMAIN"/amass.tmp /tmp/"$DOMAIN"/subfinder.tmp /tmp/"$DOMAIN"/assetfinder.tmp \
    /tmp/"$DOMAIN"/findomain.txt /tmp/"$DOMAIN"/knockpy.txt \
    $(if [ "$BRUTEFORCE" = true ]; then echo "/tmp/\"$DOMAIN\"/dnsrecon.txt /tmp/\"$DOMAIN\"/massdns.txt /tmp/\"$DOMAIN\"/gobuster.txt /tmp/\"$DOMAIN\"/shuffledns.txt"; fi) \
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
