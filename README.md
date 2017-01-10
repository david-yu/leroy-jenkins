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
--constraint 'node.role == worker' leroy-jenkins 
```
