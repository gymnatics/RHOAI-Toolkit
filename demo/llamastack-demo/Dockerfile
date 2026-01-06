# Use Red Hat UBI9 Python image for OpenShift compatibility
FROM registry.redhat.io/ubi9/python-312:latest

WORKDIR /opt/app-root/src

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app
COPY app.py .

# Make directory writable for OpenShift's arbitrary UID
USER 0
RUN chmod -R g+rwX /opt/app-root/src && \
    chgrp -R 0 /opt/app-root/src
USER 1001

EXPOSE 8501

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8501/_stcore/health || exit 1

# Run Streamlit
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0", "--server.headless=true", "--browser.gatherUsageStats=false"]

