FROM node:20-alpine

LABEL org.opencontainers.image.source="https://github.com/cirodasilvaj/bkstg-made-nodejs-demo22"

WORKDIR /app
COPY package*.json server.js ./

ENV PORT=8080 \
    APP_NAME="bkstg-made-nodejs-demo22" \
    FLUENTD_HOST="fluentd.logging.svc.cluster.local" \
    FLUENTD_PORT="24224"

EXPOSE 8080
CMD ["node", "server.js"]
