# ============================================================
# cloud-engineer-portfolio — Proyecto 1: VPC + EC2
# Terraform con AWS Provider
# ============================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.3.0"
}

# --- Proveedor AWS ---
# Cambia la región si prefieres otra (us-east-1 es la más barata)
provider "aws" {
  region = "us-east-1"
}

# ============================================================
# VARIABLES
# ============================================================

variable "project_name" {
  description = "Nombre del proyecto, se usa como prefijo en todos los recursos"
  default     = "portfolio-vpc"
}

variable "mi_ip" {
  description = "Tu IP pública para SSH (obtenla en https://checkip.amazonaws.com)"
  type        = string
  # Cámbialo por tu IP real antes de aplicar, ejemplo: "201.234.56.78/32"
  default     = "200.105.99.193/32"
}

variable "ami_id" {
  description = "AMI de Amazon Linux 2023 en us-east-1 (free tier eligible)"
  default     = "ami-0c02fb55956c7d316" # Amazon Linux 2023, us-east-1
}

variable "instance_type" {
  description = "Tipo de instancia (t2.micro es free tier)"
  default     = "t3.micro"
}

# ============================================================
# VPC
# ============================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# ============================================================
# SUBNETS
# ============================================================

# Subred pública — aquí va la EC2 con acceso a internet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true  # Las EC2 aquí reciben IP pública automáticamente

  tags = {
    Name    = "${var.project_name}-subnet-public"
    Project = var.project_name
  }
}

# Subred privada — sin acceso directo a internet (buenas prácticas)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name    = "${var.project_name}-subnet-private"
    Project = var.project_name
  }
}

# ============================================================
# INTERNET GATEWAY
# Permite que la subred pública tenga salida a internet
# ============================================================

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# ============================================================
# ROUTE TABLE — Subred pública
# Todo el tráfico 0.0.0.0/0 sale por el Internet Gateway
# ============================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name    = "${var.project_name}-rt-public"
    Project = var.project_name
  }
}

# Asocia la route table a la subred pública
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ============================================================
# SECURITY GROUP
# Controla qué tráfico entra y sale de la EC2
# ============================================================

resource "aws_security_group" "ec2_sg" {
  name        = "${var.project_name}-sg"
  description = "SG para la EC2 del portfolio"
  vpc_id      = aws_vpc.main.id

  # SSH — solo desde tu IP
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.mi_ip]
  }

  # HTTP — abierto para demo
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS — abierto para demo
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress — todo el tráfico saliente está permitido
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

# ============================================================
# KEY PAIR
# Terraform crea el par de llaves para conectarte por SSH
# IMPORTANTE: guarda la private key que se genera en outputs
# ============================================================

resource "aws_key_pair" "portfolio_key" {
  key_name   = "${var.project_name}-key"
  public_key = file("${path.module}/portfolio-key.pub")

  tags = {
    Name    = "${var.project_name}-key"
    Project = var.project_name
  }
}

# ============================================================
# EC2 INSTANCE
# t2.micro = free tier (750 horas/mes gratis)
# ============================================================

resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = aws_key_pair.portfolio_key.key_name

  # Script que se ejecuta al arrancar la instancia por primera vez
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>Portfolio Cloud Engineer - VPC + EC2 con Terraform</h1>" > /usr/share/nginx/html/index.html
  EOF

  tags = {
    Name    = "${var.project_name}-ec2"
    Project = var.project_name
  }
}

# ============================================================
# OUTPUTS
# Información que Terraform te muestra al terminar el apply
# ============================================================

output "vpc_id" {
  description = "ID de la VPC creada"
  value       = aws_vpc.main.id
}

output "ec2_public_ip" {
  description = "IP pública de la EC2 — úsala para conectarte por SSH"
  value       = aws_instance.web.public_ip
}

output "ec2_public_dns" {
  description = "DNS público de la EC2"
  value       = aws_instance.web.public_dns
}

output "ssh_command" {
  description = "Comando exacto para conectarte por SSH"
  value       = "ssh -i portfolio-key ec2-user@${aws_instance.web.public_ip}"
}

output "web_url" {
  description = "URL para ver la página en el navegador"
  value       = "http://${aws_instance.web.public_ip}"
}
