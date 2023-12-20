data "azurerm_resource_group" "testbench_rg" {
  name = "${var.application_short}-${var.location_short}-testbench-${var.environment_short}-rg"
}

data "azurerm_key_vault" "secrets-kv" {
  name                = "${var.application_short}-${var.location_short}-secrets-${var.environment_short}-kv"
  resource_group_name = data.azurerm_resource_group.testbench_rg.name
}
