# SubdomainEnum
Bash wrapper for multiple subdomain enumeration scripts

# Uses:
- [Amass](https://github.com/OWASP/Amass)
- [Turbolist3r](https://github.com/fleetcaptain/Turbolist3r)
- [Assetfinder](https://github.com/tomnomnom/assetfinder)
- [OneForAll](https://github.com/shmilylty/OneForAll)
- [HTTProbe](https://github.com/tomnomnom/httprobe)
- [Chaos](https://github.com/projectdiscovery/chaos-client) // You'll need an API key
- [HTTPResponseChecker](https://github.com/bluecanarybe/ResponseChecker)
- [HTTPX](https://github.com/projectdiscovery/httpx)

The script will run all scripts independently, and merge & clean all results in one file. 
It also supports enumeration of secondlevel subdomains such as subdomain.target.example.com.

# Installation

Clone the repository
```
git clone https://github.com/wardverduyn/SubdomainEnum.git
```

Navigate to the SubdomainEnum folder
```
cd SubdomainEnum
```

Build the image with Docker
```
sudo docker build -t subdomainenum .
```

# Usage via Docker

Run Docker container replacing with your chaos API key as an environment variable and target
```
sudo docker run -v $(pwd):/tmp subdomainenum ./SubdomainEnum.sh <target.com>
```
