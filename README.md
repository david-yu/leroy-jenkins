# jenkins-docker

A project to build docker images using Jenkins within a docker container. docker-compose is not working in thie setup. Reference: http://container-solutions.com/running-docker-in-jenkins-in-docker/ and https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/.

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

Find ip address and port which jenkins is running on by running-docker-in-jenkins-in-docker
```
docker ps
```

## Install Docker Build and Publish Plugin

Enter repository name (i.e. yongshin/docker-node-app), docker registry (i.e. https://index.docker.io/v1/), and registry credentials

https://wiki.jenkins-ci.org/display/JENKINS/CloudBees+Docker+Build+and+Publish+plugin
