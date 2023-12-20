##############################################################
# Description:
# This File is setting up the azure VM With a Wireguard VPN
# The following Services are created in the following order:
# 1. WireGuard private key
# 2.
##############################################################

locals {
  resourcegroup_name = azurerm_resource_group.wireguardvm_rg.name
  wireguardvm_admin_username = "localadmin"
  wireguardvm_admin_password = "12345ABCDEF$"
  wg_client_public_keys = {
    "user1" = {
      "ip"         = "192.168.2.2/32"
      "public_key" = "fs91AsJgtvWCvgAskm/PJ112kmwM7NK6sGfHquE2GwU="
    }
    "user2" = {
      "ip"         = "192.168.2.3/32"
      "public_key" = "bA+y591IY+KN/VaueD3OwHNymm7B7Qds1MN5qy/RvDI="
    }    
  }
  # "The internal network to use for WireGuard. Remember to place the clients in the same subnet."
  wg_server_network_cidr = "192.168.2.0/24"
  wg_server_address           = cidrhost(local.wg_server_network_cidr, 1)
  wg_server_address_with_cidr = "${local.wg_server_address}/${split("/", local.wg_server_network_cidr)[1]}"
  # "Persistent Keepalive - useful for helping connectiona stability over NATs"
  wg_persistent_keepalive = 25
  wg_server_privateKey = "WHgTD53bAihtv9LcVFT3mZIpFam4aW8SSOMWoE37hkg="
}

# ╔══════════════════════════════════════════════════════════╗
# ║                       Managed Identity                   ║
# ╚══════════════════════════════════════════════════════════╝

resource "azurerm_user_assigned_identity" "wireguardvm_identity" {
  name                = "${var.application_short}-${var.location_short}-wireguardvm-${var.environment_short}-identity"
  location            =  var.location
  resource_group_name = azurerm_resource_group.wireguardvm_rg.name
}

resource "azurerm_role_definition" "wireguardvm_user" {
  name  = "vm_user"
  scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  description = "This is a custom role created via Terraform"

  permissions {
    actions = ["*"]
  }

  assignable_scopes = [
    "/subscriptions/${data.azurerm_client_config.current.subscription_id}",
  ]
}

resource "azurerm_role_assignment" "wireguardvm_user" {
  # Assign to ressource Group
  scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"

  // role_definition_id = azurerm_role_definition.wireguardvm_user.role_definition_id
  role_definition_name = "Contributor"
  principal_id       = azurerm_user_assigned_identity.wireguardvm_identity.principal_id
}

resource "azurerm_key_vault_access_policy" "wireguardvm_policy" {
  key_vault_id = data.azurerm_key_vault.secrets-kv.id

  tenant_id = data.azurerm_client_config.current.tenant_id

  object_id = azurerm_user_assigned_identity.wireguardvm_identity.principal_id

  key_permissions = [
    "Get"
  ]

  secret_permissions = [
    "Get",
  ]
}

# ╔══════════════════════════════════════════════════════════╗
# ║                    WireGuard private key                 ║
# ╚══════════════════════════════════════════════════════════╝

resource "azurerm_key_vault_secret" "wireguard_private_key_secret_create" {
  key_vault_id    = data.azurerm_key_vault.secrets-kv.id
  name            = "wireguarde-private-key"
  value           = local.wg_server_privateKey
  content_type    = "text/plain"
  expiration_date = "2033-03-03T10:00:00Z" #Format: (Y-m-d'T'H:M:S'Z')

  // With the lifecycle block and ignore_changes we can prevent the creation of new versions if a key rotates
  # lifecycle {
  #   ignore_changes = [
  #     content_type,
  #     value,
  #     not_before_date,
  #     expiration_date
  #   ]
  # }

  depends_on = [ azurerm_key_vault_access_policy.wireguardvm_policy ]
}


# ╔══════════════════════════════════════════════════════════╗
# ║                    Setup VM Network                      ║
# ╚══════════════════════════════════════════════════════════╝

resource "azurerm_public_ip" "wireguardvm_public_ip" {
  name                = "${var.application_short}-${var.location_short}-wireguardvm-${var.environment_short}-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.wireguardvm_rg.name
  tags                = var.tags_default

  allocation_method   = "Static"
}

resource "azurerm_network_interface" "wireguardvm_nic" {
  name                = "${var.application_short}-${var.location_short}-wireguardvm-${var.environment_short}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.wireguardvm_rg.name
  tags                = var.tags_default



  ip_configuration {
    name                          = "ipconfig-mainsubnet"
    subnet_id                     = azurerm_subnet.testbench_main_subnet.id

    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"

    public_ip_address_id          = azurerm_public_ip.wireguardvm_public_ip.id
  }
}

// Now the Network Security Group to the interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.wireguardvm_nic.id
  network_security_group_id = azurerm_network_security_group.testbench.id
}

# ╔══════════════════════════════════════════════════════════╗
# ║                         User Data                        ║
# ╚══════════════════════════════════════════════════════════╝
data "template_file" "wireguardvm_client_data_json" {
  for_each = local.wg_client_public_keys

  template = file("${path.module}/wireguard_scripts/client_data.tpl")

  vars = {
    user              = each.key
    client_public_key = each.value["public_key"]
    client_ip         = each.value["ip"]

    persistent_keepalive = local.wg_persistent_keepalive
  }
}

locals {
  peers_list      = [for p in data.template_file.wireguardvm_client_data_json : p.rendered]
}

data "template_file" "wireguardvm_user_data" {
  template = file("${path.module}/wireguard_scripts/user_data.sh")

  vars = {
    wg_server_network_cidr      = local.wg_server_network_cidr
    wg_server_address           = local.wg_server_address
    wg_server_address_with_cidr = local.wg_server_address_with_cidr

    wg_server_port = local.wg_server_port

    peers = join("\n", local.peers_list)

    vm_identity_id = azurerm_user_assigned_identity.wireguardvm_identity.id
    vault_name     = data.azurerm_key_vault.secrets-kv.name
    kv_secret_name = azurerm_key_vault_secret.wireguard_private_key_secret_create.name
  }
}

# Render cloud-init config file as base64
data "template_cloudinit_config" "wireguardvm_user_data" {
  gzip          = true
  base64_encode = true

  # Main cloud-init configuration file.
  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.wireguardvm_user_data.rendered
  }
}

# ╔══════════════════════════════════════════════════════════╗
# ║                   Setup VM with Script                   ║
# ╚══════════════════════════════════════════════════════════╝
resource "azurerm_linux_virtual_machine" "wireguardvm" {
  name                = "${var.application_short}-${var.location_short}-wireguardvm-${var.environment_short}-vm"
  location            = var.location
  resource_group_name = azurerm_resource_group.wireguardvm_rg.name
  tags                = var.tags_default

  // Standard_DS1_v2 => vCPU=1; RAM=3.5GB, IOPS=3200, TempStorage=7GB, 49 CHF per Month
  // B2s = vCPU=2; RAM=4GB, IOPS=1280, TempStorage=8GB, 35 CHF per Month
  // B1ms = vCPU=1; RAM=2GB, IOPS=640, TempStorage=4GB, 17 CHF per Month
  // B1s = vCPU=1; RAM=1GB, IOPS=320, TempStorage=4GB, 9 CHF per Month
  size                            = "Standard_B1s"
  computer_name                   = "${var.application_short}-${var.location_short}-wireguardvm-${var.environment_short}-vm"
  admin_username                  = local.wireguardvm_admin_username
  admin_password                  = local.wireguardvm_admin_password
  disable_password_authentication = false
  // Should all of the disks (including the temp disk) attached to this Virtual Machine be encrypted by enabling Encryption at Host?
  // when ture, Requires a registered provider for Microsoft.Compute/EncryptionAtHost: az feature show --namespace Microsoft.Compute --name EncryptionAtHost
  encryption_at_host_enabled      = false

  // Install the packages for edge device and set the connectionstring, see cloud-init.yml
  // When the customData / cloud-init file are changed, the VM will be destroyed and rebuild.
  custom_data                     = data.template_cloudinit_config.wireguardvm_user_data.rendered

  network_interface_ids           = [
    azurerm_network_interface.wireguardvm_nic.id,
  ]

  // The Microsoft Azure Linux VM Agent (waagent) manages provisioning, along with virtual machine
  provision_vm_agent    = true
  // Enable the OS Patching
  patch_assessment_mode = "AutomaticByPlatform"
  patch_mode            = "AutomaticByPlatform"

  // Allows Serial console and diagnostic tools
  boot_diagnostics {
    // Passing a null value will utilize a Managed Storage Account to store Boot Diagnostics
    storage_account_uri = null
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  // To List the available images use:
  // az vm image list --all --location switzerlandwest -f ubuntu
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.wireguardvm_identity.id
    ]
  }

  depends_on = [
    azurerm_role_assignment.wireguardvm_user,
    azurerm_key_vault_secret.wireguard_private_key_secret_create,
  ]
}

resource "azurerm_virtual_machine_extension" "wireguardvm_extension" {
  name                        = "AzureMonitorLinuxAgent"
  tags                        = var.tags_default
  publisher                   = "Microsoft.Azure.Monitor"
  type                        = "AzureMonitorLinuxAgent"
  type_handler_version        = "1.0"
  automatic_upgrade_enabled   = true
  auto_upgrade_minor_version  = true

  virtual_machine_id   = azurerm_linux_virtual_machine.wireguardvm.id
}

//ToDo: Add the Data Collection Rule
# // associate to a existing Data Collection Rule
# resource "azurerm_monitor_data_collection_rule_association" "edgehost_vm" {
#   name                    = "${var.application_short}-${var.location_short}-wireguardvm-${var.environment_short}-dcra"
#   target_resource_id      = azurerm_linux_virtual_machine.edgehost_vm.id
#   data_collection_rule_id = azurerm_monitor_data_collection_rule.edgehost_linux.id
#   description             = "Collects the data from the edgehost ${azurerm_linux_virtual_machine.edgehost_vm.computer_name}"
# }

# ╔══════════════════════════════════════════════════════════╗
# ║                         Actions                          ║
# ╚══════════════════════════════════════════════════════════╝
// Be sure the VM is started, so call the REST API to start the VM
// See: https://learn.microsoft.com/en-us/rest/api/compute/virtual-machines/start?tabs=HTTP
resource "azapi_resource_action" "wireguardvm_start" {
  type                   = "Microsoft.Compute/virtualMachines@2023-03-01"
  resource_id            = azurerm_linux_virtual_machine.wireguardvm.id
  method                 = "POST"
  action                 = "start"
  response_export_values = ["*"]

  depends_on = [
    azurerm_linux_virtual_machine.wireguardvm,
    azurerm_virtual_machine_extension.wireguardvm_extension,
  ]
}
