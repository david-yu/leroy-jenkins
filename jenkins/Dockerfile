FROM jenkins/jenkins:lts
USER root
RUN apt-get update \
	&& apt-get upgrade -y \
	&& apt-get install -y sudo libltdl-dev \
	&& rm -rf /var/lib/apt/lists/*
RUN echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers

# Set environment varibles at runtime
ENV DTR_DOMAIN_COM=dtr.domain.com 

# Set my root's alias string for notary, this will not affect jenkins' user
RUN echo "alias notary='notary -s https://${DTR_DOMAIN_COM} --trustDir /var/jenkins_home/.docker/trust'" >> /root/.bashrc

RUN curl -k https://${DTR_DOMAIN_COM}/ca -o /usr/local/share/ca-certificates/${DTR_DOMAIN_COM}.crt \
	&& update-ca-certificates \
	&& mkdir -p /etc/ssl/ucp_bundle /var/jenkins_home/.docker

# Since I've incorporated notary, I'm copying in my Docker EE user bundle
ADD ucp_bundle /etc/ssl/ucp_bundle/