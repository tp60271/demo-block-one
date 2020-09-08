output "security_group" {
  value = "${aws_security_group.bo-default.id}"
}

output "launch_configuration" {
  value = "${aws_launch_configuration.bo-web-lc.id}"
}

output "asg_name" {
  value = "${aws_autoscaling_group.bo-web-asg.id}"
}

output "elb_name" {
  value = "${aws_elb.bo-web-elb.dns_name}"
}
