locals {
  vnet_cidr =  "10.25.0.0/16"
  vnet_default_subnet_cidr = [ "10.25.0.0/24" ]
  // "A list of hosts/networks to open up SSH access to."
  mgmt_allowed_hosts = [
    // Allow from vnet mainsubnet
    "10.25.0.0/24"
  ]
  // "A list of hosts/networks to open up WireGuard access to."
  sg_wg_allowed_subnets = [
    "0.0.0.0/0"
  ]
  // "The UDP port WireGuard should listen on."
  // Also the UDP openVPN Port on 500 could be used, for more support in other networks
  wg_server_port = 51820
}

resource "azurerm_resource_group" "wireguardvm_rg" {
  name     = "${var.application_short}-${var.location_short}-wireguardvm-${var.environment_short}-rg"
  location = var.location
  tags     = var.tags_default
}

# ╔══════════════════════════════════════════════════════════╗
# ║                           VNET                           ║
# ╚══════════════════════════════════════════════════════════╝

resource "azurerm_virtual_network" "testbench" {
  name                = "${var.application_short}-${var.location_short}-wireguardvm-${var.environment_short}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.wireguardvm_rg.name
  tags                = var.tags_default

  address_space       = [ local.vnet_cidr ]
}

resource "azurerm_subnet" "testbench_main_subnet" {
  name                 = "mainsubnet"
  resource_group_name  = azurerm_resource_group.wireguardvm_rg.name

  virtual_network_name = azurerm_virtual_network.testbench.name
  address_prefixes     = local.vnet_default_subnet_cidr
}

# ╔══════════════════════════════════════════════════════════╗
# ║                         Firewall                         ║
# ╚══════════════════════════════════════════════════════════╝
resource "azurerm_network_security_group" "testbench" {
  name = "${var.application_short}-${var.location_short}-wireguardvm-${var.environment_short}-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.wireguardvm_rg.name
  tags                = var.tags_default
}

resource "azurerm_network_security_rule" "ssh" {
  count = length(local.mgmt_allowed_hosts)

  name                        = "ssh-${count.index}"
  resource_group_name         = azurerm_resource_group.wireguardvm_rg.name
  network_security_group_name = azurerm_network_security_group.testbench.name

  priority = 100 + count.index

  direction = "Inbound"
  access    = "Allow"
  protocol  = "Tcp"

  source_port_range     = "*"
  source_address_prefix = element(local.mgmt_allowed_hosts, count.index)

  destination_address_prefix = "*"
  destination_port_range     = "22"
}


resource "azurerm_network_security_rule" "wireguard" {
  count = length(local.mgmt_allowed_hosts)

  name                        = "wireguard-${count.index}"
  resource_group_name         = azurerm_resource_group.wireguardvm_rg.name
  network_security_group_name = azurerm_network_security_group.testbench.name

  priority = 200 + count.index

  direction = "Inbound"
  access    = "Allow"
  protocol  = "Udp"

  source_port_range     = "*"
  source_address_prefix = element(local.sg_wg_allowed_subnets, count.index)

  destination_address_prefix = "*"
  destination_port_range     = local.wg_server_port
}
