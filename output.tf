output wireguard_vpn_node_public_ip {
  description = "The public IP of the Wireguard VPN instance."
  value       = azurerm_public_ip.wireguardvm_public_ip.ip_address
}
