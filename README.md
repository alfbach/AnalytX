# AnalytiX

AnalytiX is a local web application that turns **VMware inventory exports** (RVTools `.xlsx` / `.xlsm`) into a **Word (`.docx`) report**, with an in-browser preview and download. Processing runs on your machine; no data is sent to external services by this stack.

---

## Disclaimer (important)

**This software is provided “as is”, without support and without warranty of any kind**, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and noninfringement.

**You use AnalytiX entirely at your own risk.** The authors and contributors are not liable for any damage, data loss, security issues, or incorrect results arising from the use or inability to use this software. You are responsible for validating outputs (including generated reports) before relying on them in production or compliance contexts.

---

## License

This program is **free software**: you can redistribute it and/or modify it under the terms of the **GNU General Public License as published by the Free Software Foundation, either version 2 of the License, or (at your option) any later version**.

This program is distributed in the hope that it will be useful, **but without any warranty**; without even the implied warranty of **merchantability** or **fitness for a particular purpose**. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see [https://www.gnu.org/licenses/old-licenses/gpl-2.0.html](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html).

If you distribute modified versions, you must comply with the GPL-2.0 obligations (including making corresponding source available under the same license where required).

The **verbatim GPL-2.0 license text** for this project is in the repository file **`LICENSE`** (includes SPDX identifier and copyright notice).

---

## Publishing to GitHub

1. Do **not** commit `.venv/` or other ignored paths (see **`.gitignore`**).
2. Ensure no secrets, customer data, or personal paths are in the tree.
3. Recommended first push:

   ```bash
   git init
   git add .
   git status   # review
   git commit -m "Initial import: AnalytiX"
   git branch -M main
   git remote add origin https://github.com/<your-org>/<your-repo>.git
   git push -u origin main
   ```

4. On GitHub, set the repository **license** to **GPL-2.0** if it is not detected automatically from `LICENSE`.

---

## Requirements

- **Python 3.10+**
- Network access only as needed for **pip** (first install). The app itself listens on **127.0.0.1** by default.

On Linux, you may need your distribution’s **venv** package (e.g. `python3-venv`) so that `python3 -m venv` works.

---

## Quick start

### Windows

1. Install Python 3 and ensure `python` or the **py** launcher is on your `PATH`.
2. From the project root, run **`windows\Install-and-Start.bat`** (installs dependencies into `.venv` and starts the server).
3. Open **http://127.0.0.1:8765** in a browser.

Later runs: **`windows\Start-AnalytiX.bat`**.  
Install only (no start): **`windows\Install-only.bat`**, or:

```powershell
powershell -ExecutionPolicy Bypass -File windows\setup.ps1 -NoStart
```

### macOS / Linux

From the project root (make scripts executable once if needed: `chmod +x unix/*.sh start.sh`):

```bash
./unix/install-and-start.sh
```

Then open **http://127.0.0.1:8765**.

Later runs:

```bash
./unix/start-analytiX.sh
# or:
./start.sh
```

Install only:

```bash
./unix/install-only.sh
```

---

## Manual run (without helper scripts)

```bash
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python analytx_server.py
```

---

## Command-line report generator

The core pipeline can still be run from the shell (folder of `.xlsx` / `.xlsm` files):

```bash
python analytx_report.py /path/to/folder [output.docx]
```

---

## Project layout (high level)

| Path | Role |
|------|------|
| `analytx_server.py` | FastAPI app and `/api/convert` |
| `analytx_report.py` | Spreadsheet load, validation, DOCX generation |
| `static/index.html` | Web UI |
| `windows/` | Windows setup/start scripts |
| `unix/` | macOS/Linux setup/start scripts |
| `requirements.txt` | Python dependencies |
| `Dockerfile` | Container image for Docker / Kubernetes |
| `k8s/` | Kubernetes Deployment and Service manifests |
| `unix/build-k8s-image.sh` | Build (and optionally push) the container image |
| `build-k8s-image.sh` | Root wrapper for the image build script |

---

## Docker & Kubernetes

Build the image from the project root:

```bash
chmod +x unix/build-k8s-image.sh build-k8s-image.sh   # once
./build-k8s-image.sh
```

With registry tag, push, and Kustomize update:

```bash
./unix/build-k8s-image.sh -t ghcr.io/myorg/analytix:1.0.0 --push --update-kustomize
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File windows\build-k8s-image.ps1 -Tag ghcr.io/myorg/analytix:1.0.0 -Push -UpdateKustomize
```

Manual build (without script):

```bash
docker build -t analytix:latest .
```

Run locally (listens on all interfaces inside the container):

```bash
docker run --rm -p 8765:8765 analytix:latest
```

Open **http://127.0.0.1:8765**.

Deploy to Kubernetes (adjust the image name/tag for your registry):

```bash
docker build -t your-registry/analytix:latest .
docker push your-registry/analytix:latest

# edit k8s/kustomization.yaml → images.newName / newTag, then:
kubectl apply -k k8s/
kubectl port-forward svc/analytix 8765:80
```

Environment variables (optional):

| Variable | Default | Description |
|----------|---------|-------------|
| `ANALYTX_HOST` | `127.0.0.1` | Bind address (`0.0.0.0` in the container image) |
| `ANALYTX_PORT` | `8765` | HTTP port |

---

## No support

This repository is offered **without maintenance, helpdesk, or SLA**. Issues and pull requests may or may not be addressed. **Use at your own risk.**
