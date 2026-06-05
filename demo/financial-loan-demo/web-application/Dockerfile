FROM python:3.11-slim

WORKDIR /app

# Copy requirements and install dependencies
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY backend/ ./backend/
COPY static/ ./static/
COPY index.html .
COPY start.sh .

# Expose port (8080 for OpenShift compatibility)
EXPOSE 8080

# Run the application
CMD ["python", "backend/app.py"]
