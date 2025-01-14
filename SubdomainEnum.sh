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
  if [ "$VERBOSE" = true ]; then
    echo "$1"
  fi
}

# Validate the domain format
if ! echo "$DOMAIN" | grep -E -q '^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$'; then
  echo "ERROR: Invalid domain format!"
  exit 1
fi

# Log domain being enumerated
echo "Enumerating subdomains for domain: $DOMAIN"

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
log "Running Amass..."
/root/go/bin/amass enum -d "$DOMAIN" -active -src -timeout 20 -norecursive -o /tmp/"$DOMAIN"/amass1.tmp 2>&1
if [ $? -eq 0 ]; then
  log "Amass completed successfully."
else
  echo "ERROR: Amass failed."
  exit 1
fi

log "Running Turbolist3r..."
python3 /var/tmp/Turbolist3r/turbolist3r.py -d "$DOMAIN" -o /tmp/"$DOMAIN"/turbolist3r.tmp 2>&1
if [ $? -eq 0 ]; then
  log "Turbolist3r completed successfully."
else
  echo "ERROR: Turbolist3r failed."
  exit 1
fi

log "Running Assetfinder..."
/root/go/bin/assetfinder "$DOMAIN" > /tmp/"$DOMAIN"/assetfinder.tmp 2>&1
if [ $? -eq 0 ]; then
  log "Assetfinder completed successfully."
else
  echo "ERROR: Assetfinder failed."
  exit 1
fi

log "Running OneForAll..."
python3 /var/tmp/OneForAll/oneforall.py --target "$DOMAIN" --fmt json --brute False run 2>&1
if [ $? -eq 0 ]; then
  log "OneForAll completed successfully."
else
  echo "ERROR: OneForAll failed."
  exit 1
fi

if [ -n "$CHAOS_API_KEY" ]; then
  log "Running Chaos..."
  CHAOS_KEY="$CHAOS_API_KEY" /root/go/bin/chaos -d "$DOMAIN" -silent -o /tmp/"$DOMAIN"/chaos.tmp 2>&1
  if [ $? -eq 0 ]; then
    log "Chaos completed successfully."
  else
    echo "ERROR: Chaos failed."
    exit 1
  fi
else
  echo "Skipping Chaos as no API key is provided."
  touch /tmp/"$DOMAIN"/chaos.tmp
fi

log "Running Subfinder..."
/root/go/bin/subfinder -d "$DOMAIN" -o /tmp/"$DOMAIN"/subfinder.tmp 2>&1
if [ $? -eq 0 ]; then
  log "Subfinder completed successfully."
else
  echo "ERROR: Subfinder failed."
  exit 1
fi

# Merge and clean results
log "Merging results..."
cat /tmp/"$DOMAIN"/amass1.tmp /tmp/"$DOMAIN"/chaos.tmp /tmp/"$DOMAIN"/turbolist3r.tmp \
    /tmp/"$DOMAIN"/assetfinder.tmp /tmp/"$DOMAIN"/subfinder.tmp /var/tmp/OneForAll/results/temp/*.txt \
    > /tmp/"$DOMAIN"/results1.tmp 2>/dev/null

# Cleaning duplicates
tr '<BR>' '\n' < /tmp/"$DOMAIN"/results1.tmp | sed '/^$/d' | sed 's/\r//' | awk '!a[$0]++' > /tmp/"$DOMAIN"/results2.tmp

# Remove false positives
if [ "$countdots" -eq 1 ]; then
  grep "${domain1}\.${extension}" /tmp/"$DOMAIN"/results2.tmp > /tmp/"$DOMAIN"/subdomains.txt
elif [ "$countdots" -eq 2 ]; then
  grep "${domain1}\.${domain2}\.${extension}" /tmp/"$DOMAIN"/results2.tmp > /tmp/"$DOMAIN"/subdomains.txt
fi

# Display enumerated subdomains
echo "---------------------- ENUMERATED SUBDOMAINS ----------------------"
cat /tmp/"$DOMAIN"/subdomains.txt | sort -u

# Run httprobe
log "Running httprobe..."
cat /tmp/"$DOMAIN"/subdomains.txt | /root/go/bin/httprobe -c 50 > /tmp/"$DOMAIN"/http-subdomains.txt

# Run ResponseChecker
log "Running ResponseChecker..."
/root/go/bin/ResponseChecker /tmp/"$DOMAIN"/http-subdomains.txt | tee /tmp/"$DOMAIN"/responsecodes.txt

# Run httpx
log "Running httpx..."
cat /tmp/"$DOMAIN"/subdomains.txt | /root/go/bin/httpx -title -tech-detect -status-code -follow-redirects > /tmp/"$DOMAIN"/httpx.txt

echo "---------------------------- FINISHED -----------------------------"
