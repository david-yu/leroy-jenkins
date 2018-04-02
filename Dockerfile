FROM jenkins/jenkins:lts
USER root
RUN apt-get update \
	&& apt-get upgrade -y \
	&& apt-get install -y sudo libltdl-dev \
	&& rm -rf /var/lib/apt/lists/*
RUN echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers

# Set my root's alias string for notary, this will not affect jenkins' user
RUN echo "alias notary='notary -s https://repo.docker.com --tlscacert /var/jenkins_home/.docker/ca.crt --trustDir /var/jenkins_home/.docker/trust'" >> /root/.bashrc

ENV DTR_IPADDR=repo.domain.com

RUN curl -k https://repo.domain.com/ca -o /usr/local/share/ca-certificates/repo.domain.com.crt \
	&& update-ca-certificates \
	&& mkdir -p /etc/ssl/ucp_bundle \
	&& mkdir -p /var/jenkins_home/.docker

# Since I've incorporated notary, I'm copying in my user bundle
ADD ucp_bundle /etc/ssl/ucp_bundle/
