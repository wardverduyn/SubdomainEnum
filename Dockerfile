FROM python:3-alpine

# Install necessary packages
RUN apk add --update-cache \
    curl git go nano unzip wget && \
    rm -rf /var/cache/apk/*

# Disable CGO
ENV CGO_ENABLED=0

# Install Go-based tools
RUN go install -v github.com/owasp-amass/amass/v4/...@master && \
    go install -v github.com/tomnomnom/assetfinder@latest && \
    go install -v github.com/projectdiscovery/chaos-client/cmd/chaos@latest && \
    go install -v github.com/tomnomnom/httprobe@latest && \
    go install -v github.com/bluecanarybe/ResponseChecker@latest && \
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest && \
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# Clone and set up Python-based tools
RUN git clone https://github.com/fleetcaptain/Turbolist3r.git /var/tmp/Turbolist3r && \
    pip install -r /var/tmp/Turbolist3r/requirements.txt && \
    git clone https://github.com/shmilylty/OneForAll.git /var/tmp/OneForAll && \
    python3 -m pip install -U pip setuptools wheel && \
    pip install -r /var/tmp/OneForAll/requirements.txt

# Add configuration and script
RUN mkdir -p /root/.config/subfinder
COPY SubdomainEnum.sh /usr/local/bin/SubdomainEnum.sh
RUN chmod +x /usr/local/bin/SubdomainEnum.sh

# Set default entry point
ENTRYPOINT ["/usr/local/bin/SubdomainEnum.sh"]
