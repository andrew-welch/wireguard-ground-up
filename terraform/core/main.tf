# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.8.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "= 3.2.0"
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

resource "random_string" "randomstr" {
  length           = 43
  special          = false
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

# File Share in storage account. Access policy is 2 years
resource "azurerm_storage_share" "FS" {
  name                 = "wgfileshare"
  storage_account_name = azurerm_storage_account.SA.name
  quota                = 2
  access_tier          = "Hot"
  lifecycle {
    prevent_destroy = true
  }
  acl {
    id = random_string.randomstr.result
    access_policy {
      permissions = "rwdl"
      start       = timestamp()
      expiry      = timeadd(timestamp(),"17520h")
    }
  }
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "WGgroundup-VPN-vnet"
  address_space       = ["172.30.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "singlenet" {
  name                = "WG-VPN-single"
  address_prefixes    = ["172.30.1.0/24"]
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name=azurerm_virtual_network.vnet.name
}


resource "azurerm_network_security_group" "vpn-NSG" {
  name                = "WG_webserver"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_network_security_rule" "nsr-WG" {
  name                        = "WG-traffic"
  priority                    = 105
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Udp"
  source_port_range           = "*"
  destination_port_range      = "51820"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.vpn-NSG.name
}

resource "azurerm_network_security_rule" "nsr-SSH" {
  name                        = "temp-ssh"
  priority                    = 106
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.vpn-NSG.name
}

resource "azurerm_subnet_network_security_group_association" "nsg-sn-conn" {
  subnet_id      = azurerm_subnet.singlenet.id
  network_security_group_id = azurerm_network_security_group.vpn-NSG.id
}