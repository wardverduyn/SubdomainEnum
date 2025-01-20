#!/usr/bin/env python3

import os
import re
import shutil
import socket
import subprocess
import argparse
from rich.console import Console
from rich.progress import Progress
from rich.style import Style
from urllib.parse import urlparse

# Initialize Rich console
console = Console(force_terminal=True, highlight=False)

# Styles
green = Style(color="green")
red = Style(color="red")
cyan = Style(color="cyan")
yellow = Style(color="yellow")
blue = Style(color="blue")

def banner():
    """
    Print a nice banner with tool info.
    """
    console.print("[bold magenta]Subdomain Enumeration Script[/bold magenta]", style=cyan)
    console.print("Developer: [bold bright_cyan]Ward Verduyn[/bold bright_cyan]", style=yellow)

def log(message, style=green, prefix="[SCRIPT LOG] "):
    """
    Log a message in a colored format.
    """
    console.print(f"{prefix}{message}", style=style)

def run_tool(tool_name, command, verbose=False):
    """
    Run an external tool using subprocess. 
    If verbose=True, print its output; otherwise, suppress stdout/stderr.
    """
    log(f"Running {tool_name}...", style=cyan)
    if verbose:
        # Print tool output in real-time
        result = subprocess.run(command, shell=True)
    else:
        # Suppress output
        result = subprocess.run(command, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    if result.returncode == 0:
        log(f"{tool_name} completed successfully.", style=green)
    else:
        log(f"ERROR: {tool_name} failed with return code {result.returncode}.", style=red)
        exit(1)

def validate_domain(domain):
    """
    Validates that the domain is in a valid format (e.g. 'example.com').
    Returns True if valid, False otherwise.
    """
    # Simple check - adjust for your domain validation needs
    pattern = r"^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$"
    return bool(re.match(pattern, domain))

def prepare_directory(domain):
    """
    Creates a fresh /tmp/<domain> directory, removing any existing one.
    Returns the path to the directory.
    """
    dir_path = os.path.join("/tmp", domain)
    if os.path.exists(dir_path):
        shutil.rmtree(dir_path)
    os.makedirs(dir_path)
    return dir_path

def merge_results(domain_dir):
    """
    Merge and deduplicate all .txt files in the given directory.
    Return a list of unique subdomains found.
    """
    merged_path = os.path.join(domain_dir, "results_merged.tmp")
    # A set to avoid duplicates
    all_subdomains = set()

    # Regex that captures the domain name preceding `(FQDN)`
    # e.g. "myportal.lab9.be (FQDN)"
    domain_pattern = re.compile(r"([A-Za-z0-9._-]+\.[A-Za-z0-9._-]+)\s*\(FQDN\)")

    for filename in os.listdir(domain_dir):
        if filename.endswith(".txt"):
            file_path = os.path.join(domain_dir, filename)
            with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue

                    # If the line is a "graph" style from Amass
                    # e.g. "lab9.be (FQDN) --> ns_record --> ns1.cloud.telenet.be (FQDN)"
                    # we'll match all domain occurrences
                    matches = domain_pattern.findall(line)
                    if matches:
                        for match in matches:
                            all_subdomains.add(match.lower())

                    else:
                        # If it's a normal line with just "sub.domain.com"
                        # or no (FQDN) tokens
                        # fallback: check if the line is purely a domain or subdomain
                        # e.g. "sub.domain.com"
                        # (You can refine this fallback logic as needed)
                        fallback_dom = line.lower()
                        # Basic "is this line just a domain?" check
                        if re.match(r"^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$", fallback_dom):
                            all_subdomains.add(fallback_dom)

    # Write merged results
    with open(merged_path, "w", encoding="utf-8") as f:
        for sd in sorted(all_subdomains):
            f.write(sd + "\n")

    return sorted(all_subdomains)

def resolve_and_screenshot(all_subdomains, domain, domain_dir, verbose=False):
    """
    For each subdomain:
      - Attempt to resolve IP address.
      - Use gowitness (or another tool) to take a screenshot of http(s)://subdomain
      - Generate a simple HTML report with subdomain, IP, screenshot, and Nmap commands.
    """
    log("Resolving subdomains and generating screenshots...", style=cyan)

    screenshots_dir = os.path.join(domain_dir, "screenshots")
    if not os.path.exists(screenshots_dir):
        os.makedirs(screenshots_dir)

    # We'll track subdomain -> IP in a dictionary for the HTML report
    subdomain_info = {}

    # 1) Resolve each subdomain
    for sub in all_subdomains:
        try:
            ip_address = socket.gethostbyname(sub)
        except socket.gaierror:
            ip_address = "Resolution Failed"

        subdomain_info[sub] = ip_address

    # 2) Use gowitness or similar to screenshot each subdomain
    #    We'll create a file subdomains_for_screenshots.txt in domain_dir
    #    Then pass it to gowitness. 
    screenshot_input = os.path.join(domain_dir, "subdomains_for_screenshots.txt")
    with open(screenshot_input, "w") as fw:
        for sub in all_subdomains:
            fw.write(f"{sub}\n")

    # Example command:
    # gowitness file -f subdomains_for_screenshots.txt --threads 10 --destination screenshots_dir
    gowitness_cmd = (
        f"/root/go/bin/gowitness file -f {screenshot_input} "
        f"--threads 5 "  # or 10 if you want more concurrency
        f"--destination {screenshots_dir}"
    )
    run_tool("gowitness", gowitness_cmd, verbose)

    # 3) Build an HTML report
    report_path = os.path.join(domain_dir, "report.html")
    with open(report_path, "w") as html:
        html.write("<html><head><title>Subdomain Report</title></head><body>\n")
        html.write(f"<h1>Subdomain Report for {domain}</h1>\n")
        html.write(f"<p>Found {len(all_subdomains)} subdomains.</p>\n")
        
        # Table or list
        html.write("<table border='1' cellpadding='5' cellspacing='0'>\n")
        html.write("<tr><th>Subdomain</th><th>IP Address</th><th>Screenshot</th><th>Nmap Commands</th></tr>\n")
        
        for sub, ip in subdomain_info.items():
            html.write("<tr>\n")
            # Subdomain
            html.write(f"<td>{sub}</td>\n")
            # IP
            html.write(f"<td>{ip}</td>\n")

            # Screenshot: gowitness typically saves screenshots as <subdomain>.png or by hashed name.
            # If you want to embed them, you might do <img src='screenshots/subdomain.png'> 
            # but you need to confirm how gowitness names them. 
            # By default, gowitness might store them by base64-ing the domain. 
            # For simplicity, let's assume it uses sub.png (adjust as needed).
            
            # We'll guess the file is something like <screenshots_dir>/<sub>.png
            # If it doesn't exist, just write 'No screenshot'
            screenshot_filename = f"{sub}.png"
            screenshot_fullpath = os.path.join(screenshots_dir, screenshot_filename)
            if os.path.exists(screenshot_fullpath):
                # Embed or just link
                html.write(f"<td><img src='screenshots/{screenshot_filename}' width='250'></td>\n")
            else:
                html.write("<td>No screenshot</td>\n")

            # Provide some example nmap commands
            # e.g. nmap -p80,443 subdomain
            #     nmap -sC -sV subdomain
            # We'll put these in a small list
            html.write("<td>")
            html.write("<ul>")
            if ip != "Resolution Failed":
                html.write(f"<li>nmap -p80,443 {ip}</li>")
                html.write(f"<li>nmap -sC -sV {ip}</li>")
                html.write(f"<li>nmap -p1-65535 -T4 {ip}</li>")
            else:
                html.write("<li>No nmap commands (DNS resolution failed)</li>")
            html.write("</ul>")
            html.write("</td>\n")
            
            html.write("</tr>\n")
        
        html.write("</table>\n")
        html.write("</body></html>\n")

    log(f"HTML report generated: {report_path}", style=green)

def main():
    parser = argparse.ArgumentParser(
        description="Subdomain Enumeration Script (Python version)",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument("-d", "--domain", help="Domain to enumerate subdomains for", required=True)
    parser.add_argument("-v", "--verbose", help="Show tool output in real-time", action="store_true")
    parser.add_argument("-b", "--bruteforce", help="Enable bruteforce enumeration modes", action="store_true")
    parser.add_argument("-r", "--report", help="Generate HTML report (screenshots, IPs, nmap commands)", action="store_true")
    args = parser.parse_args()

    banner()

    # Normalize domain (in case someone includes http/https)
    parsed = urlparse(args.domain)
    if parsed.scheme and parsed.netloc:
        domain = parsed.netloc
    else:
        domain = args.domain

    # Validate domain
    if not validate_domain(domain):
        log(f"ERROR: Invalid domain format: {domain}", style=red)
        exit(1)

    log(f"Enumerating subdomains for domain: {domain}")
    log(f"Bruteforce mode: {args.bruteforce} | Report mode: {args.report} | Verbose mode: {args.verbose}")
    domain_dir = prepare_directory(domain)

    # Count dots to handle domain expansions if needed
    countdots = domain.count(".")
    # Optional advanced logic if you have specific TLD or domain-part handling
    # domain1, domain2, extension, etc. if you want to replicate exactly the original logic

    # Tools - paths might need adjusting to your environment
    # Amass
    amass_cmd = f"/root/go/bin/amass enum -d {domain} -v -o {os.path.join(domain_dir, 'amass.txt')}"
    run_tool("Amass", amass_cmd, args.verbose)

    # Amass (Bruteforce) if requested
    if args.bruteforce:
        amass_brute_cmd = f"/root/go/bin/amass enum -brute -d {domain} -v -o {os.path.join(domain_dir, 'amass_bruteforce.txt')}"
        run_tool("Amass (Bruteforce)", amass_brute_cmd, args.verbose)

    # DNSRecon (bruteforce mode)
    if args.bruteforce:
        dnsrecon_cmd = (
            f"dnsrecon -d {domain} -t brt "
            f"-D /root/SubdomainEnum/files/subdomains.txt "
            f"-x {os.path.join(domain_dir, 'dnsrecon.txt')}"
        )
        run_tool("DNSRecon", dnsrecon_cmd, args.verbose)

    # Findomain
    findomain_cmd = f"findomain -t {domain} --external-subdomains -v -u {os.path.join(domain_dir, 'findomain.txt')}"
    run_tool("Findomain", findomain_cmd, args.verbose)

    # Knock
    if args.bruteforce:
        knock_cmd = (
            f"knockpy -d {domain} --recon --bruteforce "
            f"--wordlist /root/SubdomainEnum/files/subdomains.txt --json > {os.path.join(domain_dir, 'knock.txt')}"
        )
        run_tool("Knock", knock_cmd, args.verbose)

    # Shuffledns
    if args.bruteforce:
        shuffle_cmd = (
            f"/root/go/bin/shuffledns -d {domain} -v -mode bruteforce "
            f"-w /root/SubdomainEnum/files/subdomains.txt "
            f"-r /root/SubdomainEnum/files/resolvers.txt "
            f"-o {os.path.join(domain_dir, 'shuffledns.txt')}"
        )
        run_tool("Shuffledns", shuffle_cmd, args.verbose)

    # Subfinder
    if args.bruteforce:
        subfinder_cmd = f"/root/go/bin/subfinder -d {domain} -all -v -o {os.path.join(domain_dir, 'subfinder.txt')}"
    else:
        subfinder_cmd = f"/root/go/bin/subfinder -d {domain} -v -o {os.path.join(domain_dir, 'subfinder.txt')}"
    run_tool("Subfinder", subfinder_cmd, args.verbose)

    # Sublist3r
    if args.bruteforce:
        sublist3r_cmd = f"sublist3r -d {domain} -v -b -o {os.path.join(domain_dir, 'sublist3r.txt')}"
    else:
        sublist3r_cmd = f"sublist3r -d {domain} -v -o {os.path.join(domain_dir, 'sublist3r.txt')}"
    run_tool("Sublist3r", sublist3r_cmd, args.verbose)

    # Merge & deduplicate
    log("Merging results...", style=cyan)
    all_subdomains = merge_results(domain_dir)
    merged_path = os.path.join(domain_dir, "results_merged.tmp")
    log(f"Merged results stored in: [bold]{merged_path}[/bold]", style=green)
    log(f"Unique subdomain count: {len(all_subdomains)}", style=green)

    # If user wants a report, do it
    if args.report:
        resolve_and_screenshot(all_subdomains, domain, domain_dir, args.verbose)

    log("Subdomain enumeration script finished!", style=cyan)

if __name__ == "__main__":
    main()