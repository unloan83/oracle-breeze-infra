output "breeze_trading_private_ip" {
  description = "Primary private IPv4 address of breeze-trading."
  value       = data.oci_core_vnic.breeze_trading.private_ip_address
}

output "breeze_trading_public_ip" {
  description = "Reserved public IPv4 address of breeze-trading."
  value       = oci_core_public_ip.breeze_trading.ip_address
}

output "vscode_dev_private_ip" {
  description = "Primary private IPv4 address of vscode-dev."
  value       = data.oci_core_vnic.vscode_dev.private_ip_address
}

output "vscode_dev_public_ip" {
  description = "Ephemeral public IPv4 address of vscode-dev for Remote-SSH bootstrap."
  value       = data.oci_core_vnic.vscode_dev.public_ip_address
}

output "breeze_trading_ssh_command" {
  description = "SSH command for the Breeze trading VM."
  value       = "ssh ubuntu@${oci_core_public_ip.breeze_trading.ip_address}"
}

output "vscode_dev_ssh_command" {
  description = "SSH command for the VS Code development VM."
  value       = "ssh ubuntu@${data.oci_core_vnic.vscode_dev.public_ip_address}"
}
