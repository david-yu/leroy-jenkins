FROM jenkins:latest

USER root
RUN apt-get update \
      && apt-get install -y sudo \
      && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://packages.docker.com/1.13/install.sh | repo=testing sh
RUN echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers
RUN sudo usermod -a -G docker jenkins
