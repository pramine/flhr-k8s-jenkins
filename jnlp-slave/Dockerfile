FROM jenkins/jnlp-slave 
MAINTAINER Charles Saroka 

ENV HELM_VERSION v3.0.0
ENV HELM_FILENAME helm-${HELM_VERSION}-linux-amd64.tar.gz
ENV KUBE_LATEST_VERSION=v1.16.0

USER root
WORKDIR /
RUN apt-get update && apt-get install -y \ 
  curl \
  tar \
  gzip \
  ca-certificates \
  git

RUN curl https://get.helm.sh/${HELM_FILENAME} | tar zxv -C /tmp \
  && cp /tmp/linux-amd64/helm /usr/local/bin/helm \
  && chmod +x /usr/local/bin/helm

RUN curl https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
 && chmod +x /usr/local/bin/kubectl

RUN apt-get clean

USER jenkins

