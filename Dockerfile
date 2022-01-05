# first stage to build
FROM debian:11-slim AS builder
MAINTAINER Arpad Kunszt <arpad.kunszt@syrius-software.hu>

# versions to build - usually the same
ENV SOGO_VERSION=5.4.0 SOPE_VERSION=5.4.0
ENV LIBWBXML2_VERSION=0.11.6-1
ENV DEBIAN_FRONTEND=noninteractive

# set the working directory
WORKDIR /root

# create an "output" directory
RUN mkdir /packages

# configure apt and update the base
RUN echo 'APT::Install-Recommends "false";' >> /etc/apt/apt.conf && \
	echo 'APT::Install-Suggests "false";' >> /etc/apt/apt.conf && \
	apt update && \
	apt -y upgrade

# install required packages for the build
RUN apt -y install \
	build-essential \
	curl \
	debhelper \
	devscripts \
	git \
	gnustep-make \
	libcurl4 \
	libcurl4-gnutls-dev \
	libexpat1-dev \
	libgnustep-base-dev \
	liblasso3-dev \
	libldap2-dev \
	libmariadbclient-dev-compat \
	libmemcached-dev \
	liboath-dev \
	libpopt-dev \
	libpq-dev \
	libsbjson2.3 \
	libsbjson-dev \
	libsodium-dev \
	libssl-dev \
	libytnef0-dev \
	libzip-dev \
	make \
	python \
	wget \
	zip \
	zlib1g-dev

# install libwbxml2
RUN curl -sO https://packages.inverse.ca/SOGo/nightly/5/debian/pool/bullseye/w/wbxml2/libwbxml2-dev_${LIBWBXML2_VERSION}_amd64.deb && \
	curl -sO https://packages.inverse.ca/SOGo/nightly/5/debian/pool/bullseye/w/wbxml2/libwbxml2-0_${LIBWBXML2_VERSION}_amd64.deb && \
	dpkg -i libwbxml2*deb && \
	apt -fy install && \
	mv -v libwbxml2*deb /packages

# configure git - make it less noisy
RUN git config --global --add advice.detachedHead false

# clone repositories
RUN git clone --depth 1 --branch "SOPE-$SOPE_VERSION" https://github.com/inverse-inc/sope.git
RUN git clone --depth 1 --branch "SOGo-$SOGO_VERSION" https://github.com/inverse-inc/sogo.git

# build SOPE
WORKDIR /root/sope
RUN cp -av packaging/debian debian && ./debian/rules
RUN dpkg-checkbuilddeps && dpkg-buildpackage
RUN dpkg -i ../libsope*.deb
RUN mv -v ../*.deb /packages

WORKDIR /root/sogo
RUN cp -av packaging/debian debian
# is it really necessary?
RUN dch --newversion "$SOGO_VERSION" "Automated build for version $SOGO_VERSION"
RUN ./debian/rules
RUN dpkg-checkbuilddeps && dpkg-buildpackage -b
RUN mv -v ../*.deb /packages

# second stage - use the images built in the first stage
FROM debian:11-slim
MAINTAINER Arpad Kunszt <arpad.kunszt@syrius-software.hu>

# ugly workaround to let the sogo package configuration finish
RUN mkdir -p /usr/share/doc/sogo && touch /usr/share/doc/sogo/skip.sh && chmod 0750 /usr/share/doc/sogo/skip.sh

# create user and group to fix the UID and GID
RUN groupadd -g 842 -r sogo
RUN useradd -c "SOGo daemon" -d /var/lib/sogo -g sogo -M -N -r -s /usr/sbin/nologin -u 842 sogo

# configure apt and update the base
RUN echo 'APT::Install-Recommends "false";' >> /etc/apt/apt.conf && \
	echo 'APT::Install-Suggests "false";' >> /etc/apt/apt.conf && \
	apt update && \
	apt -y upgrade

COPY --from=builder /packages /packages/
RUN apt -y install \
	/packages/libsope-appserver4.9_*deb \
	/packages/libsope-core4.9_*deb \
	/packages/libsope-gdl1-4.9_*deb \
	/packages/libsope-ldap4.9_*deb \
	/packages/libsope-mime4.9_*deb \
	/packages/libsope-xml4.9_*deb \
	/packages/libwbxml2-0_*deb \
	/packages/sogo_*deb \
	/packages/sogo-activesync_*deb \
	/packages/sope4.9-gdl1-postgresql_*deb \
	/packages/sope4.9-libxmlsaxdriver_*deb

USER sogo:sogo
COPY --chown=sogo:sogo files/start.sh /

ENTRYPOINT [ "/start.sh" ]
