output "security_group" {
  value = "${aws_security_group.bo-asg-default.id}"
}

output "launch_configuration" {
  value = "${aws_launch_configuration.bo-asg-web-lc.id}"
}

output "asg_name" {
  value = "${aws_autoscaling_group.bo-asg-web-asg.id}"
}

output "elb_name" {
  value = "${aws_elb.bo-asg-web-elb.dns_name}"
}
