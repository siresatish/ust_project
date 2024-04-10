output "static_ip_address" {
    value = aws_eip.static_ip.public_ip
}