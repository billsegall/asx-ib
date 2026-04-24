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
    curl \
    gettext-base \
    libxtst6 \
    libxrender1 \
    libxi6 \
    && rm -rf /var/lib/apt/lists/*

# Install IB Gateway (quiet mode installs to /usr/local/ibgateway)
ARG IB_GATEWAY_URL=https://download2.interactivebrokers.com/installers/ibgateway/latest-standalone/ibgateway-latest-standalone-linux-x64.sh
RUN wget -q "${IB_GATEWAY_URL}" -O /tmp/ibgateway.sh \
    && chmod +x /tmp/ibgateway.sh \
    && xvfb-run --auto-servernum /tmp/ibgateway.sh -q \
    && rm /tmp/ibgateway.sh

# Store IBC-compatible major version in /etc (outside the settings volume).
# The entrypoint recreates the versioned symlink after the volume is mounted.
RUN GW_VER=$(sed -n 's/.*IB Gateway \([0-9.]*\).*/\1/p' /usr/local/ibgateway/ibgateway.vmoptions | head -1) \
    && MAJOR_VER=$(echo "${GW_VER}" | tr -d '.') \
    && echo "${MAJOR_VER}" > /etc/ibgateway_version \
    && echo "IB Gateway ${GW_VER} (IBC major version: ${MAJOR_VER})"

# Install IBC
ARG IBC_VERSION=3.23.0
RUN wget -q "https://github.com/IbcAlpha/IBC/releases/download/${IBC_VERSION}/IBCLinux-${IBC_VERSION}.zip" \
    -O /tmp/ibc.zip \
    && unzip -q /tmp/ibc.zip -d /opt/ibc \
    && chmod +x /opt/ibc/*.sh /opt/ibc/scripts/*.sh \
    && rm /tmp/ibc.zip

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
