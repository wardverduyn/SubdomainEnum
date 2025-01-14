# SubdomainEnum

SubdomainEnum is a bash wrapper for multiple subdomain enumeration scripts. It runs various tools independently and merges & cleans all results into one file. It also supports enumeration of second-level subdomains such as `subdomain.target.example.com`.

## Tools Used

- [Amass](https://github.com/OWASP/Amass)
- [Turbolist3r](https://github.com/fleetcaptain/Turbolist3r)
- [Assetfinder](https://github.com/tomnomnom/assetfinder)
- [OneForAll](https://github.com/shmilylty/OneForAll)
- [HTTProbe](https://github.com/tomnomnom/httprobe)
- [Chaos](https://github.com/projectdiscovery/chaos-client) (You'll need an API key)
- [HTTPResponseChecker](https://github.com/bluecanarybe/ResponseChecker)
- [HTTPX](https://github.com/projectdiscovery/httpx)

## Installation

1. Clone the repository:
    ```sh
    git clone https://github.com/wardverduyn/SubdomainEnum.git
    ```

2. Navigate to the SubdomainEnum folder:
    ```sh
    cd SubdomainEnum
    ```

3. Build the Docker image:
    ```sh
    sudo docker build -t subdomainenum .
    ```

## Usage

### Running the Docker Container

To run the Docker container, use the following command. Replace `example.com` with your target domain.

If you have a Chaos API key:
```sh
sudo docker run -v $(pwd):/tmp -e CHAOS_API_KEY=your_chaos_api_key subdomainenum example.com
```

If you don't have a Chaos API key:
```sh
sudo docker run -v $(pwd):/tmp subdomainenum example.com
```

## Output
The script will save the enumerated subdomains and HTTP probe results in the `/tmp/<target_domain>` directory inside the container. The results will be merged, cleaned, and saved in the following files:

- `subdomains.txt`: List of unique subdomains.
- `http-subdomains.txt`: List of subdomains serving HTTP/HTTPS.
- `200-OK-urls.txt`: List of URLs returning HTTP 200 OK status.
- `httpx.txt`: Detailed HTTPX results including titles, technologies, and status codes.