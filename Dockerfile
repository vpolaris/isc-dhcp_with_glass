#How to set ARCH variable for mutli-arch building
#https://medium.com/@tonistiigi/advanced-multi-stage-build-patterns-6f741b852fae
ARG ARCH
ARG sysroot=/mnt/sysroot
FROM vpolaris/rsyslog:8.2204.0-2.fc36 as rsyslog
FROM vpolaris/isc-dhcpd:4.4.3-2.fc36 as isc-dhcp
FROM fedora:36 as builder
ARG sysroot
ARG DISTVERSION=36
ARG DNFOPTION="--setopt=install_weak_deps=False --nodocs"

#install system

COPY --from=rsyslog / ${sysroot}
COPY --from=isc-dhcp / ${sysroot}

#Glass prerequisites
RUN dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION} install --downloadonly --downloaddir=./ dhcpd-pools


#Used by glass to show statistic
RUN ARCH="$(uname -m)" \
    && POOLRPM="$(ls dhcpd-pools*${ARCH}.rpm)" \
    && rpm -ivh --root=${sysroot}  --nodeps --excludedocs ${POOLRPM}


#install Git

RUN dnf -y install git 

FROM builder as builder-arm64
ARG ARCH=arm64
FROM builder as builder-amd64
ARG ARCH=x64

FROM builder-${TARGETARCH} as glass
ARG sysroot
#install nodejs
ARG NODE_VERSION=16.16.0
ARG NODE_PACKAGE=node-v$NODE_VERSION-linux-${ARCH}
ARG NODE_HOME=${sysroot}/opt/$NODE_PACKAGE

ENV NODE_PATH $NODE_HOME/lib/node_modules
ARG BKPATH=$PATH
ENV PATH $NODE_HOME/bin:$PATH
RUN mkdir -p ${sysroot}/opt/glass-isc-dhcp  \
    && curl https://nodejs.org/dist/v$NODE_VERSION/$NODE_PACKAGE.tar.gz | tar -xzC  ${sysroot}/opt/ \
    && npm install --location=global npm@8

# install Glass 
RUN cd ${sysroot}/opt \
    && git clone https://github.com/Akkadius/glass-isc-dhcp.git \
    && cd glass-isc-dhcp \
    && mkdir logs \
    && chmod u+x ./bin/ -R \
    && chmod u+x *.sh \
    && npm install

COPY "./glass-gui.service" "${sysroot}/etc/rc.d/init.d/glass-gui.service"
COPY "./service" "${sysroot}/sbin/service"
 
RUN chmod +x "${sysroot}/etc/rc.d/init.d/glass-gui.service" "${sysroot}/sbin/service"

# adjust Glass settings
RUN cd "${sysroot}/opt/glass-isc-dhcp" \
    && sed -i 's!\"/var/lib/dhcp/dhcpd.leases\"!\"/isc-dhcpd/leasing/dhcpd.leases\"!1' ./config/glass_config.json \
    && sed -i 's!\"/var/log/dhcp.log\"!\"/isc-dhcpd/log/dhcp.log\"!1' ./config/glass_config.json \
    && sed -i  's!\"/etc/dhcp/dhcpd.conf\"!\"/isc-dhcpd/etc/dhcpd.conf\"!1' ./config/glass_config.json
 
# adjust rsyslog settings to isc-dhcpd chroot
COPY "./rsyslog.conf" "${sysroot}/etc/rsyslog.conf"
RUN if ! [ -f /etc/rsyslog.d ];then mkdir /etc/rsyslog.d;fi \
    && printf "local0.debug      /isc-dhcpd/log/dhcp.log\n" > "${sysroot}/etc/rsyslog.d/35-isc-dhcpd.conf" \
    && mkdir -p "${sysroot}//isc-dhcpd/dev"

#clean up
RUN dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION}  autoremove \    
    && dnf -y --installroot=${sysroot} ${DNFOPTION} --releasever ${DISTVERSION}  clean all \
    && rm -rf ${sysroot}/usr/{{lib,share}/locale,{lib,lib64}/gconv,bin/localedef,sbin/build-locale-archive} \
#  docs and man pages       
    && rm -rf ${sysroot}/usr/share/{man,doc,info,gnome/help} \
#  purge log files
    && rm -f ${sysroot}/var/log/*|| exit 0 \
#  cracklib
    && rm -rf ${sysroot}/usr/share/cracklib \
#  i18n
    && rm -rf ${sysroot}/usr/share/i18n \
#  packaging
    && rm -rf ${sysroot}/var/cache/dnf/ \
    && mkdir -p --mode=0755 ${sysroot}/var/cache/dnf/ \
    && rm -f ${sysroot}//var/lib/dnf/history.* \
    && rm -f ${sysroot}//usr/lib/sysimage/rpm/* \
#  sln
    && rm -rf ${sysroot}/sbin/sln \
#  ldconfig
    && rm -rf ${sysroot}/etc/ld.so.cache ${sysroot}/var/cache/ldconfig \
    && mkdir -p --mode=0755 ${sysroot}/var/cache/ldconfig


FROM scratch 
ARG sysroot
COPY --from=glass "${sysroot}" /
ENV TINI_VERSION v0.19.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENV DISTTAG=f36container FGC=f36 FBR=f36 container=podman
ENV DISTRIB_ID fedora
ENV DISTRIB_RELEASE 36
ENV PLATFORM_ID "platform:f36"
ENV DISTRIB_DESCRIPTION "Fedora 36 Container"
ENV TZ UTC
ENV LANG C.UTF-8
ENV TERM xterm
ARG NODE_VERSION=16.16.0
ARG NODE_PACKAGE=node-v$NODE_VERSION-linux-${ARCH}
ARG NODE_HOME=/opt/$NODE_PACKAGE
ENV NODE_PATH $NODE_HOME/lib/node_modules
ENV PATH $NODE_HOME/bin:$PATH
ENV IPOPT=-4
HEALTHCHECK CMD dhcpd-pools -c /isc-dhcpd/etc/dhcpd.conf -l /isc-dhcpd/leasing/dhcpd.leases || exit 1
EXPOSE 67/udp
ENTRYPOINT ["./tini", "--", "/bin/entrypoint.sh"]
CMD ["start"]