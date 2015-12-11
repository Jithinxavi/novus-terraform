# Specify the provider and access details
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = "${var.aws_region}"
}

# Creating VPC 

resource "aws_vpc" "darby" {
  cidr_block = "${var.vpc_cidr}"
  tags {
     Name = "DARBY-VPC"
    }
}

# Create an internet gateway for internet access.

resource "aws_internet_gateway" "darby_igw" {
  vpc_id = "${aws_vpc.darby.id}"
}

# Public route table creation

resource "aws_route_table" "public_access_rt" {
    vpc_id = "${aws_vpc.darby.id}"

    route {
        cidr_block  = "0.0.0.0/0"
        gateway_id  = "${aws_internet_gateway.darby_igw.id}"
    }

    tags {
        Name = "PUB-ROUTE-TABLE"
    }
}

# Private route table creation

resource "aws_route_table" "private_access_rt" {
    vpc_id = "${aws_vpc.darby.id}"

    route {
        cidr_block  = "0.0.0.0/0"
        instance_id = "${aws_instance.nat.id}"
    }

    tags {
        Name = "PRV-ROUTE-TABLE"
    }
}

# Routing table association to Public subnet

resource "aws_route_table_association" "public_access_ra" {
    subnet_id = "${aws_subnet.darby_public.id}"
    route_table_id = "${aws_route_table.public_access_rt.id}"
}

# Routing table association to Private subnet

resource "aws_route_table_association" "private_access_ra" {
    subnet_id = "${aws_subnet.darby_private.id}"
    route_table_id = "${aws_route_table.private_access_rt.id}"
}

# Create a subnet to launch instances into Public subnet

resource "aws_subnet" "darby_public" {
  vpc_id                  = "${aws_vpc.darby.id}"
  cidr_block              = "${var.public_subnet_cidr}"
  map_public_ip_on_launch = true
  tags {
      Name = "DARBY-PUB-SUBNET"
    }
}

# Create a subnet to launch instances into Private Subnet

resource "aws_subnet" "darby_private" {
  vpc_id                  = "${aws_vpc.darby.id}"
  cidr_block              = "${var.private_subnet_cidr}"
  tags {
      Name = "DARBY-PRV-SUBNET"
    }
}


# Security group for the ELB so it is accessible via the web

resource "aws_security_group" "elb" {
  name        = "DARBY-ELB-SG"
  description = "Used in the darby"
  vpc_id      = "${aws_vpc.darby.id}"

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

# Web server security group

resource "aws_security_group" "darby_web" {
  name        = "DARBY-WEB-SG"
  description = "Darby Web instance security group"
  vpc_id      = "${aws_vpc.darby.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  # HTTP access from the VPC
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

# App server security group

resource "aws_security_group" "darby_app" {
  name        = "DARBY-APP-SG"
  description = "Darby App instance security group"
  vpc_id      = "${aws_vpc.darby.id}"

  # SSH access from VPC CIDR block
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    #security_groups = ${self.aws_security_group.darby_app.name}
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  # HTTP access from abywhere
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

# Darby NAT security group

resource "aws_security_group" "darby_nat" {
  name        = "DARBY-NAT-SG"
  description = "Darby NAT instance security group"
  vpc_id      = "${aws_vpc.darby.id}"

  # SSH access from VPC CIDR
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   # HTTPS access from the VPC
  ingress {
    from_port   = 443
    to_port     = 443
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

resource "aws_elb" "web_elb" {
  name = "DARBY-WEB-ELB"

  subnets         = ["${aws_subnet.darby_public.id}"]
  security_groups = ["${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.web.id}"]
  # Multiple instance behind the ELB
  # instances       = ["${aws_instance.web.id}","${aws_instance.app.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

}

# Launching Web instance 

resource "aws_instance" "web" {
  instance_type = "t2.micro"

  # Lookup the correct AMI based on the region we specified
  ami = "${lookup(var.aws_web_ami, var.aws_region)}"

  # The name of the SSH keypair.
  key_name = "${var.aws_key_name.id}"

  # Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.darby_web.id}"]
  subnet_id = "${aws_subnet.darby_public.id}"
  tags {
    Name = "DARBY-WEB"
  }
}

# Launching App instance 

resource "aws_instance" "app" {
  instance_type = "t2.micro"

  # Lookup the correct AMI based on the region we specified
  ami = "${lookup(var.aws_app_ami, var.aws_region)}"

  # The name of the SSH keypair.
  key_name = "${var.aws_key_name.id}"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = ["${aws_security_group.darby_app.id}"]
  subnet_id = "${aws_subnet.darby_private.id}"
  tags {
    Name = "DARBY-APP"
  }
}

# Launching NAT instance 

resource "aws_instance" "nat" {
  instance_type = "m1.small"
  ami = "${var.aws_nat_ami.ami_image}"
  key_name = "${var.aws_key_name.id}"

  # Our Security group to allow HTTP and SSH access

  vpc_security_group_ids = ["${aws_security_group.darby_nat.id}"]
  subnet_id = "${aws_subnet.darby_public.id}"
  associate_public_ip_address = true
  source_dest_check = false
  
  tags {
    Name = "DARBY-NAT"
  }
}
