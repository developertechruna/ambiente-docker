# Dockerfile para ViniPlay con parches de subpath (/viniplay) y compatibilidad VOD
FROM docker.io/ardovini/viniplay:latest

WORKDIR /usr/src/app

COPY viniplay-subpath.patch /tmp/viniplay-subpath.patch

RUN apt-get update && apt-get install -y --no-install-recommends patch && \
    patch -p1 < /tmp/viniplay-subpath.patch && \
    rm /tmp/viniplay-subpath.patch && \
    apt-get purge -y patch && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

EXPOSE 8998

CMD ["npm", "start"]
