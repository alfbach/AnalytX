# AnalytiX — container image for Docker / Kubernetes
FROM python:3.12-slim-bookworm

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ANALYTX_HOST=0.0.0.0 \
    ANALYTX_PORT=8765

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY analytx_server.py analytx_report.py LICENSE ./
COPY static/ static/

RUN chown -R nobody:nogroup /app
USER nobody

EXPOSE 8765

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8765/api/version')" || exit 1

CMD ["python", "analytx_server.py"]
