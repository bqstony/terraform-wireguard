// Version Handling:
// - ~> Allow greater patch versions 1.1.x
// - >= Any newer version allowed x.x.x
// - >= 1.4.0, < 2.0.0 Avoids major version updates
terraform {

  required_version = ">= 1.4.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.71.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~>1.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.5.0"
    }
  }

  # Alternative use local terraform state file
  backend "azurerm" {} # backend with storage account (terraform init -backend-config environment/[env]/backend.hcl)
}

provider "azurerm" {
  subscription_id = var.environment_subscription_id
  tenant_id       = var.environment_tenant_id

  features {
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }
}

provider "azapi" {
  subscription_id = var.environment_subscription_id
  tenant_id       = var.environment_tenant_id
}

// Used to access the current configuration of the AzureRM provider.
data "azurerm_client_config" "current" {
}
