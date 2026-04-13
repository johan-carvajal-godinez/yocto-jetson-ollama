# ==============================================================================
# Yocto Build Container — Jetson Nano + Ollama LLM
# Base: Ubuntu 22.04 LTS (compatible con Yocto Kirkstone/Scarthgap)
# Target: NVIDIA Jetson Nano (tegra210, aarch64)
# ==============================================================================

FROM ubuntu:22.04

LABEL maintainer="Yocto Build System"
LABEL description="Build environment for Jetson Nano Yocto image with Ollama LLM support"
LABEL yocto.version="kirkstone"
LABEL target.board="jetson-nano"

# Evitar prompts interactivos durante la instalación
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# ─── Variables de entorno del build ───────────────────────────────────────────
ENV YOCTO_RELEASE=kirkstone
ENV YOCTO_DIR=/yocto
ENV BUILD_DIR=/yocto/build
ENV DL_DIR=/yocto/downloads
ENV SSTATE_DIR=/yocto/sstate-cache
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANGUAGE=en_US:en

# ─── 1. Dependencias del sistema requeridas por Yocto ─────────────────────────
# Ref: https://docs.yoctoproject.org/ref-manual/system-requirements.html
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    ninja-build \
    # Python (Yocto requiere Python 3.8+)
    python3 \
    python3-pip \
    python3-pexpect \
    python3-jinja2 \
    python3-git \
    python3-subunit \
    python3-distutils \
    python3-setuptools \
    python3-testtools \
    python3-websockets \
    # Control de versiones
    git \
    git-lfs \
    repo \
    # Utilidades de compresión y archivado
    gzip \
    bzip2 \
    xz-utils \
    zstd \
    zip \
    unzip \
    tar \
    cpio \
    lz4 \
    # Herramientas de desarrollo
    diffstat \
    patch \
    texinfo \
    chrpath \
    socat \
    file \
    wget \
    curl \
    rsync \
    # Dependencias de librerías
    libsdl1.2-dev \
    libssl-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libxml2-utils \
    libc6-dev \
    # Locales y encoding
    locales \
    locales-all \
    # Herramientas de terminal y misc
    lsb-release \
    sudo \
    iputils-ping \
    net-tools \
    vim \
    nano \
    tmux \
    screen \
    htop \
    # Dependencias adicionales para meta-tegra
    device-tree-compiler \
    # Java (requerido por algunas recetas)
    default-jre-headless \
    # Para generar imágenes de disco
    parted \
    mtools \
    dosfstools \
    e2fsprogs \
    # Repo y git extras
    python-is-python3 \
    && rm -rf /var/lib/apt/lists/*

# ─── 2. Configurar locale en_US.UTF-8 ────────────────────────────────────────
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8

# ─── 3. Instalar kas (Yocto build tool / configuration manager) ───────────────
RUN pip3 install --no-cache-dir \
    kas==4.3 \
    GitPython \
    PyYAML \
    jsonschema \
    urllib3

# ─── 4. Instalar repo tool (Google) ──────────────────────────────────────────
RUN curl -o /usr/local/bin/repo \
    https://storage.googleapis.com/git-repo-downloads/repo \
    && chmod a+x /usr/local/bin/repo

# ─── 5. Crear usuario no-root para el build (Yocto no corre como root) ────────
RUN groupadd -g 1000 yocto \
    && useradd -m -u 1000 -g yocto -s /bin/bash yocto \
    && echo "yocto ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ─── 6. Crear estructura de directorios con permisos correctos ────────────────
RUN mkdir -p \
    ${YOCTO_DIR} \
    ${BUILD_DIR} \
    ${DL_DIR} \
    ${SSTATE_DIR} \
    /yocto/layers \
    /yocto/meta-custom \
    /home/yocto/.config \
    && chown -R yocto:yocto /yocto /home/yocto

# ─── 7. Configurar git global para el usuario yocto ──────────────────────────
USER yocto
RUN git config --global user.email "yocto@build.local" \
    && git config --global user.name "Yocto Builder" \
    && git config --global http.sslVerify false \
    && git config --global protocol.version 2

# ─── 8. Copiar scripts y configuraciones ──────────────────────────────────────
USER root
COPY --chown=yocto:yocto scripts/ /yocto/scripts/
COPY --chown=yocto:yocto conf/   /yocto/conf-templates/
COPY --chown=yocto:yocto meta-ollama/ /yocto/meta-ollama/

RUN chmod +x /yocto/scripts/*.sh

# ─── 9. Crear script de entrypoint ───────────────────────────────────────────
COPY --chown=root:root docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# ─── 10. Volúmenes para persistencia del estado de build ──────────────────────
# IMPORTANTE: montar estos volúmenes para acelerar builds subsecuentes
VOLUME ["${DL_DIR}", "${SSTATE_DIR}", "${BUILD_DIR}"]

# ─── 11. Variables de entorno finales ────────────────────────────────────────
ENV PATH="/yocto/scripts:${PATH}"
ENV TEMPLATECONF="/yocto/conf-templates"

USER yocto
WORKDIR /yocto

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]
