FROM jenkins/jenkins:lts
USER root
RUN apt-get update \
	&& apt-get upgrade -y \
	&& apt-get install -y sudo libltdl-dev \
	&& rm -rf /var/lib/apt/lists/*
RUN echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers

# Set my root's alias string for notary, this will not affect jenkins' user
RUN echo "alias notary='notary -s https://dtr.docker.ee --tlscacert /var/jenkins_home/.docker/ca.crt --trustDir /var/jenkins_home/.docker/trust' >> /root/.bashrc"

ENV DTR_IPADDR=dtr.docker.ee

RUN curl -k https://dtr.docker.ee/ca -o /usr/local/share/ca-certificates/dtr.docker.ee.crt \
	&& update-ca-certificates \
	&& mkdir -p /etc/ssl/ucp_bundle

# Since I've incorporated notary, I'm copying in my user bundle
ADD ucp_bundle /etc/ssl/ucp_bundle/

## I've just left these here for notes, while I test a few things
#Service labels
#com.docker.ucp.mesh.http.8080-1 / internal_port=8080,external_route=http://jenkins.apps.docker.ee"

#Container Labels
#com.docker.ucp.mesh.http / true
