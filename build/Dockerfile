FROM ubuntu:22.04
ARG CONFIG
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash hostapd iptables isc-dhcp-server iproute2 iw rfkill gettext-base && \
    rm -rf /var/lib/apt/lists/* && \
    echo "" > /var/lib/dhcp/dhcpd.leases
ADD ${CONFIG} /etc/hostapd.conf
ADD scripts/start.sh /bin/start.sh
RUN chmod +x /bin/start.sh
ENTRYPOINT [ "/bin/bash", "/bin/start.sh"]
CMD []
