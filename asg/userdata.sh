#!/bin/bash -v
sudo yum -y update
sudo amazon-linux-extras install nginx1 -y 
sudo service nginx start
