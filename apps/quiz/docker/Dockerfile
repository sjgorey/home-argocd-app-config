# Use official Python 3.12 slim image
FROM python:3.12-slim

# Install system dependencies
RUN apt-get update && \
    apt-get install -y sqlite3 && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy app code
COPY app /app/app

# Install Python dependencies
RUN pip install --no-cache-dir fastapi uvicorn pydantic

# Expose port
EXPOSE 8000

# Start the app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
