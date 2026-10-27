FROM python:3.11-slim

ARG PIP_INDEX_URL

WORKDIR /app

# Install only the reviewed versions, using the configured package index.
COPY pyproject.toml uv.lock ./
RUN pip install --no-cache-dir uv==0.7.20 \
    && uv export --frozen --no-dev --no-emit-project --output-file /tmp/requirements.txt \
    && pip install --no-cache-dir --require-hashes --no-deps -r /tmp/requirements.txt \
    && pip check \
    && rm /tmp/requirements.txt

# Copy source
COPY src/ ./src/

# Expose port
EXPOSE 8000

# Run server
CMD ["python", "-m", "src.server"]
