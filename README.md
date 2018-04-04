# Jenkings in a container with NFS & Notary (optional)
***
## The Dockerfile
```
FROM jenkins/jenkins:lts
USER root
RUN apt-get update \
	&& apt-get upgrade -y \
	&& apt-get install -y sudo libltdl-dev \
	&& rm -rf /var/lib/apt/lists/*
RUN echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers

# Set my root's alias string for notary, this will not affect jenkins' user
RUN echo "alias notary='notary -s https://${DTR_IP_OR_URL} --trustDir /var/jenkins_home/.docker/trust'" >> /root/.bashrc

ENV DTR_IPADDR=${DTR_IP_OR_URL}

RUN curl -k https://${DTR_IP_OR_URL}/ca -o /usr/local/share/ca-certificates/<dtr.example.com>.crt \
	&& update-ca-certificates \
	&& mkdir -p /etc/ssl/ucp_bundle

# Since I've incorporated notary, I'm copying in my user bundle
ADD ucp_bundle /etc/ssl/ucp_bundle/
```

Here above we reference jenkins' repo for the lts (long-term-supported) image and compile in updates and packages required for Jenkins. A crucial step is to add jenkins to the sudoers file so that running the following commands will be possible. We'll also add in a bash alias just to make it easier to setup notary manually. Lets add DTR's IP (x.x.x.x) or URL (dtr.domain.com) to the environment (optional) and curl in the CA certificate, we'll also transfer in a client bundle.  That's pretty much it, next we'll have to setup our NFS mounts and configure our service via stack deploy. Please note that any "notary" steps may change with "docker-trust" in the near future.

Now let's build the image and push it to our DTR registry.
```
docker build -t dtr.domain.com/repo/jenkins:tag .
docker push dtr.domain.com/repo/jenkins:tag
```

## The NFS setup
On my Ubuntu 16.04 system I configured nfs like so...

I've created two directories, one for jenkins_home for it's configuration data and another for jenkins to actually do the docker build commands locally (from the container) for us.
```
mkdir -p /nfs/jenkins_home /nfs/jenkins_build
```
Next we'll add these to the /etc/exports file and update the nfs service.
```
/etc/exports...
/nfs/jenkins_home *(rw,sync,no_subtree_check,no_root_squash)
/nfs/jenkins_build *(rw,sync,no_subtree_check,no_root_squash)
...

shaker@nfsserver:~$ sudo exportfs -af
shaker@nfsserver:~$ sudo exportfs
/nfs/jenkins_home <world>
/nfs/jenkins_build <world>
```
### Deploying jenkins
Now we have our image pushed to our DTR or hub account and we have our nfs server sharing the mount points. We now have to make sure that the nfs clients (apt-get install nfs-common -y) are installed on each node so that mounting the volumes will be possible. We'll also want to ensure that the notary binary is installed on each node as well since we'll be using notary to sign images. I have also desided to leverage the HTTP Routing Mesh (HRM), you'll see this in the docker-compose.yml file. 

I'm not going to cover notary right now since I expect the process to be updated in the near future, but having access to the notary binary in advance will help you add that functionality if you so desire.

Notary binary's may be located here: https://github.com/theupdateframework/notary/releases; I have found that version 0.4.3 works best, if you run "notary version" and don't get any results, make sure you're using v0.4.3. Every node that Jenkins may be running on (container) will need the notary binary installed... so, all of them to be safe.

```
shaker@worker1:~$ sudo curl -k https://github.com/theupdateframework/notary/releases/download/v0.4.3/notary-Linux-amd64 -o /usr/bin/notary ; chmod +x /usr/bin/notary
```
The only remaining step is to deploy the docker-compose.yml file... Here I've loaded my docker client bundle for admin, so I'll deploy it.

```
DockerMac:leroy-jenkins $ docker stack deploy -c docker-compose.yml myjenkins
Creating service myjenkins_jenkins
DockerMac:leroy-jenkins $ 

DockerMac:leroy-jenkins $ docker stack ls
NAME                SERVICES
myjenkins           1
DockerMac:leroy-jenkins $ docker stack ps myjenkins
ID                  NAME                  IMAGE                            NODE                DESIRED STATE       CURRENT STATE           ERROR               PORTS
jjiwk6cw2kzl        myjenkins_jenkins.1   dtr.domain.com/org/jenkins:tag   worker1              Running             Running 4 minutes ago                       
DockerMac:leroy-jenkins $ 
```

Visit http://jenkins.domain.com to pull up Jenkin's first login, you can access the initialAdminPassword file directly from the nfs server share. Login with this account, install the common plugins and you should be presented with the configuration page. Don't forget to go back and update your admin password.

```
root@nfsserver:~# cat /nfs/jenkins_home/secrets/initialAdminPassword 
```

Enjoy!

# leroy-jenkins (The Original)

This repo contains is a set of instructions to get you started on running Jenkins in a Container and building and deploying applications with Docker EE Standard and Advanced.

## Provision node to run Jenkins on

#### Install Docker EE on the Node
```
export DOCKER_EE_URL=$(cat /home/ubuntu/ee_url)
sudo curl -fsSL ${DOCKER_EE_URL}/gpg | sudo apt-key add
sudo add-apt-repository "deb [arch=amd64] ${DOCKER_EE_URL} $(lsb_release -cs) stable-17.06"
sudo apt-get update
sudo apt-get -y install docker-ee
sudo usermod -aG docker ubuntu
```

#### Join Node to Docker Swarm
```
docker swarm join --token ${SWARM_TOKEN} ${SWARM_MANAGER}:2377
```

#### Create Jenkins directory on Node
```
mkdir jenkins
```

#### Install DTR CA on Node as well as all Nodes inside of UCP Swarm (if using self-signed certs)
```
export DTR_IPADDR=$(cat /vagrant/dtr-vancouver-node1-ipaddr)
openssl s_client -connect ${DTR_IPADDR}:443 -showcerts </dev/null 2>/dev/null | openssl x509 -outform PEM | sudo tee /usr/local/share/ca-certificates/${DTR_IPADDR}.crt
sudo update-ca-certificates
sudo service docker restart
```

## Build application using Jenkins

### Setup Jenkins

#### Build from Dockerfile on Github (Optional, otherwise just pull from DockerHub)
```
docker build -t yongshin/leroy-jenkins .
```

#### Download UCP Client bundle from ucp-bundle-admin and unzip in `ucp-bundle-admin` folder
```
cp -r /vagrant/ucp-bundle-admin/ .
cd ucp-bundle-admin
source env.sh
```

#### Start Jenkins by mapping the Jenkins workspace, Docker binary, Notary and exposing the Docker daemon socket to the container (remove volumes you do not wish to mount otherwise the command will not work):

```
docker service create --name leroy-jenkins --network ucp-hrm --publish 8080:8080 \
  --mount type=bind,source=/home/ubuntu/jenkins,destination=/var/jenkins_home \
  --mount type=bind,source=/home/ubuntu/notary-config/.docker/trust,destination=/root/.docker/trust \
  --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \
  --mount type=bind,source=/usr/bin/docker,destination=/usr/bin/docker \
  --mount type=bind,source=/home/ubuntu/ucp-bundle-admin,destination=/home/jenkins/ucp-bundle-admin \
  --mount type=bind,source=/home/ubuntu/notary,destination=/usr/local/bin/notary \
  --label com.docker.ucp.mesh.http.8080=external_route=http://jenkins.local,internal_port=8080 \
  --constraint node.hostname==engine04 yongshin/leroy-jenkins
```

#### Copy password from jenkins folder on Node
Run this inside of node
```
sudo more jenkins/secrets/initialAdminPassword
```

#### Have Jenkins trust the DTR CA (if using self-signed certs)
Run this inside of Jenkins container:
```
export DTR_IPADDR=172.28.128.11
openssl s_client -connect ${DTR_IPADDR}:443 -showcerts </dev/null 2>/dev/null | openssl x509 -outform PEM | sudo tee /usr/local/share/ca-certificates/${DTR_IPADDR}.crt
sudo update-ca-certificates
```

### Setup Docker Build and Push to DTR Jenkins Job

#### Create repo in DTR to push images. Otherwise authentication to DTR will fail on build.
![Repo](images/repo.png?raw=true)

#### Import private key from ucp bundle using notary
Run `notary key import` within jenkins container
```
root@09a07f72010d:/# notary -d ~/.docker/trust key import /home/jenkins/ucp-bundle-admin/key.pem
Enter passphrase for new delegation key with ID 4906f54 (tuf_keys):
Repeat passphrase for new delegation key with ID 4906f54 (tuf_keys):
```

#### Initialize repository on notary
Run `notary init` on the newly created repo `docker-node-app` within jenkins container
```
root@09a07f72010d:/# notary -d ~/.docker/trust -s https://172.28.128.11 init 172.28.128.11/engineering/docker-node-app
Root key found, using: c47333b8b15fe43a6abc59dcb29f4e60dee1807919dfc05f6e57dbfc57553d88
Enter passphrase for root key with ID c47333b:
Enter passphrase for new targets key with ID 8e7009a (172.28.128.4/engineering/docker-node-app):
Repeat passphrase for new targets key with ID 8e7009a (172.28.128.4/engineering/docker-node-app):
Enter passphrase for new snapshot key with ID 16827df (172.28.128.4/engineering/docker-node-app):
Repeat passphrase for new snapshot key with ID 16827df (172.28.128.4/engineering/docker-node-app):
Enter username: admin
Enter password:
```

#### Rotate key to notary server
```
root@09a07f72010d:/# notary -d ~/.docker/trust -s https://172.28.128.11 key rotate \
  172.28.128.11/engineering/docker-node-app snapshot -r
  Enter username: admin
  Enter password:
  Enter passphrase for root key with ID be231c8:
  Enter passphrase for targets key with ID 43d1a93:
  Successfully rotated snapshot key for repository 172.28.128.11/engineering/docker-node-app
```

#### Publish changes
```
root@09a07f72010d:/# notary -d ~/.docker/trust publish -s https://172.28.128.11  \
  172.28.128.11/engineering/docker-node-app
  Pushing changes to 172.28.128.11/engineering/docker-node-app
  Enter username: admin
  Enter password:
  Successfully published changes for repository 172.28.128.11/engineering/docker-node-app
```

#### Add delegation for targets/releases and targets/jenkins
```
root@6ddfb62a5b8d:/# notary -d ~/.docker/trust -s https://172.28.128.11 delegation add \
  172.28.128.11/engineering/docker-node-app targets/releases --all-paths /home/jenkins/ucp-bundle-admin/cert.pem

root@6ddfb62a5b8d/: notary -d ~/.docker/trust -s https://172.28.128.11 delegation add \
  172.28.128.11/engineering/docker-node-app targets/jenkins --all-paths /home/jenkins/ucp-bundle-admin/cert.pem

root@6ddfb62a5b8d/: notary -d ~/.docker/trust -s https://172.28.128.11 publish \
  172.28.128.11/engineering/docker-node-app
  Pushing changes to 172.28.128.11/engineering/docker-node-app
  Enter username: admin
  Enter password:
  Enter passphrase for targets key with ID 43d1a93:
  Successfully published changes for repository 172.28.128.11/engineering/docker-node-app
```

#### Check Notary Local Keys
Make sure your delegation key is here
```
notary -d ~/.docker/trust key list
```

#### Check Notary Notary Delegations
Also make sure your delegations are setup
```
notary -s https://172.28.128.11 -d ~/.docker/trust delegation list 172.28.128.11/engineering/docker-node-app
```

#### Additional commands if needing to start over
Delete repo from notary server:
```
notary -d ~/.docker/trust -s https://172.28.128.11 delete 172.28.128.11/engineering/docker-node-app --remote
```

#### Create 'docker build and push' Free-Style Jenkins Job
![Jenkins Job](images/jenkins-create-job.png?raw=true)

#### Source Code Management -> Git - set repository to the repository to check out source
```
https://github.com/yongshin/docker-node-app.git
```

#### Set Build Triggers -> Poll SCM
```
* * * * *
```

#### Add Build Step -> Execute Shell
```
#!/bin/bash
export DTR_IPADDR=172.28.128.11
export DOCKER_CONTENT_TRUST=1 DOCKER_CONTENT_TRUST_ROOT_PASSPHRASE=docker123 DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE=docker123
docker rmi ${DTR_IPADDR}/engineering/docker-node-app:latest
docker build -t ${DTR_IPADDR}/engineering/docker-node-app .
docker tag ${DTR_IPADDR}/engineering/docker-node-app ${DTR_IPADDR}/engineering/docker-node-app:1.${BUILD_NUMBER}
docker login -u admin -p dockeradmin ${DTR_IPADDR}
docker push ${DTR_IPADDR}/engineering/docker-node-app
docker push ${DTR_IPADDR}/engineering/docker-node-app:1.${BUILD_NUMBER}
```

### Setup Docker Deploy Jenkins Job

#### Create Docker Deploy Application Free-Style Jenkins Job
![Docker Create Job](images/jenkins-create-job-deploy.png?raw=true)

#### Source Code Management -> Git - set repository to the repository to check out source
```
https://github.com/yongshin/docker-node-app.git
```

#### Add Jenkins build trigger to run deploy after image build job is complete
![Jenkins Build Trigger](images/jenkins-build-trigger.png?raw=true)

#### Add Build Step -> Execute Shell
```
#!/bin/bash
export DTR_IPADDR=172.28.128.11
export DOCKER_CONTENT_TRUST=1 DOCKER_CONTENT_TRUST_ROOT_PASSPHRASE=docker123 DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE=docker123
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH="/home/jenkins/ucp-bundle-admin"
export DOCKER_HOST=tcp://ucp.local:443
docker login -u admin -p dockeradmin ${DTR_IPADDR}
docker rmi ${DTR_IPADDR}/engineering/docker-node-app:latest
docker pull ${DTR_IPADDR}/engineering/docker-node-app:latest
docker pull clusterhq/mongodb
docker service update --image ${DTR_IPADDR}/engineering/docker-node-app:latest nodeapp_app
# run to deploy stack first
# docker stack deploy -c docker-compose-demo.yml nodeapp
```

### Setup Docker Deploy Trusted Images Job (Optional)

#### Add Build Step -> Execute Shell
```
#!/bin/bash
export DTR_IPADDR=172.28.128.11
export DOCKER_CONTENT_TRUST=1 DOCKER_CONTENT_TRUST_ROOT_PASSPHRASE=docker123 DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE=docker123
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH="/home/jenkins/ucp-bundle-admin"
export DOCKER_HOST=tcp://ucp.local:443
# create users
createUser() {
	USER_NAME=$1
    FULL_NAME=$2
	curl -X POST --header "Content-Type: application/json" --header "Accept: application/json" \
    --user admin:dockeradmin -d "{
      \"isOrg\": false,
      \"isAdmin\": false,
      \"isActive\": true,
      \"fullName\": \"${FULL_NAME}\",
      \"name\": \"${USER_NAME}\",
      \"password\": \"docker123\"}" \
    "https://${DTR_IPADDR}/enzi/v0/accounts"
}
createUser david 'David Yu'
createUser solomon 'Solomon Hykes'
createUser banjot 'Banjot Chanana'
# create organizations
createOrg() {
	ORG_NAME=$1
	curl -X POST --header "Content-Type: application/json" --header "Accept: application/json" \
    --user admin:dockeradmin -d "{
      \"isOrg\": true,
      \"name\": \"${ORG_NAME}\"}" \
      "https://${DTR_IPADDR}/enzi/v0/accounts"
}
createOrg engineering
createOrg infrastructure
# create repositories
createRepo() {
    REPO_NAME=$1
    ORG_NAME=$2
    NOTARY_ROOT_PASSPHRASE="docker123"
    NOTARY_TARGETS_PASSPHRASE="docker123"
    NOTARY_SNAPSHOT_PASSPHRASE="docker123"
    NOTARY_DELEGATION_PASSPHRASE="docker123"
    NOTARY_OPTS="-s https://${DTR_URL} -d ${HOME}/.docker/trust"
    curl -X POST --header "Content-Type: application/json" --header "Accept: application/json" \
  --user admin:dockeradmin -d "{
    \"name\": \"${REPO_NAME}\",
    \"shortDescription\": \"\",
    \"longDescription\": \"\",
    \"visibility\": \"public\"}" \
  "https://${DTR_IPADDR}/api/v0/repositories/${ORG_NAME}"
}
createRepo mongo engineering
createRepo wordpress engineering
createRepo mariadb engineering
createRepo leroy-jenkins infrastructure
# pull images from hub
docker pull mongo
docker pull wordpress
docker pull mariadb
# build custom images
docker build -t leroy-jenkins .
# tag images
docker tag mongo ${DTR_IPADDR}/engineering/mongo:latest
docker tag wordpress ${DTR_IPADDR}/engineering/wordpress:latest
docker tag mariadb ${DTR_IPADDR}/engineering/mariadb:latest
docker tag leroy-jenkins ${DTR_IPADDR}/infrastructure/leroy-jenkins:latest
# push signed images
docker push ${DTR_IPADDR}/engineering/mongo:latest
docker push ${DTR_IPADDR}/engineering/wordpress:latest
docker push ${DTR_IPADDR}/engineering/mariadb:latest
docker push ${DTR_IPADDR}/infrastructure/leroy-jenkins:latest
```
