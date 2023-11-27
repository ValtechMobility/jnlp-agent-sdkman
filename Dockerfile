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
    graphviz

RUN curl -s "https://get.sdkman.io" | bash

SHELL ["/bin/bash", "-c"]    

RUN source "$HOME/.sdkman/bin/sdkman-init.sh" && sdk install java 21-tem && sdk use java 21-tem

USER ${user}

RUN java --version
RUN which java

ENTRYPOINT ["/usr/local/bin/jenkins-agent"]
