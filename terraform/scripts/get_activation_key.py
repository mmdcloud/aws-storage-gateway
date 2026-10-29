#!/usr/bin/env python3
import sys
import json
import subprocess
import time
import re
import urllib.request
import urllib.error

KEY_RE = re.compile(r"activationKey=([A-Z0-9-]+)", re.IGNORECASE)
BODY_RE = re.compile(r"\b([A-Z0-9]{5}(?:-[A-Z0-9]{5}){4})\b")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **kw):
        return None  # Surface 302 response instead of following redirect


def extract(text):
    if not text:
        return None
    m = KEY_RE.search(text) or BODY_RE.search(text)
    return m.group(1) if m else None


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def main():
    try:
        d = json.load(sys.stdin)
    except Exception:
        d = {}

    ip = d.get("gateway_ip", "")
    region = d.get("region", "us-east-1")
    vpce = d.get("vpc_endpoint", "")
    vm = d.get("vm_name", "source-vm")
    zone = d.get("zone", "us-central1-a")
    project = d.get("project", "")
    gateway_name = d.get("gateway_name", "gcp-vm-file-gateway")

    # 1. Fast-path: Check if the gateway is already active in AWS Storage Gateway
    # If the gateway is already active, port 80 will no longer serve an activation key.
    # Returning a sentinel value allows Terraform refresh, plan, and destroy to proceed instantly.
    try:
        sgw_cmd = ["aws", "storagegateway", "list-gateways", f"--region={region}", "--output=json"]
        sgw_res = subprocess.run(sgw_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=6)
        if sgw_res.returncode == 0:
            data = json.loads(sgw_res.stdout)
            for gw in data.get("Gateways", []):
                if gw.get("GatewayName") == gateway_name and gw.get("GatewayOperationalState") == "ACTIVE":
                    log(f"Storage Gateway '{gateway_name}' is already ACTIVE. Bypassing activation key lookup.")
                    print(json.dumps({"activation_key": "ALREADY_ACTIVATED"}))
                    return
    except Exception as e:
        log(f"aws list-gateways check skipped: {e}")

    # If ip or vpce are not set (e.g. during certain destroy/plan phases)
    if not ip or not vpce:
        print(json.dumps({"activation_key": "NONE"}))
        return

    url_primary = f"http://{ip}/?gatewayType=FILE_S3&activationRegion={region}&vpcEndpoint={vpce}"
    url_noredirect = f"http://{ip}/?gatewayType=FILE_S3&activationRegion={region}&vpcEndpoint={vpce}&no_redirect"

    # 2. Direct attempt (if Terraform runner is on the VPC / VPN)
    for test_url in [url_primary, url_noredirect]:
        try:
            opener = urllib.request.build_opener(NoRedirect)
            try:
                resp = opener.open(test_url, timeout=3)
                content = str(resp.headers) + " " + resp.read().decode(errors="ignore")
            except urllib.error.HTTPError as e:
                content = str(e.headers) + " " + e.read().decode(errors="ignore")
            key = extract(content)
            if key:
                print(json.dumps({"activation_key": key}))
                return
        except Exception:
            pass

    # 3. Remote attempt via GCP source-vm over the HA VPN
    # Storage Gateway EC2 boot + IPsec negotiation + BGP peering typically takes 1.5 - 2.5 minutes on fresh apply.
    max_attempts = 45  # 45 * 4s = ~3 minutes max
    last_out, last_err = "", ""

    for attempt in range(max_attempts):
        for test_url in [url_primary, url_noredirect]:
            cmd = [
                "gcloud", "compute", "ssh", vm,
                f"--zone={zone}", f"--project={project}",
                "--quiet", "--strict-host-key-checking=no",
                "--command", f"curl -s -i --max-time 8 '{test_url}'"
            ]
            try:
                r = subprocess.run(
                    cmd,
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    timeout=15
                )
                last_out, last_err = r.stdout, r.stderr
                key = extract(r.stdout)
                if key:
                    log(f"Activation key successfully retrieved on attempt {attempt}: {key}")
                    print(json.dumps({"activation_key": key}))
                    return
            except Exception as e:
                last_err = str(e)

        if attempt % 5 == 0:
            log(f"Waiting for gateway/VPN readiness... (attempt {attempt}/{max_attempts})")
        time.sleep(4)

    log(f"Timed out waiting for activation key from {ip}. Last output: {last_out[:300]} / Error: {last_err[-300:]}")
    print(json.dumps({"activation_key": "FAILED_TO_RETRIEVE"}))


if __name__ == "__main__":
    main()
