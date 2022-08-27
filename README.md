# Container for ISC-DHCP with a touch of GLASS

## Goal
This project aims to build a full ISC DHCP server with the Web User Interface nammed Glass who provide a convenient way to manage the DHCP server in a single container. The container support amd64 et arm64 architectures. The distribution used to create the container is [Fedora 36]

You can retreive the container on my [Docker HUB]. it's built by a Github Action

## What the script does ?
 - Pull 2 prebuilt containers (isc-dhcp and rsyslog)
 - Pull a fedora 36 container as helper
 - Use a dedicated directory to build the container image
 - Install Git in the helper
 - Install Node.JS and Glass in /opt of the target directory
 - Copy config and service files inside the directory
 - Use the directoy to build the final image


## [ISC-DHCP]

DHCP Server is chrooted in one single directory : /isc-dhcp providing configuration, PID log device and output file for Rsyslog
For more infromation see my helper container used in the dockerfile : [Container for ISC-DHCP]

# [Glass] Features
- Manage DHCP configuration with Snapshot each time we modify the dhcpd.conf (backup)
- Integrated log view with Regex
- Restart DHCP Server
- Provide statistics
- Show active leases
- Monitoring based on thresholds and send alerts

Th default user is glassadmin/glassadmin

## Download

``` sh
git clone https://github.com/vpolaris/isc-dhcp_with_glass.git
cd isc-dhcp_with_glass

```
## Building

The Dockerfile is set to be used by buildkit by Moby

``` sh
sudo docker buildx build --platform linux/amd64,linux/arm64 -t f36:glass -f Dockerfile .
```

## Usage

This sample share the configuration from the hosts and the container.
``` sh
sudo podman run --name glass --net host -d \
--cap-add NET_RAW --cap-add SYS_CHROOT --cap-add SYSLOG \
--volume /etc/dhcp/dhcpd.conf:/isc-dhcpd/etc/dhcpd.conf:ro \
--health-cmd 'CMD-SHELL dhcpd-pools -c /isc-dhcpd/etc/dhcpd.conf -l /isc-dhcpd/leasing/dhcpd.leases || exit 1' \
--health-interval 15m \
--health-start-period 2m \
--restart on-failure \
-t f36:glass
```

## Networking

Expose required port if you don't use the host network (--net host)
| Service  | Port | Protocol |
|:--------:|------|----------|
| DHCP     | 67   | UDP      |
| HTTP     | 3000 | TCP      |

### Firewall rules

For DHCP.

Not so restrictive rule that can be applied easyly.

``` sh
iptables -I INPUT -i $IFACE -p udp --dport 67:68 --sport  67:68 -j ACCEPT
```

Where $IFACE is the network adapter listenning the DHCP server

For more details see .
https://ixnfo.com/en/iptables-rules-for-dhcp.html

For Glass access

You can have a look to the Github owner of Glass.

https://github.com/Akkadius/glass-isc-dhcp#iptables-recommended


![image](https://user-images.githubusercontent.com/73080749/186994264-f84701c9-044b-47e2-81ad-4729d38942e0.png)



[Glass]: https://github.com/Akkadius/glass-isc-dhcp
[ISC-DHCP]: https://www.isc.org/dhcp/
[Docker HUB]: https://hub.docker.com/r/vpolaris/dhcp-glass
[Fedora 36]: https://fedoramagazine.org/announcing-fedora-36/
[Container for ISC-DHCP]: https://github.com/vpolaris/container_isc-dhcp_f36
