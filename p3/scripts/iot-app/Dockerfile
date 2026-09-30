FROM python:3.9-alpine

WORKDIR /app
COPY server.py .

RUN adduser -D appuser
USER appuser

EXPOSE 8888
CMD ["python", "server.py"]