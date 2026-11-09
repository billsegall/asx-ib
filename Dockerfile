FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    xvfb \
    x11vnc \
    x11-utils \
    supervisor \
    wget \
    unzip \
    socat \
    telnet \
    curl \
    gettext-base \
    libxtst6 \
    libxrender1 \
    libxi6 \
    x11-apps \
    xdotool \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Install IB Gateway to /usr/local/ibgateway. The directory must be given:
# the installer's default has changed (10.52 installs to /root/ibgateway).
ARG IB_GATEWAY_URL=https://download2.interactivebrokers.com/installers/ibgateway/latest-standalone/ibgateway-latest-standalone-linux-x64.sh
RUN wget -q "${IB_GATEWAY_URL}" -O /tmp/ibgateway.sh \
    && chmod +x /tmp/ibgateway.sh \
    && xvfb-run --auto-servernum /tmp/ibgateway.sh -q -dir /usr/local/ibgateway \
    && rm /tmp/ibgateway.sh

# Store IBC-compatible major version in /etc (outside the settings volume).
# The entrypoint recreates the versioned symlink after the volume is mounted.
RUN GW_VER=$(sed -n 's/.*IB Gateway \([0-9.]*\).*/\1/p' /usr/local/ibgateway/ibgateway.vmoptions | head -1) \
    && MAJOR_VER=$(echo "${GW_VER}" | tr -d '.') \
    && [ -n "${MAJOR_VER}" ] || { echo "IB Gateway version not found"; exit 1; } \
    && echo "${MAJOR_VER}" > /etc/ibgateway_version \
    && echo "IB Gateway ${GW_VER} (IBC major version: ${MAJOR_VER})"

# Install IBC (3.24.2+ is needed for Gateway 10.48 onwards). The release zip
# is kept in vendor/: GitHub's release download link has been unreliable.
ARG IBC_VERSION=3.24.2
ARG IBC_SHA256=cc097ca1dfa75413a5fbe02e4743050af15f3308eb6a97c769b3cff9850c80c5
COPY vendor/IBCLinux-${IBC_VERSION}.zip /tmp/ibc.zip
RUN echo "${IBC_SHA256}  /tmp/ibc.zip" | sha256sum -c - \
    && unzip -q /tmp/ibc.zip -d /opt/ibc \
    && chmod +x /opt/ibc/*.sh /opt/ibc/scripts/*.sh \
    && rm /tmp/ibc.zip \
    && ln -s /bin/telnet /usr/local/bin/telnet

# Copy configuration and scripts
COPY config/ /config/
COPY scripts/ /scripts/
COPY supervisord.conf /etc/supervisor/conf.d/ibc.conf

RUN chmod +x /scripts/*.sh \
    && mkdir -p /var/log/ibc /var/log/supervisor /root/.vnc

EXPOSE 4001 4002 5900

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
    CMD /scripts/healthcheck.sh

ENTRYPOINT ["/scripts/entrypoint.sh"]
