FROM ghcr.io/cirruslabs/flutter:stable

USER root

# Install common dev tools
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Pre-warm the Flutter tool cache so first flutter command is instant
RUN flutter precache --no-android --no-ios --no-web --no-linux --no-windows --no-macos \
    && flutter --version \
    && dart --version

WORKDIR /workspaces/pc-ify
