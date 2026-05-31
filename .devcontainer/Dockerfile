FROM ghcr.io/cirruslabs/flutter:stable

USER root

# Install common dev tools + Java 17 (required by this project's build.gradle.kts)
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-17-jdk \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

# Install Android SDK command-line tools
RUN mkdir -p $ANDROID_HOME/cmdline-tools \
    && curl -s https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
        -o /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools \
    && mv /tmp/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip

# Accept licenses and install SDK packages matching the project's build.gradle.kts
# compileSdk = flutter default (35), buildTools = 35.0.0, Java 17
RUN yes | sdkmanager --licenses \
    && sdkmanager \
        "platform-tools" \
        "platforms;android-35" \
        "build-tools;35.0.0"

# Pre-warm Flutter tool cache including Android
RUN flutter config --android-sdk $ANDROID_HOME \
    && flutter precache --android \
    && flutter --version \
    && dart --version

WORKDIR /workspaces/pc-ify
