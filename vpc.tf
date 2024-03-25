resource "aws_vpc" "dev" {
  cidr_block = var.cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = var.vpc_name
  }
}

resource "aws_internet_gateway" "igwsS" {
    vpc_id = aws_vpc.dev.id
    tags = {
        Name = "${var.vpc_name}-igw"
    }
  
}

resource "aws_subnet" "publicsubnets" {
    count = 3
    vpc_id = aws_vpc.dev.id
    cidr_block = element(var.cidr_block_publicsubnets,count.index)
    availability_zone = element(var.azs,count.index)
    map_public_ip_on_launch = true
    tags = {
        Name = "${var.vpc_name}-publicsubnets${count.index+1}"
    }
  
}

resource "aws_route_table" "rt" {
    vpc_id = aws_vpc.dev.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
  tags = {
    Name = "${var.vpc_name}-rt"
  }
}

resource "aws_route_table_association" "subnets" {
    count = 3
    subnet_id = element(aws_subnet.publicsubnets.*.id,count.index)
    route_table_id = aws_route_table.rt.id
  
}

resource "aws_security_group" "sg" {
    vpc_id = aws_vpc.dev.id
    name = "devvpc"
    description = "allow all rules"
    tags = {
        Name = "${var.vpc_name}-sg"
    }
    ingress  {
        to_port = 0
        from_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
   egress  {
    to_port = 0
        from_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
   }
}

resource "aws_instance" "albserver" {
    count =1
    ami = var.ami
    key_name = var.key_name
    instance_type = var.instance_type
    vpc_security_group_ids = [aws_security_group.sg.id]
    subnet_id = element(aws_subnet.publicsubnets.*.id,count.index)
    associate_public_ip_address = true
    # private_ip = var.private_ip
    iam_instance_profile= var.iam_instance_profile
    user_data=<<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install apache2 -y
    sudo systemctl start apache2
    EOF  
    tags = {
        Name = "${var.vpc_name}-server"
    }
}
resource "aws_instance" "albserver1" {
    count =1
    ami = var.ami1
    key_name = var.key_name
    instance_type = var.instance_type
    vpc_security_group_ids = [aws_security_group.sg.id]
    subnet_id = element(aws_subnet.publicsubnets.*.id,count.index)
    associate_public_ip_address = true
    # private_ip = var.private_ip
    iam_instance_profile= var.iam_instance_profile
    user_data=<<-EOF
    #!/bin/bash
    yum update -y
amazon-linux-extras install nginx1.12 -y
service nginx start
echo "<div><h1>PUBLIC-SERVER</h1></div>" >> /usr/share/nginx/html/index.html
echo "<div><h1>DEV-OPS2024</h1></div>" >> /usr/share/nginx/html/index.html
EOF
    
    tags = {
        Name = "${var.vpc_name}-server"
    }
}

resource "aws_lb_target_group" "albtg" {
    vpc_id = aws_vpc.dev.id
    name = "ramtg"
    protocol = "HTTP"
    port =80
    health_check {
    enabled             = true
    port                = 80
    interval            = 30
    protocol            = "HTTP"
    path                = "/index.html"
    matcher             = "200"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    }
    tags = {
        Name = "${var.vpc_name}-alb"
    }
  
}

resource "aws_lb_target_group_attachment" "albattach" {
    target_group_arn = aws_lb_target_group.albtg.arn
    target_id = aws_instance.albserver[0].id
  
}
resource "aws_lb_target_group_attachment" "albattach1" {
    target_group_arn = aws_lb_target_group.albtg.arn
    target_id = aws_instance.albserver1[0].id
  
}

resource "aws_lb" "applicationloadbalancer" {
    load_balancer_type = "application"
    name = "ramalb"
    security_groups = [aws_security_group.sg.id]
    subnets = [aws_subnet.publicsubnets[0].id,aws_subnet.publicsubnets[1].id]
    
  
}

resource "aws_lb_listener" "alblisten" {
    load_balancer_arn = aws_lb.applicationloadbalancer.arn
    protocol = "HTTP"
    port = 80
    default_action {
      type = "forward"
      target_group_arn = aws_lb_target_group.albtg.arn
    }
  
}
