# Cloud Engineer Portfolio — Jin

## Proyecto 1: VPC + EC2 con Terraform
Infraestructura en AWS desplegada con Terraform:
- VPC con subred pública y privada
- Internet Gateway + Route Table
- Security Group (SSH restringido, HTTP/HTTPS abierto)
- EC2 t2.micro con nginx corriendo

### Cómo usar
```bash
terraform init
terraform apply
```

## Stack
- AWS (VPC, EC2, Security Groups)
- Terraform
- Amazon Linux 2023 + nginx
