####################
# GLOBAL VARIABLES #
####################

variable "environment_subscription_id" {
  description = "The current environment subscription-id"
  type        = string
}

variable "environment_tenant_id" {
  description = "The current environment tenant-id"
  type        = string
}

variable "environment_short" {
  description = "The environment stage"
  type        = string
  validation {
    condition     = (contains(["prod", "test", "dev"], var.environment_short) || startswith(var.environment_short, "dev") ) && length(var.environment_short) <= 4
    error_message = "The environment name has to be prod, test or starts with dev like dev1 to dev9"
  }
}

variable "application_short" {
  description = "The name of the application"
  type        = string
  default     = "tb"
  validation {
    condition     = contains(["tb"], var.application_short)
    error_message = "The application name has to be tb"
  }
}

//       use a map or object vor location! so long and short name are one variable, or use a list to name id automaticly
variable "location" {
  description = "The Resource Location as long name used in Azure like: switzerlandnorth"
  type        = string
  default     = "switzerlandnorth"
  validation {
    condition     = contains(["Switzerland North", "switzerlandnorth", "Switzerland West", "switzerlandwest", "westeurope"], var.location)
    error_message = "The location has to be switzerlandnorth, switzerlandwest or westeurope"
  }
}

variable "location_short" {
  description = "The Resource Location as short name like: chn"
  type        = string
  default     = "chn"
  validation {
    condition     = contains(["chn", "chw", "euw"], var.location_short)
    error_message = "The location has to be switzerlandnorth, switzerlandwest or westeurope"
  }
}

variable "tags_default" {
  description = "A List of key=value Tag that allways have to be set"
  type        = map(string)
}


locals {
  // in dev it is allowd to have named dev1 to dev9, and use som existing ressources from clean dev
  environment_short_clean = trimsuffix(trimsuffix(trimsuffix(trimsuffix(trimsuffix(trimsuffix(trimsuffix(trimsuffix(trimsuffix(var.environment_short, "1"), "2"), "3"), "4"), "5"), "6"), "7"), "8"), "9")
}
