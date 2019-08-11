#!bin/bash
sudo apt install openjdk-8-jdk -y

#jenkins install
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add 

sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt update
sudo apt install Jenkins -y

systemctl start jenkins
cat /var/lib/jenkins/secrets/initialAdminPassword

sleep 15    #sleep for you to copy the password
