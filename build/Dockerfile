FROM ubuntu:19.10 
ARG CONFIG
RUN apt-get update
RUN apt-get install -y bash hostapd iptables isc-dhcp-server docker iproute2 iw rfkill gettext-base crda wireless-crda
RUN echo "" > /var/lib/dhcp/dhcpd.leases
ADD ${CONFIG} /etc/hostapd.conf
ADD scripts/start.sh /bin/start.sh
RUN chmod +x /bin/start.sh
ENTRYPOINT [ "/bin/bash", "/bin/start.sh"]
CMD []
