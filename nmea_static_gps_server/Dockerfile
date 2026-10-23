FROM alpine:3.24

RUN apk add --no-cache python3 py3-zeroconf

COPY nmea_server.py /usr/bin/

CMD ["nmea_server.py"]
