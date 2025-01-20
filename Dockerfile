FROM python:3-alpine

# Install necessary packages minimally
RUN apk add \
    go \
    curl \
    unzip \
    wget

# Install Go-based tools (gowitness removed)
RUN go install -v github.com/owasp-amass/amass/v4/...@master && \
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && \
    go install -v github.com/OJ/gobuster@latest && \
    go install -v github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest

# Install Eyewitness from the latest release dynamically
RUN mkdir -p /opt/EyeWitness && \
    LATEST_ZIP_URL=$(curl -s https://api.github.com/repos/RedSiege/EyeWitness/releases/latest | \
      grep '"zipball_url":' | head -n 1 | cut -d '"' -f 4) && \
    wget -O /tmp/EyeWitness.zip "${LATEST_ZIP_URL}" && \
    unzip /tmp/EyeWitness.zip -d /opt/EyeWitness && \
    rm -rf /tmp/EyeWitness.zip && \
    cd /opt/EyeWitness && \
    # Assume only one release folder was created; get its name
    RELEASE_DIR=$(ls -d */ | head -n 1) && \
    # Move the contents of the release folder up to /opt/EyeWitness
    mv ${RELEASE_DIR}* ./ && \
    rm -rf ${RELEASE_DIR} && \
    # Now navigate to the Python/setup directory and run setup.sh
    cd Python/setup && \
    chmod +x setup.sh && \
    ./setup.sh

# Install Findomain from precompiled binary
ADD https://github.com/Findomain/Findomain/releases/latest/download/findomain-linux.zip /tmp/findomain.zip
RUN mkdir -p /tmp/findomain && \
    unzip /tmp/findomain.zip -d /tmp/findomain && \
    mv /tmp/findomain/findomain /usr/local/bin/findomain && \
    chmod +x /usr/local/bin/findomain && \
    rm -rf /tmp/findomain /tmp/findomain.zip

# Install Python-based tools
RUN pip install \
    dnsrecon \
    knock-subdomains \
    sublist3r \
    rich

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