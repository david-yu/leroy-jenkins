# leroy-jenkins

This repo contains is a set of instructions to get you started on running Jenkins in a Container and building and deploying applications with Docker DataCenter for Engine 1.13.

## Provision node to run Jenkins on

#### Install CS Engine on Node
```
curl -fsSL https://packages.docker.com/1.13/install.sh | repo=testing sh
```

#### Join Node to Docker Swarm
```
docker swarm join --token ${SWARM_TOKEN} ${SWARM_MANAGER}:2377
```

#### Create Jenkins directory on Node
```
mkdir jenkins
```

#### Create Node label on Docker Engine
```
docker node update --label-add jenkins master
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

#### Copy scripts folder that includes `trust-dtr.sh` script, provided by [vagrant-vancouver](https://github.com/yongshin/vagrant-vancouver)
```
cp -r /vagrant/scripts/ /home/ubuntu/scripts
```

#### Start Jenkins by mapping workspace, expose Docker socket and Docker compose to container:

```
docker service create --name leroy-jenkins --network ucp-hrm --publish 8080:8080 \
  --mount type=bind,source=/home/ubuntu/jenkins,destination=/var/jenkins_home \
  --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \
  --mount type=bind,source=/usr/bin/docker,destination=/usr/bin/docker \
  --mount type=bind,source=/home/ubuntu/ucp-bundle-admin,destination=/home/jenkins/ucp-bundle-admin \
  --mount type=bind,source=/home/ubuntu/scripts,destination=/home/jenkins/scripts \
  --mount type=bind,source=/home/ubuntu/notary,destination=/usr/local/bin/notary \
  --label com.docker.ucp.mesh.http.8080=external_route=http://jenkins.local,internal_port=8080 \
  --constraint 'node.labels.jenkins == master' yongshin/leroy-jenkins
```

#### Have Jenkins trust the DTR CA (if using self-signed certs)
Run this inside of Jenkins container, mounted from a volume as shown above, the contents of the file are here: [trust-dtr.sh](https://github.com/yongshin/vagrant-vancouver/blob/master/scripts/trust-dtr.sh)
```
export DTR_IPADDR=172.28.128.11
./home/jenkins/scripts/trust-dtr.sh
```

#### Copy password from jenkins folder on Node
Run this inside of node
```
sudo more jenkins/secrets/initialAdminPassword
```

### Setup Docker Build and Push to DTR Jenkins Job

#### Create repo in DTR to push images. Otherwise authentication to DTR will fail on build.
![Repo](images/repo.png?raw=true)

#### Import private key from ucp bundle using notary
Run `notary key import` within jenkins container
```
root@09a07f72010d:/# notary -d /var/jenkins_home/.docker/trust key import /home/jenkins/ucp-bundle-admin/key.pem
Enter passphrase for new delegation key with ID 4906f54 (tuf_keys):
Repeat passphrase for new delegation key with ID 4906f54 (tuf_keys):
```

#### Initialize repository on notary
Run `notary init` on the newly created repo `docker-node-app` within jenkins container
```
root@09a07f72010d:/# notary -d /var/jenkins_home/.docker/trust -s https://172.28.128.11 init 172.28.128.11/engineering/docker-node-app
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
root@09a07f72010d:/# notary -d /var/jenkins_home/.docker/trust -s https://172.28.128.11 key rotate \
  172.28.128.11/engineering/docker-node-app snapshot -r
```

#### Publish changes
```
root@09a07f72010d:/# notary -s https://172.28.128.11 -d /var/jenkins_home/.docker/trust publish \
  172.28.128.11/engineering/docker-node-app
```

#### Add delegation for targets/releases and targets/jenkins
```
root@6ddfb62a5b8d:/# notary -s https://172.28.128.11 -d /var/jenkins_home/.docker/trust delegation add \
  172.28.128.11/engineering/docker-node-app targets/releases --all-paths /home/jenkins/ucp-bundle-admin/cert.pem

root@6ddfb62a5b8d/: notary -s https://172.28.128.11 -d /var/jenkins_home/.docker/trust delegation add \   
  172.28.128.11/engineering/docker-node-app targets/jenkins --all-paths /home/jenkins/ucp-bundle-admin/cert.pem

root@6ddfb62a5b8d/: notary -s https://172.28.128.11 -d /var/jenkins_home/.docker/trust publish \    
  172.28.128.11/engineering/docker-node-app
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
docker build -t ${DTR_IPADDR}/engineering/docker-node-app:1.${BUILD_NUMBER} .
docker tag ${DTR_IPADDR}/engineering/docker-node-app:1.${BUILD_NUMBER} ${DTR_IPADDR}/engineering/docker-node-app:latest
docker login -u admin -p dockeradmin ${DTR_IPADDR}
docker push ${DTR_IPADDR}/engineering/docker-node-app:1.${BUILD_NUMBER}
docker push ${DTR_IPADDR}/engineering/docker-node-app:latest
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
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH="/home/jenkins/ucp-bundle-admin"
export DOCKER_HOST=tcp://172.28.128.5:443
docker login -u admin -p dockeradmin ${DTR_IPADDR}
docker pull ${DTR_IPADDR}/engineering/docker-node-app:latest
docker pull clusterhq/mongodb
docker stack rm nodeapp
docker stack deploy -c docker-compose.yml nodeapp
```
