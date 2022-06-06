# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.8.0"
    }
  }

  required_version = ">= 1.1.0"

  cloud {
    organization = "882edn"
    workspaces {
      name = "pandawelch_wireguard-ground-up_main"
    }
  }

}

provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_location
  tags = {
  	ManagedBy = "Terraform"
    
  }
}

resource "azurerm_storage_account" "SA" {
  name                     = "wggroundupvpnstorage"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  lifecycle {
    prevent_destroy = true
  }
}

#ping
#push to main