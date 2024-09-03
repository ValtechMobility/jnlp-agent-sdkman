FROM jenkins/inbound-agent:alpine as jnlp

FROM jenkins/agent:latest-jdk21

ARG version
LABEL Description="This is a base image, which allows connecting Jenkins agents via JNLP protocols" Vendor="Jenkins project" Version="$version"

ARG user=jenkins

USER root

COPY --from=jnlp /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-agent

RUN chmod +x /usr/local/bin/jenkins-agent &&\
    ln -s /usr/local/bin/jenkins-agent /usr/local/bin/jenkins-slave

RUN apt-get update \
  && apt-get -y install \
    unzip \
    curl \
    zip \
    wget \
    rsync \
    openssh-client \
    ca-certificates-java \
    xvfb \
    gnupg \
    gnupg1 \
    gnupg2 \
    libxi6 \
    libgconf-2-4 \
    graphviz  && rm -rf /var/lib/apt/lists/*

RUN curl -sS -o - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64]  http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list \
    && apt-get -y update \
    && apt-get -y install google-chrome-stable

RUN wget -q https://storage.googleapis.com/chrome-for-testing-public/128.0.6613.119/linux64/chromedriver-linux64.zip \
    && unzip chromedriver-linux64.zip \
    && mv chromedriver-linux64/chromedriver /usr/bin/chromedriver \
    && chmod +x /usr/bin/chromedriver \
    && rm -f chromedriver_linux64.zip

RUN google-chrome --version
RUN chromedriver --version

RUN curl -SsL https://downloads.gauge.org/stable | sh

RUN gauge install java
RUN gauge install xml-report

RUN gauge version

SHELL ["/bin/bash", "-c"]


# GitVersion
RUN wget https://github.com/GitTools/GitVersion/releases/download/5.12.0/gitversion-linux-x64-5.12.0.tar.gz
RUN tar -xvf gitversion-linux-x64-5.12.0.tar.gz
RUN mv gitversion /usr/local/bin
RUN chmod +x /usr/local/bin/gitversion

# Dependencies to execute Android builds
RUN apt-get update -qq
RUN dpkg --add-architecture i386 && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libc6:i386 \
    libgcc1:i386 \
    libncurses5:i386 \
    libstdc++6:i386 \
    libz1:i386

SHELL ["/bin/bash", "-c"]

ENV ANDROID_HOME /opt/sdk
ENV ANDROID_SDK_ROOT /opt/sdk
ENV DEBIAN_FRONTEND=noninteractive

RUN mkdir -p ${ANDROID_SDK_ROOT}
RUN chmod -Rf 777 ${ANDROID_SDK_ROOT}
RUN chown -Rf 1000:1000 ${ANDROID_SDK_ROOT}
RUN cd ${ANDROID_SDK_ROOT} && wget https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip -O sdk-tools.zip
RUN cd ${ANDROID_SDK_ROOT} && mkdir tmp && unzip sdk-tools.zip -d tmp && rm sdk-tools.zip
RUN cd ${ANDROID_SDK_ROOT} && mkdir -p cmdline-tools/latest && mv tmp/cmdline-tools/* cmdline-tools/latest

ENV PATH ${PATH}:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin

# Accept licenses before installing components, no need to echo y for each component
# License is valid for all the standard components in versions installed from this file
# Non-standard components: MIPS system images, preview versions, GDK (Google Glass) and Android Google TV require separate licenses, not accepted there
RUN yes | sdkmanager --update
RUN yes | sdkmanager --licenses
RUN sdkmanager "platform-tools"
RUN sdkmanager --install "ndk;25.1.8937393" "cmake;3.22.1"

# Please keep all sections in descending order!
# list all platforms, sort them in descending order, take the newest 8 versions and install them
RUN yes | sdkmanager $( sdkmanager --list 2>/dev/null| grep platforms | awk -F' ' '{print $1}' | sort -nr -k2 -t- | head -8 | uniq )
# list all build-tools, sort them in descending order and install them
# skip rc versions, increase head count - versions are found twice (actual matches will now be ~5)
RUN yes | sdkmanager $( sdkmanager --list 2>/dev/null | grep build-tools | grep -v "\-rc" | awk -F' ' '{print $1}' | sort -nr -k2 -t\; | head -10 | uniq )
RUN yes | sdkmanager \
    "extras;android;m2repository" \
    "extras;google;m2repository"

USER ${user}

RUN curl -s "https://get.sdkman.io" | bash

RUN source "$HOME/.sdkman/bin/sdkman-init.sh" && \
    sdk install maven && \
    sdk install java 17.0.10-tem && \
    sdk install java 21-tem && \
    sdk use java 21-tem

RUN java --version
RUN which java

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
