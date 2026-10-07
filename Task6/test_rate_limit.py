import argparse
import time
import urllib.error
import urllib.request


def status(url):
    request = urllib.request.Request(url, headers={"Connection": "close"})
    try:
        with urllib.request.urlopen(request, timeout=5) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    args = parser.parse_args()
    started = time.monotonic()
    accepted = []
    rejected = 0

    for attempt in range(68):
        elapsed = time.monotonic() - started
        code = status(args.url)
        print(f"{elapsed:06.2f}s request={attempt + 1:02d} status={code}", flush=True)
        if code == 200:
            accepted.append(elapsed)
            in_window = [stamp for stamp in accepted if elapsed - stamp < 60]
            assert len(in_window) <= 10, "More than 10 accepted requests within 60s"
        elif code == 429:
            rejected += 1
        else:
            raise AssertionError(f"Unexpected response {code}: backend must return 200")
        if attempt == 0:
            assert code == 200, "The first request must reach the backend"
        if attempt == 1:
            assert code == 429, "A burst must not be accepted"
        if attempt < 67:
            time.sleep(1)

    assert len(accepted) >= 8, "The limiter must recover capacity over time"
    assert rejected > 0, "No HTTP 429 responses observed"
    print(f"PASS: accepted={len(accepted)}, rejected={rejected}; max 10 per rolling 60s")


if __name__ == "__main__":
    main()
