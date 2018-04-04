FROM jenkins/jenkins:lts
USER root
RUN apt-get update \
	&& apt-get upgrade -y \
	&& apt-get install -y sudo libltdl-dev \
	&& rm -rf /var/lib/apt/lists/*
RUN echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers

# Set my root's alias string for notary, this will not affect jenkins' user
RUN echo "alias notary='notary -s https://dtr.domain.com --trustDir /var/jenkins_home/.docker/trust'" >> /root/.bashrc

ENV DTR_IPADDR=dtr.domain.com

RUN curl -k https://dtr.domain.com/ca -o /usr/local/share/ca-certificates/dtr.domain.com.crt \
	&& update-ca-certificates \
	&& mkdir -p /etc/ssl/ucp_bundle /var/jenkins_home/.docker

# Since I've incorporated notary, I'm copying in my user bundle
ADD ucp_bundle /etc/ssl/ucp_bundle/
