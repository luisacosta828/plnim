# =============================================================================
# PostgreSQL 15 with PL/Nim (Nim Procedural Language Handler)
# Powered by Pgxcrown
# =============================================================================
FROM postgres:15-bullseye

LABEL maintainer="Luis Acosta <luisacosta828@gmail.com>"
LABEL description="PostgreSQL 15 image with native PL/Nim procedural language support"

SHELL ["/bin/bash", "-c"]

# -----------------------------------------------------------------------------
# 1. System Build Dependencies & PostgreSQL Development Headers
# -----------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        postgresql-contrib \
        libpq-dev \
        postgresql-server-dev-15 \
        wget \
        xz-utils \
        git \
        libssl-dev \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2. Install Official Nim Compiler (v2.2.4)
# -----------------------------------------------------------------------------
RUN wget -q https://nim-lang.org/download/nim-2.2.4-linux_x64.tar.xz && \
    mkdir -p /opt && \
    tar -xf nim-2.2.4-linux_x64.tar.xz -C /opt && \
    mv /opt/nim-2.2.4 /opt/nim && \
    rm nim-2.2.4-linux_x64.tar.xz && \
    ln -sf /opt/nim/bin/nim /usr/local/bin/nim && \
    ln -sf /opt/nim/bin/nimble /usr/local/bin/nimble

# Set global PATH and pgxtool environment variables
ENV PATH="/opt/nim/bin:/var/lib/postgresql/.nimble/bin:/usr/local/bin:${PATH}"
ENV PGXTOOL_BIN="/usr/local/bin/pgxtool"
ENV PGXTOOL_INIT_DIR="/var/lib/postgresql/postgresql_pgxtool"

# Configure git safe directory globally for all users
RUN git config --system --add safe.directory "*"

# -----------------------------------------------------------------------------
# 3. Install latest Pgxcrown Core & Global pgxtool CLI
# -----------------------------------------------------------------------------
USER postgres
ENV HOME=/var/lib/postgresql
RUN git config --global --add safe.directory "*" && \
    nimble install -y https://github.com/luisacosta828/pgxcrown.git

USER root
RUN ln -sf /var/lib/postgresql/.nimble/bin/pgxtool /usr/local/bin/pgxtool

# -----------------------------------------------------------------------------
# 4. Build & Install PL/Nim Extension Library
# -----------------------------------------------------------------------------
WORKDIR /tmp/plnim_build
COPY --chown=postgres:postgres . .

USER postgres
RUN nim c --hints:off -d:release --app:lib -o:plnim.so src/plnim.nim && \
    nimble install -y

USER root
# Install plnim.so into PostgreSQL shared libraries directory
RUN cp plnim.so $(pg_config --pkglibdir)/

# Register plnim extension automatically on container initialization
RUN mkdir -p /docker-entrypoint-initdb.d && \
    cp src/plnim/sql/extension.sql /docker-entrypoint-initdb.d/01_plnim.sql && \
    rm -rf /tmp/plnim_build

# -----------------------------------------------------------------------------
# 5. Runtime Workspace Setup for PostgreSQL user
# -----------------------------------------------------------------------------
RUN mkdir -p /var/lib/postgresql/postgresql_pgxtool && \
    chown -R postgres:postgres /var/lib/postgresql

USER postgres
WORKDIR /var/lib/postgresql

# Default PostgreSQL port
EXPOSE 5432
