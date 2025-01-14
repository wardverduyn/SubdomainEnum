#! /bin/sh

# Ensure a domain is given as an argument
if [ -z "$1" ]; then
  echo "ERROR: no domain given as argument!"
  exit 1
fi

# Check number of dots in the given domain
countdots=$(echo "$1" | grep -o "\." | wc -l)

# Prepare directory
rm -rf /tmp/"$1" 2>/dev/null
rm -rf /var/tmp/OneForAll/results/* 2>/dev/null
mkdir -p /tmp/"$1"

# Variables
if [ "$countdots" -eq 1 ]; then
  domain1=$(echo "$1" | cut -d'.' -f1)
  extension=$(echo "$1" | cut -d'.' -f2)
elif [ "$countdots" -eq 2 ]; then
  domain1=$(echo "$1" | cut -d'.' -f1)
  domain2=$(echo "$1" | cut -d'.' -f2)
  extension=$(echo "$1" | cut -d'.' -f3)
else
  echo "ERROR: invalid domain format!"
  exit 1
fi

echo 'Running Amass'
/root/go/bin/amass enum -d "$1" -active -noalts -src -timeout 20 -norecursive -o /tmp/"$1"/amass1.tmp
cat /tmp/"$1"/amass1.tmp | cut -d']' -f 2 | awk '{print $1}' | sort -u > /tmp/"$1"/amass2.tmp

echo 'Running Turbolist3r'
python3 /var/tmp/Turbolist3r/turbolist3r.py -d "$1" -o /tmp/"$1"/turbolist3r.tmp

echo 'Running Assetfinder'
/root/go/bin/assetfinder "$1" > /tmp/"$1"/assetfinder.tmp

echo 'Running OneForAll'
python3 /var/tmp/OneForAll/oneforall.py --target "$1" --fmt json --brute False run

if [ -n "$CHAOS_API_KEY" ]; then
  echo 'Running Chaos'
  CHAOS_KEY="$CHAOS_API_KEY" /root/go/bin/chaos -d "$1" -silent -o /tmp/"$1"/chaos.tmp
else
  echo "Skipping Chaos as no API key is provided"
  touch /tmp/"$1"/chaos.tmp
fi

echo 'Running Subfinder'
/root/go/bin/subfinder -d "$1" -o /tmp/"$1"/subfinder.tmp

# Merge and clean results
cat /tmp/"$1"/amass2.tmp /tmp/"$1"/chaos.tmp /tmp/"$1"/turbolist3r.tmp /tmp/"$1"/assetfinder.tmp /tmp/"$1"/subfinder.tmp /var/tmp/OneForAll/results/temp/*.txt > /tmp/"$1"/results1.tmp

# Clean duplicates and show results
tr '<BR>' '\n' < /tmp/"$1"/results1.tmp > /tmp/"$1"/results2.tmp
sed -i '/^$/d' /tmp/"$1"/results2.tmp
sed 's/\r//' < /tmp/"$1"/results2.tmp > /tmp/"$1"/results3.tmp
awk '!a[$0]++' /tmp/"$1"/results3.tmp > /tmp/"$1"/results4.tmp

# Remove false positives (non-matching domain)
if [ "$countdots" -eq 1 ]; then
  egrep ''$domain1'\.'$extension'' /tmp/"$1"/results4.tmp > /tmp/"$1"/subdomains.txt
elif [ "$countdots" -eq 2 ]; then
  egrep ''$domain1'\.'$domain2'\.'$extension'' /tmp/"$1"/results4.tmp > /tmp/"$1"/subdomains.txt
else
  echo "ERROR: invalid domain format!"
  exit 1
fi

RED='\033[0;31m'
printf ''${RED}'---------------------- ENUMERATED SUBDOMAINS ----------------------\n'
sort -u /tmp/"$1"/subdomains.txt

printf ''${RED}'------------------------ RUNNING HTTPROBE  ------------------------\n'
cat /tmp/"$1"/subdomains.txt | /root/go/bin/httprobe -p http:8000 -p http:8080 -p http:8443 -p https:8000 -p https:8080 -p https:8443 -c 50 | tee /tmp/"$1"/http-subdomains.txt

printf ''${RED}'--------------------- RUNNING RESPONSECHECKER ---------------------\n'
/root/go/bin/ResponseChecker /tmp/"$1"/http-subdomains.txt | tee /tmp/"$1"/responsecodes.txt
cat /tmp/"$1"/responsecodes.txt | grep 200 | awk '{ print $1 }' > /tmp/"$1"/200-OK-urls.txt

printf ''${RED}'--------------------- RUNNING HTTPX ---------------------\n'
cat /tmp/"$1"/subdomains.txt | /root/go/bin/httpx -title -tech-detect -status-code -follow-redirects > /tmp/"$1"/httpx.txt | tee
cat /tmp/"$1"/httpx.txt

printf ''${RED}'---------------------------- FINISHED -----------------------------\n'

rm /tmp/"$1"/*.tmp