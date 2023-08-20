terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.12.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}


resource "aws_vpc" "main" {
  cidr_block = "192.168.0.0/16"

  tags = {
    Name = "vpc-demo"
  }
}

resource "aws_subnet" "pub" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.8.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "public-sub"
  }
}

resource "aws_subnet" "priv" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.9.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "private-sub"
  }
}

resource "aws_subnet" "nava-sub" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "192.168.10.0/24"
  availability_zone = "us-east-1c"
  tags = {
    Name = "nava-sub"
  }
}


resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw1"
  }
}


resource "aws_route_table" "pubrt" {
  vpc_id = aws_vpc.main.id



  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }


  tags = {
    Name = "public-rt"
  }
}


resource "aws_route_table_association" "pubass" {
  subnet_id      = aws_subnet.pub.id
  route_table_id = aws_route_table.pubrt.id
}



resource "aws_nat_gateway" "ng" {
  allocation_id = aws_eip.elastic.id
  subnet_id     = aws_subnet.pub.id

  tags = {
    Name = "NAT1"
  }
}


resource "aws_eip" "elastic" {
  vpc = true # If using a VPC
}




resource "aws_route_table" "prirt" {
  vpc_id = aws_vpc.main.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.ng.id
  }

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "priass" {
  subnet_id      = aws_subnet.priv.id
  route_table_id = aws_route_table.prirt.id
}

resource "aws_db_instance" "default" {
  allocated_storage    = 10
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = "akki"
  password             = "123456789"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  db_subnet_group_name = aws_db_subnet_group.mera-vpc-ka-subnet.name
  vpc_security_group_ids =  [aws_security_group.rds-sg.id]
}

resource "aws_db_subnet_group" "mera-vpc-ka-subnet" {
  name       = "main"
  subnet_ids = [aws_subnet.priv.id,aws_subnet.nava-sub.id]

  tags = {
    Name = "My DB subnet group"
}

}


resource "aws_security_group" "rds-sg" {
  name        = "rdssg"
  vpc_id      = aws_vpc.main.id


  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["192.168.0.0/16"]

  }
   ingress {

    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["192.168.0.0/16"]
   }




}

resource "aws_iam_role" "test_role" {
  name = "s3kafull"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "test_policy" {
  name = "s3-full-access-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "s3:*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.test_role.name
  policy_arn = aws_iam_policy.test_policy.arn  # Use aws_iam_policy here
}

resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = aws_iam_role.test_role.name
}

resource "aws_instance" "tomcat" {
  ami           = "ami-08a52ddb321b32a8c"
  instance_type = "t2.micro"
  key_name      = "ak"
  iam_instance_profile = aws_iam_instance_profile.test_profile.name
 vpc_security_group_ids = [aws_security_group.tom-sg.id]
 subnet_id = aws_subnet.priv.id
 associate_public_ip_address = false
  user_data = <<EOF
#!/bin/bash
sudo dnf install java-11-amazon-corretto -y
sudo yum install mariadb105-devel.x86_64 -y
sudo systemctl start mariadb.service
sudo systemctl enable mariadb.service
wget https://dlcdn.apache.org/tomcat/tomcat-8/v8.5.92/bin/apache-tomcat-8.5.92-windows-x64.zip
sudo unzip apache-tomcat-8.5.92-windows-x64.zip
sudo mv apache-tomcat-8.5.92 /mnt/tomcat
wget https://s3-us-west-2.amazonaws.com/studentapi-cit/student.war
sudo mv ./student.war /mnt/tomcat/webapps
wget https://s3-us-west-2.amazonaws.com/studentapi-cit/mysql-connector.jar
sudo mv ./mysql-connector.jar /mnt/tomcat/lib
sudo chmod 0755 /mnt/tomcat/bin/*
sudo bash /mnt/tomcat/bin/catalina.sh start
echo "<Resource name="jdbc/TestDB" auth="Container" type="javax.sql.DataSource"
           maxTotal="500" maxIdle="30" maxWaitMillis="1000"
           username="admin" password="123456789" driverClassName="com.mysql.jdbc.Driver"
           url="jdbc:mysql://${aws_db_instance.default.endpoint}/app"/>" > /mnt/file1
sed -i '/<Context>/r /mnt/file1' /mnt/tomcat/conf/context.xml
mysql -h ${aws_db_instance.default.endpoint} -u akki -p123456789
CREATE DATABASE app;
CREATE TABLE if not exists students(student_id INT NOT NULL AUTO_INCREMENT,
        student_name VARCHAR(100) NOT NULL,
        student_addr VARCHAR(100) NOT NULL,
        student_age VARCHAR(3) NOT NULL,
        student_qual VARCHAR(20) NOT NULL,
        student_percent VARCHAR(10) NOT NULL,
        student_year_passed VARCHAR(10) NOT NULL,
        PRIMARY KEY (student_id)
);
sudo bash /mnt/tomcat/bin/catalina.sh stop
sudo bash /mnt/tomcat/bin/catalina.sh start

EOF

}


resource "aws_security_group" "tom-sg" {
  name        = "TOMCAT-SG"
  description = "ssh"
    vpc_id      = aws_vpc.main.id

  ingress {

    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["192.168.0.0/16"]
   }
   ingress {

    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["192.168.0.0/16"]
   }
   ingress {

    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["192.168.0.0/16"]
   }




  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  tags = {
    Name = "tomcat-sg"
  }
}

resource "aws_instance" "nginx" {
  ami           = "ami-08a52ddb321b32a8c"
  instance_type = "t2.micro"
  key_name      = "ak"
  vpc_security_group_ids = [aws_security_group.nginx-sg.id]
  subnet_id = aws_subnet.pub.id
  associate_public_ip_address = true

user_data = <<EOF
#!/bin/bash
sudo yum install nginx -y
sudo systemctl start nginx
sudo systemctl enable nginx
 echo 'server {
                listen 80;
                location / {
                   proxy_pass http://${aws_instance.tomcat.private_ip}:8080;
                }
              }' > /etc/nginx/conf.d/reverse-proxy.conf

sudo systemctl restart nginx
EOF


}

resource "aws_security_group" "nginx-sg" {
  name        = "NG-SG"
  description = "ssh"
    vpc_id      = aws_vpc.main.id

  ingress {

    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
   }
   ingress {

    from_port        = 80
    to_port          = 80
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
    Name = "nginx-sg"
  }
}
