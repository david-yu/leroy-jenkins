# leroy-jenkins

The greatest Jenkins to rule them all!

## Provision node to run Jenkins on

#### Install CS Engine on Node
```
curl -fsSL https://packages.docker.com/1.13/install.sh | repo=testing sh
```

#### Install Docker Compose
```
curl -L https://github.com/docker/compose/releases/download/1.10.0-rc1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

#### Join Node to Docker Swarm
```
docker swarm join --token ${SWARM_TOKEN} ${SWARM_MANAGER}:2377
```

#### Create Jenkins directory on node
```
mkdir jenkins
```

#### Create node label on Docker Engine
```
docker node update --label-add type=jenkins ${WORKER_NODE_NAME}
```

## Build application using Jenkins

#### Build from latest Jenkins image from Docker Hub

```
docker build -t yongshin/leroy-jenkins .
```

#### Start Jenkins by mapping workspace, expose Docker socket and Docker compose to container:

```
docker service create --name leroy-jenkins --publish 8080:8080 \
  --mount type=bind,source=$PWD/jenkins,destination=/var/jenkins_home \
  --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \
  --mount type=bind,source=/usr/local/bin/docker-compose,destination=/usr/local/bin/docker-compose \
  --constraint 'node.labels.type == jenkins' yongshin/leroy-jenkins
```

#### Copy password from jenkins folder

```
sudo more jenkins/secrets/initialAdminPassword
```

#### Create 'docker build and push' Free-Style Jenkins Job

```
#!/bin/bash
export DTR_IPADDR=172.28.128.10 export DOCKER_CONTENT_TRUST=1 DOCKER_CONTENT_TRUST_ROOT_PASSPHRASE=docker123 DOCKER_CONTENT_TRUST_REPOSITORY_PASSPHRASE=docker123
docker build -t ${DTR_IPADDR}/engineering/docker-node-app:1.${BUILD_NUMBER} .
docker tag ${DTR_IPADDR}/engineering/docker-node-app:1.${BUILD_NUMBER} ${DTR_IPADDR}/engineering/docker-node-app:latest
docker login -u admin -p dockeradmin ${DTR_IPADDR} 
docker push ${DTR_IPADDR}/engineering/docker-node-app:1.${BUILD_NUMBER}
docker push ${DTR_IPADDR}/engineering/docker-node-app:latest
```
