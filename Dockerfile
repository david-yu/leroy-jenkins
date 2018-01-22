FROM jenkins/jenkins:lts
USER root
RUN apt-get update \
	&& apt-get upgrade -y \
	&& apt-get install -y sudo libltdl-dev \
	&& rm -rf /var/lib/apt/lists/*
RUN echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers 
RUN echo "alias notary='notary -s https://dtr.docker.ee --tlscacert /var/jenkins_home/.docker/ca.crt --trustDir /var/jenkins_home/.docker/trust' >> /root/.bashrc"
ENV DTR_IPADDR=dtr.docker.ee
RUN curl -k https://dtr.docker.ee/ca -o /usr/local/share/ca-certificates/dtr.docker.ee.crt \
	&& update-ca-certificates \
	&& mkdir -p /etc/ssl/ucp_bundle
ADD ucp_bundle /etc/ssl/ucp_bundle/

