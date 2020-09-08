output "address" {
  value = "${aws_elb.bo-web.dns_name}"
}
