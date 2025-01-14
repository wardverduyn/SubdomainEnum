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

# Merge and clean results
cat /tmp/"$1"/*.tmp | sort -u > /tmp/"$1"/final_subdomains.txt
echo "Subdomain enumeration completed. Results saved to /tmp/$1/final_subdomains.txt"