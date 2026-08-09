FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG UID=1000
ARG GID=1000

# Ubuntu 22.04 (Jammy) is deliberately used because Garmin's SDK Manager
# dynamically links against WebKitGTK 4.0 and JavaScriptCoreGTK 4.0, which
# newer Ubuntu/Debian releases no longer provide.
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        dbus-x11 \
        file \
        libcurl4 \
        libjavascriptcoregtk-4.0-18 \
        libjpeg-turbo8 \
        libsecret-1-0 \
        libusb-1.0-0 \
        libwebkit2gtk-4.0-37 \
        libx11-6 \
        libxext6 \
        libxxf86vm1 \
        openjdk-17-jre-headless \
        openssl \
        xvfb \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${GID}" ciq \
    && useradd --uid "${UID}" --gid "${GID}" --create-home --shell /bin/bash ciq \
    && mkdir --parents /workspace \
    && chown ciq:ciq /workspace

COPY docker/ciq-entrypoint.sh /usr/local/bin/ciq-entrypoint
RUN chmod +x /usr/local/bin/ciq-entrypoint

WORKDIR /workspace
ENV HOME=/home/ciq
ENV XDG_CONFIG_HOME=/home/ciq/.config
ENV XDG_CACHE_HOME=/home/ciq/.cache
ENTRYPOINT ["/usr/local/bin/ciq-entrypoint"]
CMD ["bash"]
