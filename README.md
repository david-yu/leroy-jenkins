# jenkins-docker

Reference: http://container-solutions.com/running-docker-in-jenkins-in-docker/

## Build application using Jenkins

Build from latest Jenkins image from Docker Hub

```
docker build -t yongshin/jenkins-docker .
```

Start Jenkins by mapping workspace, expose Docker socket to Jenkins Container, and mapping docker binary:

```
docker run -d -p 49001:8080 -v $PWD/jenkins:/var/jenkins_home -v /var/run/docker.sock:/var/run/docker.sock -v $(which docker):/usr/bin/docker -t yongshin/jenkins-docker
```

## Install Docker Build and Publish Plugin

Enter repository name (i.e. yongshin/docker-node-app), docker registry (i.e. https://index.docker.io/v1/), and registry credentials

https://wiki.jenkins-ci.org/display/JENKINS/CloudBees+Docker+Build+and+Publish+plugin
