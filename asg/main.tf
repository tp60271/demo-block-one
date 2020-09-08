# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

locals {
  availability_zones = "${split(",", var.availability_zones)}"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "bo-asg-default" {
  cidr_block = "10.2.0.0/16"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "bo-asg-default" {
  vpc_id = "${aws_vpc.bo-asg-default.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "bo-asg-internet_access" {
  route_table_id         = "${aws_vpc.bo-asg-default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.bo-asg-default.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "bo-asg-default-1" {
  vpc_id                  = "${aws_vpc.bo-asg-default.id}"
  cidr_block              = "10.2.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1c"
}

resource "aws_subnet" "bo-asg-default-2" {
  vpc_id                  = "${aws_vpc.bo-asg-default.id}"
  cidr_block              = "10.2.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

resource "aws_elb" "bo-asg-web-elb" {
  name = "bo-asg-terraform-web-asg-elb"
  subnets         = ["${aws_subnet.bo-asg-default-1.id}","${aws_subnet.bo-asg-default-2.id}"]
  security_groups = ["${aws_security_group.bo-asg-default.id}"]

  # The same availability zone as our instances
  #availability_zones = "${local.availability_zones}"

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }
}

resource "aws_autoscaling_group" "bo-asg-web-asg" {
  availability_zones   = "${local.availability_zones}"
  name                 = "bo-asg-terraform-web-asg"
  max_size             = "${var.asg_max}"
  min_size             = "${var.asg_min}"
  desired_capacity     = "${var.asg_desired}"
  force_delete         = true
  launch_configuration = "${aws_launch_configuration.bo-asg-web-lc.name}"
  load_balancers       = ["${aws_elb.bo-asg-web-elb.name}"]
  vpc_zone_identifier  = ["${aws_subnet.bo-asg-default-1.id}","${aws_subnet.bo-asg-default-2.id}"]

  #vpc_zone_identifier = ["${split(",", var.availability_zones)}"]
  tag {
    key                 = "Name"
    value               = "bo-asg-web-asg"
    propagate_at_launch = "true"
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${var.public_key_path}"
}

resource "aws_launch_configuration" "bo-asg-web-lc" {
  name          = "bo-asg-terraform-example-lc"
  image_id      = "${lookup(var.aws_amis, var.aws_region)}"
  instance_type = "${var.instance_type}"

  # Security group
  security_groups = ["${aws_security_group.bo-asg-default.id}"]
  user_data       = "${file("bootstrap_nginx.tpl")}"
  #key_name        = "${var.key_name}"
  key_name = "${aws_key_pair.auth.id}"
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "bo-asg-default" {
  name        = "terraform_example_sg"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.bo-asg-default.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
