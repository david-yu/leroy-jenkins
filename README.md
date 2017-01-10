# leroy-jenkins

The greatest Jenkins to rule them all!

## Provision node to run Jenkins on

### Install CS Engine on Node
```
curl -fsSL https://packages.docker.com/1.13/install.sh | repo=testing sh
```

### Install Docker Compose
```
curl -L https://github.com/docker/compose/releases/download/1.10.0-rc1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

### Join Node to Docker Swarm

## Build application using Jenkins

Build from latest Jenkins image from Docker Hub

```
docker build -t yongshin/leroy-jenkins .
```

Start Jenkins by mapping workspace, expose Docker socket to Jenkins Container, and mapping docker binary:

```
docker run -d -p 49001:8080 -v $PWD/jenkins:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock -v $(which docker):/usr/bin/docker -t yongshin/jenkins-docker

docker run -d -p 8080:8080 -v /var/run/docker.sock:/var/run/docker.sock -v /usr/local/bin/docker-compose:/usr/local/bin/docker-compose leroy-jenkins
```
