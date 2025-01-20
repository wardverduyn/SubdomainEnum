# SubdomainEnum

SubdomainEnum is a **Python-based** wrapper for multiple subdomain enumeration tools. It runs various tools independently, merges & deduplicates all results, and can optionally generate an **HTML report** with screenshots, IP addresses, and example nmap commands.

## Tools Used

The script currently calls the following subdomain enumeration tools:

- [Amass](https://github.com/owasp-amass/amass)
- [DNSRecon](https://github.com/darkoperator/dnsrecon) (in bruteforce mode when requested)
- [Findomain](https://github.com/Findomain/Findomain)
- [Knock](https://github.com/guelfoweb/knock) (in bruteforce mode when requested)
- [Shuffledns](https://github.com/projectdiscovery/shuffledns) (in bruteforce mode when requested)
- [Subfinder](https://github.com/projectdiscovery/subfinder) (with optional Chaos API support)
- [Sublist3r](https://github.com/aboul3la/Sublist3r) (in bruteforce mode when requested)

### Optional Screenshot Tool

When generating an HTML report (`--report`), the script uses a screenshot tool to capture web screenshots. By default, the example Docker image installs **[gowitness](https://github.com/sensepost/gowitness)**.

## Installation

1. **Clone** this repository:
   ```bash
   git clone https://github.com/wardverduyn/SubdomainEnum.git
   ```
2. **Navigate** to the cloned directory:
   ```bash
   cd SubdomainEnum
   ```
3. **Build** the Docker image:
   ```bash
   sudo docker build -t subdomainenum .
   ```

## Usage

### Basic Enumeration

```bash
sudo docker run -it -v "$(pwd):/tmp" subdomainenum -d example.com
```
Replace `example.com` with your target domain.

### Verbose Mode

Add `--verbose` to see real-time tool output:

```bash
sudo docker run -it -v "$(pwd):/tmp" subdomainenum -d example.com --verbose
```

### Bruteforce Mode

Add `--bruteforce` to enable Amass, DNSRecon, Knock, and Shuffledns bruteforce enumeration:

```bash
sudo docker run -it -v "$(pwd):/tmp" subdomainenum -d example.com --bruteforce
```

### Generating an HTML Report with Screenshots

Use `--report` to produce an **HTML file** with subdomain screenshots and IP addresses. (Ensure `gowitness` or another tool is installed in the Docker image.)

```bash
sudo docker run -it -v "$(pwd):/tmp" subdomainenum -d example.com --report
```

This will:
- Attempt to resolve each subdomain to an IP.
- Use `gowitness` to capture a screenshot of each subdomain.
- Generate `report.html` under `/tmp/<domain>` inside the container (mapped to `./<domain>` on your host).

## Output

The script stores results in a new directory named after your target domain, e.g., `./example.com` if your domain is `example.com`. Inside, you'll find:

- **Individual tool output** files (e.g. `amass.txt`, `findomain.txt`, `subfinder.txt`, etc.).  
- **`results_merged.tmp`** – A merged, deduplicated list of discovered subdomains.  
- **`screenshots/`** (only if `--report` is used) – Folder containing PNG screenshots.  
- **`report.html`** (only if `--report` is used) – An HTML report summarizing subdomains, resolved IPs, screenshots, and example `nmap` commands.