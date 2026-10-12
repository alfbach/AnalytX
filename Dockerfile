# AnalytiX — container image for Docker / Podman / Kubernetes / OpenShift
FROM python:3.12-slim-bookworm

WORKDIR /app

# Writable runtime dirs: python-multipart may spool large RVTools uploads to disk;
# OpenShift/K8s often mount a read-only root filesystem.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ANALYTX_HOST=0.0.0.0 \
    ANALYTX_PORT=8765 \
    TMPDIR=/tmp \
    HOME=/tmp \
    XDG_CACHE_HOME=/tmp \
    XDG_CONFIG_HOME=/tmp \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY analytx_server.py analytx_report.py LICENSE ./
COPY static/ static/

# OpenShift restricted SCC assigns an arbitrary UID in the root group (GID 0).
# Keep the image readable/executable for that UID; do not rely on USER nobody.
RUN chgrp -R 0 /app && chmod -R g=u /app

# Non-root default for Docker/Podman; OpenShift may override with a random UID.
USER 65534

EXPOSE 8765

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8765/api/version')" || exit 1

CMD ["python", "analytx_server.py"]
