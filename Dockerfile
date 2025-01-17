FROM python:3-alpine

# Install necessary packages
RUN apk add cargo cmake curl g++ gcc git go make musl-dev nano python3-dev rust unzip wget && \
    rm -rf /var/cache/apk/*

# Disable CGO
ENV CGO_ENABLED=0

# Install Go-based tools
RUN go install -v github.com/owasp-amass/amass/v4/...@master && \
    go install -v github.com/tomnomnom/assetfinder@latest && \
    go install -v github.com/tomnomnom/httprobe@latest && \
    go install -v github.com/bluecanarybe/ResponseChecker@latest && \
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest && \
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && \
    go install -v github.com/OJ/gobuster@latest && \
    go install -v github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest

# Install Findomain from precompiled binary
ADD https://github.com/Findomain/Findomain/releases/latest/download/findomain-linux.zip /tmp/findomain.tar.gz
RUN mkdir -p /tmp/findomain && \
    unzip /tmp/findomain.tar.gz -d /tmp/findomain && \
    mv /tmp/findomain/findomain /usr/local/bin/findomain && \
    chmod +x /usr/local/bin/findomain && \
    rm -rf /tmp/findomain /tmp/findomain.tar.gz

# Install Python-based tools
RUN pip install dnsrecon knock-subdomains sublist3r

# Add configuration and script
ARG CACHEBUST=1
RUN mkdir -p /root/.config/subfinder
COPY SubdomainEnum.sh /usr/local/bin/SubdomainEnum.sh
RUN chmod +x /usr/local/bin/SubdomainEnum.sh

# Add resolvers and wordlist files
RUN mkdir -p /root/SubdomainEnum/files
COPY resolvers.txt /root/SubdomainEnum/files
COPY subdomains.txt /root/SubdomainEnum/files
RUN chmod 644 /root/SubdomainEnum/files/resolvers.txt /root/SubdomainEnum/files/subdomains.txt


# Set default entry point
ENTRYPOINT ["/bin/sh", "/usr/local/bin/SubdomainEnum.sh"]

