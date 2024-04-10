resource "aws_vpc" "myvpc" {
    cidr_block = var.cidr
    tags = {
      Name = "mainVPC"
    }
}

resource "aws_vpc" "peervpc" {
    cidr_block = "10.4.0.0/20"
    tags = {
      Name = "peerVPC"
    }
}

resource "aws_vpc_peering_connection" "myvpc_to_peervpc" {
    vpc_id = aws_vpc.myvpc.id
    peer_vpc_id = aws_vpc.peervpc.id
    auto_accept = true
    tags = {
        Name = "myvpc_to_peervpc_peering"
  }
  
}

resource "aws_subnet" "sub1" {
     vpc_id = aws_vpc.myvpc.id
     cidr_block = var.cidr_sub1
     availability_zone = var.sub1_availability_zone
     map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "myigw" {
    vpc_id = aws_vpc.myvpc.id
  
}

resource "aws_route_table" "myrt" {
    vpc_id = aws_vpc.myvpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myigw.id
    }
}

resource "aws_route_table_association" "myrta" {
     subnet_id = aws_subnet.sub1.id
     route_table_id = aws_route_table.myrt.id
}

resource "aws_security_group" "websg" {
    name = "web"
    vpc_id = aws_vpc.myvpc.id

    ingress {
        description = "SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "HTTP from VPC"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "HTTPS from VPC"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "web-sg"
    }
}

resource "aws_autoscaling_group" "myasg" {
    name = "pip_asg"
    launch_configuration = aws_launch_configuration.mylc.name
    min_size = 3
    max_size = 3
    desired_capacity = 3
    vpc_zone_identifier = [ aws_subnet.sub1.id ]

    tag {
      key = "Name"
      value = "asg_instance"
      propagate_at_launch = true
    }
  
}

resource "aws_launch_configuration" "mylc" {
    name = "asglc"
    image_id = "ami-09c8d5d747253fb7a"
    instance_type = "t2.micro"
    security_groups = [ aws_security_group.websg.id ]
    user_data = <<-EOF
                 #!/bin/bash
                 echo "Hello, World!" > index.html
                 nohup python -m SimpleHTTPServer 80 &
                 EOF
    lifecycle {
        create_before_destroy = true
    }
  
}

resource "aws_elb" "example_elb" {
  name               = "asgelb"
  availability_zones = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  
  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    unhealthy_threshold = 2
    healthy_threshold   = 2
  }

    instances = aws_instance.myInstance[*].id
}

resource "aws_instance" "asg_instances" {
  count              = 3
  ami                = "ami-09c8d5d747253fb7a"  # Update with your desired AMI ID
  instance_type      = "t2.micro"        # Update with your desired instance type
  security_groups    = [aws_security_group.websg.id]
  user_data          = <<-EOF
                        #!/bin/bash
                        echo "Hello, World!" > index.html
                        nohup python -m SimpleHTTPServer 80 &
                        EOF

  tags = {
    Name = "asg-instance-${count.index}"
  }
}

resource "aws_network_interface" "myvnet0" {
    subnet_id = aws_subnet.sub1.id
    private_ips = [ "10.1.4.89" ]
  tags = {
    Name = "vnet0"
  }
}

resource "aws_s3_bucket" "myBucket" {
    bucket = "terraformpipproject"
  
}

resource "aws_key_pair" "MyKey" {
    key_name = "tfkey"
    public_key = file("keys/tfkey.pub")
}

resource "aws_instance" "myInstance" {
    ami = "ami-09c8d5d747253fb7a"
    instance_type = "t2.micro"
    subnet_id = aws_subnet.sub1.id
    key_name = aws_key_pair.MyKey.key_name

    tags = {
        Name = "terraform_instance"
    }
  
}

resource "aws_eip" "static_ip" {
    instance = aws_instance.myInstance.id
  
}