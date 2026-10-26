#!/usr/bin/env python3
import sys
import json
import subprocess
import urllib.request
import urllib.parse
import time
import re

def main():
    try:
        input_data = json.load(sys.stdin)
    except Exception:
        input_data = {}

    gateway_ip = input_data.get("gateway_ip", "")
    region = input_data.get("region", "us-east-1")
    vpc_endpoint = input_data.get("vpc_endpoint", "")
    vm_name = input_data.get("vm_name", "source-vm")
    zone = input_data.get("zone", "us-central1-a")
    project = input_data.get("project", "")

    url = f"http://{gateway_ip}/?activationRegion={region}&vpcEndpoint={vpc_endpoint}"

    # 1. Try direct HTTP GET first (in case running on a host with direct route to VPC)
    try:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=3) as resp:
            loc = resp.geturl()
            match = re.search(r"activationKey=([A-Z0-9-]+)", loc)
            if match:
                print(json.dumps({"activation_key": match.group(1)}))
                return
    except Exception:
        pass

    # 2. If direct access fails, fetch through GCP source-vm across the HA VPN
    cmd = [
        "gcloud", "compute", "ssh", vm_name,
        f"--zone={zone}",
        f"--project={project}",
        "--command",
        f"curl -s -i --max-time 5 '{url}'"
    ]

    max_attempts = 36  # Retry up to 3 minutes for VPN / instance readiness
    for attempt in range(max_attempts):
        try:
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=15)
            output = res.stdout
            match = re.search(r"activationKey=([A-Z0-9-]+)", output)
            if match:
                print(json.dumps({"activation_key": match.group(1)}))
                return
        except Exception:
            pass
        time.sleep(5)

    print(json.dumps({"error": f"Failed to retrieve activation key from {gateway_ip}"}))
    sys.exit(1)

if __name__ == "__main__":
    main()

