FROM python:3.10-slim as builder
ENV PYTHONUNBUFFERED=1
WORKDIR /opt/app-build-dependencies
COPY backend/requirements.txt /opt/app-build-dependencies/requirements.txt
RUN pip install --no-cache-dir --upgrade pip && pip install --no-cache-dir -r /opt/app-build-dependencies/requirements.txt

FROM python:3.10-slim
ENV PYTHONUNBUFFERED=1
WORKDIR /opt/app
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid 1001 --shell /bin/bash --create-home appuser
COPY --from=builder /usr/local/lib/python3.10/site-packages /usr/local/lib/python3.10/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY backend/src /opt/app/src
COPY backend/tests /opt/app/tests
RUN chown -R appuser:appgroup /opt/app
USER appuser
ENV WORKERS_PER_CORE="1"
ENV MAX_WORKERS=""
ENV WEB_CONCURRENCY=""
ENV HOST="0.0.0.0"
ENV PORT="1163"
ENV APP_MODULE="src.server:app"
ENV LOG_LEVEL="info"
EXPOSE ${PORT}
CMD exec gunicorn --bind ${HOST}:${PORT} --workers ${WEB_CONCURRENCY:-4} --worker-class uvicorn.workers.UvicornWorker ${APP_MODULE} --log-level ${LOG_LEVEL}
