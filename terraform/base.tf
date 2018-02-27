provider "aws" {
	region     = "${var.region}"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
  filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
}

resource "aws_security_group" "permit-ssh" {
  	name = "ssh"
  	description = "Permit SSH"
	ingress {
	  	from_port = 22
	  	to_port = 22
	  	protocol = "tcp"
	  	cidr_blocks = ["0.0.0.0/0"]
  	}
	tags {
	    Name = "permit_ssh"
  	}
}

resource "aws_security_group" "permit-dell" {
  	name = "dell"
  	description = "Permit Dell"
	ingress {
	  	from_port = 21
	  	to_port = 21
	  	protocol = "tcp"
	  	cidr_blocks = ["0.0.0.0/0"]
  	}
	tags {
	    Name = "permit_ssh"
  	}
}

resource "aws_security_group" "permit-https" {
  	name = "https"
  	description = "Permit HTTPS"
	ingress {
	  	from_port = 443
	  	to_port = 443
	  	protocol = "tcp"
	  	cidr_blocks = ["0.0.0.0/0"]
  	}
	tags {
	    Name = "permit_https"
  	}
}

resource "aws_security_group" "permit-pks" {
  	name = "pks"
  	description = "Permit PKS"
	ingress {
	  	from_port = 8443
	  	to_port = 8443
	  	protocol = "tcp"
	  	cidr_blocks = ["0.0.0.0/0"]
  	}
	tags {
	    Name = "permit_https"
  	}
}

resource "aws_instance" "base" {
	ami = "${data.aws_ami.ubuntu.id}"
	instance_type = "t2.micro" 
	key_name = "grant_pub"
	tags {
		Name = "jump"
	}
	vpc_security_group_ids = [
		"${aws_security_group.permit-ssh.id}",
        "${aws_security_group.permit-https.id}",
		"${aws_security_group.permit-dell.id}",
		"${aws_security_group.permit-pks.id}"
		]
	provisioner "remote-exec" {
        inline = [
        "sudo sed -i '$ a 127.0.0.1 pks.wwko2018.com' /etc/hosts"
        ]
        connection {
	        type = "ssh"
	        user = "ubuntu"
	        private_key = "${file(var.private_key)}"
    	}
    }
}

resource "aws_eip" "base" {
  instance = "${aws_instance.base.id}"
  vpc      = true
}

data "aws_route53_zone" "wwko2018" {
  name         = "wwko2018.com."
  private_zone = false
}

resource "aws_route53_record" "jump" {
   zone_id = "${data.aws_route53_zone.wwko2018.zone_id}"
   name = "jump.wwko2018.com"
   type = "A"
   ttl = "300"
   records = ["${aws_eip.base.public_ip}"]
}

resource "aws_route53_record" "pks" {
   zone_id = "${data.aws_route53_zone.wwko2018.zone_id}"
   name = "pks.wwko2018.com"
   type = "A"
   ttl = "300"
   records = ["${aws_eip.base.public_ip}"]
}

resource "aws_elb" "pks" {
	name = "pks-lb"
	availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
	
	listener {
    instance_port      = 8443
    instance_protocol  = "https"
    lb_port            = 8443
    lb_protocol        = "https"
	ssl_certificate_id = "arn:aws:acm:us-west-2:495078824317:certificate/d06af351-75f1-43cb-b466-9462c4a57670"
	}

	instances                   = ["${aws_instance.base.id}"]
    cross_zone_load_balancing   = false
    idle_timeout                = 400
    connection_draining         = true
    connection_draining_timeout = 400

}