#!/usr/bin/env python3
"""
Extract DNS-related RFC numbers from https://www.ietf.org/rfc/rfc-index.txt
and download their TXT versions from https://www.rfc-editor.org/rfc/

Outputs:
  - dns-rfcs.txt       (RFC number list, icann/rfc-annotations compatible)
  - raw-originals/     (downloaded TXT files)
"""

import re
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

# --- Configuration ---
RFC_INDEX_URL   = "https://www.ietf.org/rfc/rfc-index.txt"
RFC_BASE_URL    = "https://www.rfc-editor.org/rfc"
OUTPUT_FILE     = "dns-rfcs.txt"
DOWNLOAD_DIR    = Path("raw-originals")
MAX_WORKERS     = 8       # concurrent downloads
RETRY_ATTEMPTS  = 3
RETRY_DELAY     = 2.0     # seconds between retries
REQUEST_TIMEOUT = 30      # seconds

DNS_KEYWORDS = [
    r"\bDNS\b",
    r"\bDNSSEC\b",
    r"\bdomain name",
    r"\bname server",
    r"\bnameserver",
    r"\bresolver\b",
    r"\bzone transfer",
    r"\bDNS-SD\b",
    r"\bmDNS\b",
    r"\bmulticast DNS",
    r"\bDoH\b",
    r"\bDoT\b",
    r"\bDNS over",
    r"\bDANE\b",
    r"\bTLSA\b",
    r"\bNSEC\b",
    r"\bDNSKEY\b",
    r"\bRRSIG\b",
    r"\bEDNS\b",
]

DNS_PATTERN = re.compile("|".join(DNS_KEYWORDS), re.IGNORECASE)

# --- RFC Index Fetching & Parsing ---

def fetch_url(url: str, timeout: int = REQUEST_TIMEOUT) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "rfc-dns-fetcher/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", errors="replace")

def parse_rfc_entries(text: str) -> list[dict]:
    """Reassemble multi-line RFC index entries into single records."""
    entries = []
    current = []

    for line in text.splitlines():
        if re.match(r"^\d{4} ", line):
            if current:
                entries.append(" ".join(current))
            current = [line.strip()]
        elif current and line.startswith(" "):
            current.append(line.strip())

    if current:
        entries.append(" ".join(current))

    result = []
    for entry in entries:
        m = re.match(r"^(\d{4})\s+(.*)", entry)
        if m:
            result.append({"number": int(m.group(1)), "text": m.group(2)})
    return result

def extract_title(text: str) -> str:
    m = re.match(r"^(.*?)\.\s+[A-Z][a-z]?\.", text)
    return m.group(1) if m else text.split(".")[0]

def is_dns_related(entry: dict) -> bool:
    return bool(DNS_PATTERN.search(extract_title(entry["text"])))

# --- Downloading ---

def download_rfc(number: int, dest_dir: Path, force: bool = False) -> tuple[int, str]:
    """
    Download rfcNNNN.txt to dest_dir.
    Returns (number, status) where status is 'ok', 'skipped', or 'error: ...'
    """
    filename = dest_dir / f"rfc{number}.txt"

    if filename.exists() and not force:
        return number, "skipped"

    url = f"{RFC_BASE_URL}/rfc{number}.txt"

    for attempt in range(1, RETRY_ATTEMPTS + 1):
        try:
            content = fetch_url(url)
            filename.write_text(content, encoding="utf-8")
            return number, "ok"
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return number, f"error: 404 not found"
            if attempt < RETRY_ATTEMPTS:
                time.sleep(RETRY_DELAY * attempt)
        except Exception as e:
            if attempt < RETRY_ATTEMPTS:
                time.sleep(RETRY_DELAY * attempt)
            else:
                return number, f"error: {e}"

    return number, f"error: max retries exceeded"

def download_all(rfc_numbers: list[int], dest_dir: Path, force: bool = False) -> dict:
    dest_dir.mkdir(parents=True, exist_ok=True)
    results = {}
    total = len(rfc_numbers)

    print(f"\nDownloading {total} RFCs to {dest_dir}/ (workers={MAX_WORKERS}) ...")

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        futures = {pool.submit(download_rfc, n, dest_dir, force): n for n in rfc_numbers}
        done = 0
        for future in as_completed(futures):
            number, status = future.result()
            results[number] = status
            done += 1
            symbol = "✓" if status == "ok" else "–" if status == "skipped" else "✗"
            print(f"  [{done:3d}/{total}] {symbol} RFC{number:04d}  {status}")

    return results

# --- Main ---

def main():
    import argparse

    parser = argparse.ArgumentParser(description="Find DNS RFCs and download their TXT files.")
    parser.add_argument("--output",     default=OUTPUT_FILE,        help="RFC list output file")
    parser.add_argument("--dest",       default=str(DOWNLOAD_DIR),  help="Download directory")
    parser.add_argument("--workers",    type=int, default=MAX_WORKERS, help="Concurrent downloads")
    parser.add_argument("--force",      action="store_true",         help="Re-download existing files")
    parser.add_argument("--list-only",  action="store_true",         help="Only generate list, skip download")
    parser.add_argument("--skip-list",  action="store_true",         help="Only download (reuse existing list)")
    args = parser.parse_args()

    dest_dir = Path(args.dest)
    output   = Path(args.output)

    # Step 1: Build DNS RFC list
    if not args.skip_list:
        print(f"Fetching RFC index from {RFC_INDEX_URL} ...")
        raw = fetch_url(RFC_INDEX_URL)

        entries = parse_rfc_entries(raw)
        print(f"Parsed {len(entries)} RFC entries")

        dns_entries = [e for e in entries if is_dns_related(e)]
        dns_numbers = sorted(e["number"] for e in dns_entries)
        print(f"Found {len(dns_numbers)} DNS-related RFCs")

        output.write_text("\n".join(str(n) for n in dns_numbers) + "\n")
        print(f"Written list to {output}")

        for e in dns_entries:
            print(f"  RFC{e['number']:04d}  {extract_title(e['text'])}")
    else:
        if not output.exists():
            print(f"Error: {output} not found. Run without --skip-list first.", file=sys.stderr)
            sys.exit(1)
        dns_numbers = [int(l.strip()) for l in output.read_text().splitlines() if l.strip()]
        print(f"Loaded {len(dns_numbers)} RFC numbers from {output}")

    if args.list_only:
        return

    # Step 2: Download TXT files
    results = download_all(dns_numbers, dest_dir, force=args.force)

    ok      = sum(1 for s in results.values() if s == "ok")
    skipped = sum(1 for s in results.values() if s == "skipped")
    errors  = {n: s for n, s in results.items() if s.startswith("error")}

    print(f"\nSummary: {ok} downloaded, {skipped} skipped, {len(errors)} errors")
    if errors:
        print("Errors:")
        for n, s in sorted(errors.items()):
            print(f"  RFC{n:04d}: {s}")

if __name__ == "__main__":
    main()
