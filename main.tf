resource "aws_vpc" "myvpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "VPC"
  }
}

resource "aws_subnet" "pubsub" {
  vpc_id              = aws_vpc.myvpc.id
  cidr_block          = "10.0.1.0/24"
  availability_zone   = "ap-south-1a"
  
  tags = {
    Name = "PUBLIC SUBNET"
  }
}

resource "aws_subnet" "prisub" {
  vpc_id                 = aws_vpc.myvpc.id
  cidr_block             = "10.0.2.0/24"
  availability_zone      ="ap-south-1b"
  
  tags = {
    Name = "PRIVATE SUBNET"
  }
}

resource "aws_subnet" "prisub2" {
  vpc_id              = aws_vpc.myvpc.id
  cidr_block          = "10.0.3.0/24"
  availability_zone   ="ap-south-1c"

  tags = {
    Name = "PRIVATE SUBNET 2"
  }
}

resource "aws_internet_gateway" "tigw" {
  vpc_id            = aws_vpc.myvpc.id

  tags = {
    Name = "INTERNET GATEWAY"
  }
}

resource "aws_route_table" "pubrt" {
  vpc_id           = aws_vpc.myvpc.id

  route {
    cidr_block    = "0.0.0.0/0"
    gateway_id    = aws_internet_gateway.tigw.id
  }

  tags = {
    Name = "PUBLIC ROUTE TABLE"
  }
}

resource "aws_route_table_association" "pubsubassociation" {
  subnet_id         = aws_subnet.pubsub.id
  route_table_id    = aws_route_table.pubrt.id
}

resource "aws_eip" "teip" {
        vpc      = true
}

resource "aws_nat_gateway" "tnat" {
  allocation_id   = aws_eip.teip.id
  subnet_id       = aws_subnet.pubsub.id

  tags = {
    Name = "NAT-GATEWAY"
  }
}


resource "aws_route_table" "prirt1" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.tnat.id
  }

  tags = {
    Name = "PRIVATE ROUTE TABLE"
  }
}

resource "aws_route_table_association" "prisubassociation" {
  subnet_id      = aws_subnet.prisub.id
  route_table_id = aws_route_table.prirt1.id
}

resource "aws_route_table" "prirt2" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.tnat.id
  }

  tags = {
    Name = "PRIVATE ROUTE TABLE 2"
  }
}

resource "aws_route_table_association" "prisubassociation2" {
  subnet_id      = aws_subnet.prisub2.id
  route_table_id = aws_route_table.prirt2.id
}

resource "aws_security_group" "pubsg" {
  name        = "pubsg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.myvpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PUBLIC SECURITY GROUP"
  }
}

resource "aws_security_group" "prisg" {
  name            = "prisg"
  description     = "Allow TLS inbound traffic from Public Subnet"
  vpc_id          = aws_vpc.myvpc.id
 ingress {
    description      = "TLS from VPC"
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["10.0.1.0/24"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PRIVATE SECURITY GROUP"
  }
}

resource "aws_instance" "pub_instance" {
  ami                                 = "ami-052cef05d01020f1d"
  instance_type                       = "t2.micro"
  availability_zone                   = "ap-south-1a"
  associate_public_ip_address         = "true"
  vpc_security_group_ids              = [aws_security_group.pubsg.id]
  subnet_id                           = aws_subnet.pubsub.id
  key_name                            = "linux_key"
  user_data                           = <<-EOF
                                        #! /bin/bash
                                        yum install httpd php-mysql -y
                                        amazon-linux-extras install -y php7.3
                                        cd /var/www/html
                                        echo "healthy" > healthy.html
                                        wget https://wordpress.org/latest.tar.gz
                                        tar -xzf latest.tar.gz
                                        cp -r wordpress/* /var/www/html/
                                        rm -rf wordpress
                                        rm -rf latest.tar.gz
                                        chmod -R 755 wp-content
                                        chown -R apache: apache wp-content
                                        wget https://s3.amazonaws.com/bucketforwordpresslab-donotdelete/htaccess.txt
                                        mv htaccess.txt .htaccess
                                        chkconfig httpd on
                                        service httpd start

                                        EOF

    tags = {
    Name = "WEBSERVER"
  }
}

resource "aws_instance" "pri_instance" {
  ami                                 = "ami-052cef05d01020f1d"
  instance_type                       = "t2.micro"
  availability_zone                   = "ap-south-1b"
  associate_public_ip_address         = "false"
  vpc_security_group_ids              = [aws_security_group.prisg.id]
  subnet_id                           = aws_subnet.prisub.id
  key_name                            = "linux_key"
  
tags = {
    Name = "DB"
  }
}

resource "aws_security_group" "rdssg" {
	name		        = "rdsSecu-group"
	description 	  = "Allow inbound traffic from application layer" 
	vpc_id 		      = aws_vpc.myvpc.id

	ingress {
		description = "Allow inbound traffic" 
		from_port   = 3306
		to_port     = 3306
		protocol    = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

	egress {
		from_port	  = 32768
		to_port		  = 65535
		protocol	  = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	tags = {
		name = "rds-SG"
	}
}

resource "aws_db_subnet_group" "subgrp" {
	name          = "rds_1"
	subnet_ids    = [aws_subnet.prisub.id, aws_subnet.prisub2.id]
	
	tags = {
	name          = "rds-2"
	}
}

resource "aws_db_instance" "rds" {
	db_subnet_group_name      = aws_db_subnet_group.subgrp.id
	engine 	                  = "mysql"
	name                      = "hashdb"
	allocated_storage         = 20
	storage_type              = "gp2"
	engine_version            = "8.0.28"
	instance_class            = "db.t2.micro"
	multi_az                  = true
	username	          = "admin"
	password	          = "admin123"
	vpc_security_group_ids    = [aws_security_group.rdssg.id] 	
	skip_final_snapshot       = true
	}

