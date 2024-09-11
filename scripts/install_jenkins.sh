#!/bin/bash

# Update the package repository
sudo apt-get update -y

# Install Java (Jenkins dependency)
sudo apt-get install -y openjdk-11-jre

# Install Jenkins
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt-get update -y
sudo apt-get install -y jenkins


# Install Docker
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update -y
sudo apt-get install -y docker-ce


# Add the Jenkins user to the Docker group
sudo usermod -aG docker jenkins

# Install Git
sudo apt-get install -y git
git config --global user.name "david"
git config --global user.email "9200200@gmail.com"

# install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# install kbuectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# start docker
echo "Starting docker"
sudo systemctl enable docker
sudo systemctl start docker

# Start Jenkins
echo "Starting Jenkins"
sudo systemctl enable jenkins
sudo systemctl start jenkins
