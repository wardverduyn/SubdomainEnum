FROM python:3-alpine

# Install necessary packages
RUN apk add --no-cache \
    cargo \
    cmake \
    curl \
    g++ \
    gcc \
    git \
    go \
    make \
    musl-dev \
    nano \
    python3-dev \
    rust \
    unzip \
    wget

# Install Go-based tools
RUN go install -v github.com/owasp-amass/amass/v4/...@master && \
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && \
    go install -v github.com/OJ/gobuster@latest && \
    go install -v github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest && \
    go install -v github.com/sensepost/gowitness@latest

# Install Findomain from precompiled binary
ADD https://github.com/Findomain/Findomain/releases/latest/download/findomain-linux.zip /tmp/findomain.zip
RUN mkdir -p /tmp/findomain && \
    unzip /tmp/findomain.zip -d /tmp/findomain && \
    mv /tmp/findomain/findomain /usr/local/bin/findomain && \
    chmod +x /usr/local/bin/findomain && \
    rm -rf /tmp/findomain /tmp/findomain.zip

# Install Python-based tools
RUN pip install --no-cache-dir \
    dnsrecon \
    knock-subdomains \
    sublist3r \
    rich

# Prepare subfinder config directory
RUN mkdir -p /root/.config/subfinder

# Make sure the cached version of the script is up-to-date
ARG CACHEBUST=1

# Copy your new Python script
# Make sure subdomain_enum.py is in the same directory as this Dockerfile
COPY subdomain_enum.py /usr/local/bin/subdomain_enum.py
RUN chmod +x /usr/local/bin/subdomain_enum.py

# Copy resolvers and wordlist files
RUN mkdir -p /root/SubdomainEnum/files
COPY resolvers.txt /root/SubdomainEnum/files/
COPY subdomains.txt /root/SubdomainEnum/files/
RUN chmod 644 /root/SubdomainEnum/files/resolvers.txt /root/SubdomainEnum/files/subdomains.txt

# Set default entry point to run the Python script
ENTRYPOINT ["python", "/usr/local/bin/subdomain_enum.py"]
