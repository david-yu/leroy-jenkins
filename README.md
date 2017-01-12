# leroy-jenkins

The greatest Jenkins to rule them all!

## Provision node to run Jenkins on

#### Install CS Engine on Node
```
curl -fsSL https://packages.docker.com/1.13/install.sh | repo=testing sh
```

#### Install Docker Compose on Node
```
curl -L https://github.com/docker/compose/releases/download/1.10.0-rc1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
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
docker node update --label-add type=jenkins ${WORKER_NODE_NAME}
```

#### Install DTR CA on Node (if using self-signed certs)
```
export DTR_IPADDR=$(cat /vagrant/dtr-vancouver-node1-ipaddr)
openssl s_client -connect ${DTR_IPADDR}:443 -showcerts </dev/null 2>/dev/null | openssl x509 -outform PEM | sudo tee /usr/local/share/ca-certificates/${DTR_IPADDR}.crt
sudo update-ca-certificates
sudo service docker restart
```

## Build application using Jenkins

#### Build from Dockerfile on Github (Optional, otherwise just pull from DockerHub)
```
docker build -t yongshin/leroy-jenkins .
```

#### Start Jenkins by mapping workspace, expose Docker socket and Docker compose to container:

```
docker service create --name leroy-jenkins --publish 8080:8080 \
  --mount type=bind,source=/home/ubuntu/jenkins,destination=/var/jenkins_home \
  --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \
  --mount type=bind,source=/usr/local/bin/docker-compose,destination=/usr/local/bin/docker-compose \
  --mount type=bind,source=/home/ubuntu/ucp-bundle-admin,destination=/home/jenkins/ucp-bundle-admin \
  --constraint 'node.labels.type == jenkins' yongshin/leroy-jenkins
```

#### Copy password from jenkins folder on Node
```
sudo more jenkins/secrets/initialAdminPassword
```

#### Create repo in DTR to push images. Otherwise authentication to DTR will fail on build.
![Repo](images/repo.png?raw=true)

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
export DTR_IPADDR=172.28.128.10
export DOCKER_CONTENT_TRUST=1 DOCKER_CONTENT_TRUST_ROOT_PASSPHRASE=docker123 DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE=docker123
docker build -t ${DTR_IPADDR}/engineering/docker-node-app:1.${BUILD_NUMBER} .
docker tag ${DTR_IPADDR}/engineering/docker-node-app:1.${BUILD_NUMBER} ${DTR_IPADDR}/engineering/docker-node-app:latest
docker login -u admin -p dockeradmin ${DTR_IPADDR}
docker push ${DTR_IPADDR}/engineering/docker-node-app:1.${BUILD_NUMBER}
docker push ${DTR_IPADDR}/engineering/docker-node-app:latest
```

#### Create 'docker deploy' Free-Style Jenkins Job
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
export DTR_IPADDR=172.28.128.6
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH="/home/jenkins/ucp-bundle-admin"
export DOCKER_HOST=tcp://172.28.128.5:443
docker-compose stop
docker login -u admin -p admin ${DTR_IPADDR}
docker pull ${DTR_IPADDR}/engineering/docker-node-app
docker pull clusterhq/mongodb
docker-compose -p docker-node-app up -d
docker-compose scale app=5
```
