# leroy-jenkins

The greatest jenkins to rule them all.

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
