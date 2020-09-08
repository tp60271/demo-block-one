# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "bo-default" {
  cidr_block = "10.1.0.0/16"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "bo-default" {
  vpc_id = "${aws_vpc.bo-default.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "bo-internet_access" {
  route_table_id         = "${aws_vpc.bo-default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.bo-default.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "bo-default" {
  vpc_id                  = "${aws_vpc.bo-default.id}"
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
}

# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "bo-elb" {
  name        = "terraform_web_elb"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.bo-default.id}"

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

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "bo-default" {
  name        = "terraform_security_group"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.bo-default.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "bo-web" {
  name = "terraform-web-elb"

  subnets         = ["${aws_subnet.bo-default.id}"]
  security_groups = ["${aws_security_group.bo-elb.id}"]
  instances       = ["${aws_instance.bo-web.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${var.public_key_path}"
}

resource "aws_instance" "bo-web" {
  # The connection block tells our provisioner how to
  # communicate with the resource (instance)
  connection {
    # The default username for our AMI
    user = "ubuntu"
    host = "${self.public_ip}"
    # The connection will use the local SSH agent for authentication.
  }

  instance_type = "t3.micro"

  # Lookup the correct AMI based on the region
  # we specified
  ami = "${lookup(var.aws_amis, var.aws_region)}"

  # The name of our SSH keypair we created above.
  key_name = "${aws_key_pair.auth.id}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.bo-default.id}"]

  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_id = "${aws_subnet.bo-default.id}"

  user_data           = "${file("${path.module}/bootstrap_nginx.tpl")}"

  tags = {
		name = "terraform-firsts"	
		cost-center = "free"
	}

}