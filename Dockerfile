FROM itzg/minecraft-server

COPY entrypoint.sh /app/entrypoint.sh
COPY healthcheck.sh /app/healthcheck.sh
COPY .env /app/.env
RUN cd /app && chmod +x /app/*.sh

ENTRYPOINT ["/app/entrypoint.sh"]
