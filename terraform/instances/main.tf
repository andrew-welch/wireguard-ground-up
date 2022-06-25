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

}

provider "azurerm" {
  features {}
}

provider "random" {
  features {}
}

data "azurerm_subscription" "current" {}

resource "random_string" "randomstr" {
  length           = 43
  special          = false
}
/*
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.resource_location
  tags = {
  	ManagedBy = "Terraform"
  }
}


resource "azurerm_storage_account" "SA" {
  name                     = "WG-VPN-Storage"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  lifecycle {
    prevent_destroy = true
  }
}
*/
/*
resource "azurerm_storage_share" "FS" {
  name                 = "wgfileshare"
  storage_account_name = azurerm_storage_account.SA.name
  quota                = 2
  access_tier          = "Hot"
  lifecycle {
    prevent_destroy = true
  }
  acl {
    id = randomstr
    access_policy {
      permissions = "rwdl"
      start       = timestamp()
      expiry      = timeadd(timestamp(),"17520h")
    }
  }
}
*/
/*

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "WG-VPN-vnet"
  address_space       = ["172.30.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
*/
/*
resource "azurerm_subnet" "singlenet" {
  name                = "WG-VPN-single"
  address_prefixes    = ["172.30.1.0/24"]
  resource_group_name = azurerm_resource_group.rg.name
  virtual_network_name=azurerm_virtual_network.vnet.name
}
*/
resource "azurerm_public_ip" "pip" {
  name                = "WG-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "extnic" {
  name                = "single-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  enable_ip_forwarding = true
  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.singlenet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

/*
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
*/
/*
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
*/
/*
resource "azurerm_subnet_network_security_group_association" "nsg-sn-conn" {
  subnet_id      = azurerm_subnet.singlenet.id
  network_security_group_id = azurerm_network_security_group.vpn-NSG.id
}
*/

resource "azurerm_linux_virtual_machine" "WG-VPN" {
  name                = "WG-VPN"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "admin"
  network_interface_ids = [
    azurerm_network_interface.extnic.id,
  ]
  admin_password = var.aw_password
  disable_password_authentication = false

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  ## Update the source image ID wit hthe output of packer process
  source_image_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/packer-wireguard/providers/Microsoft.Compute/images/az-wireguard-image-noconfig"
                                    
  identity {
    type = "SystemAssigned"
  }

  connection {
    type = "ssh"
    user = self.admin_username
    password = var.password
    host = self.public_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "storageAccountName=\"${azurerm_storage_account.SA.name}\"",
      "fileShareName=\"${azurerm_storage_share.FS.name}\"",
      "mntPath=\"/mnt/$storageAccountName/$fileShareName\"",
      "sudo mkdir -p $mntPath",
      "credentialRoot=\"/etc/smbcredentials\"",
      "sudo mkdir -p $credentialRoot",
      "smbCredentialFile=\"$credentialRoot/$storageAccountName.cred\"",
      "storageAccountKey=\"${azurerm_storage_account.SA.primary_access_key}\"",
      "echo \"username=$storageAccountName\" | sudo tee $smbCredentialFile > /dev/null",
      "echo \"password=$storageAccountKey\" | sudo tee -a $smbCredentialFile > /dev/null",
      "httpEndpoint=\"${azurerm_storage_account.SA.primary_file_endpoint}\"",
      "smbPath=$(echo $httpEndpoint | cut -c7-$(expr length $httpEndpoint))$fileShareName",
      "if [ -z \"$(grep $smbPath\\ $mntPath /etc/fstab)\" ]; then",
      "echo \"$smbPath $mntPath cifs nofail,credentials=$smbCredentialFile,serverino,nosharesock,actimeo=30\" | sudo tee -a /etc/fstab > /dev/null",
      "fi",
      "sudo mount -a",
      #post mount
      "sudo mkdir -p $mntPath/wg/keys",
      "sudo mkdir -p $mntPath/wg/clients",
      "sudo mkdir -p $mntPath/wg/keys/server",
      "umask 077",
      "serverKey=\"$mntPath/wg/keys/server/server_private_key\"",
      "if [ ! -f \"$serverKey\" ]; then ",
        "sudo wg genkey | sudo tee $mntPath/wg/keys/server/server_private_key > /dev/null",
        "sudo cat $mntPath/wg/keys/server/server_private_key | sudo wg pubkey | sudo tee $mntPath/wg/keys/server/server_public_key",
      "fi",
      "echo \"",
      "[Interface]",
      "Address = 10.200.200.1/24",
      "SaveConfig = true",
      "ListenPort = 51820",
      "PrivateKey=$(cat $mntPath/wg/keys/server/server_private_key)\" | sudo tee /etc/wireguard/wg0.conf > /dev/null",
      "sudo wg-quick up wg0",
      "sudo systemctl enable wg-quick@wg0.service"
      #Need to add any existing configs
    ]
  }

}

resource "azurerm_role_assignment" "vpn-data-assign" {
  scope              = azurerm_storage_account.SA.id
  role_definition_name = "Contributor"
  principal_id       = azurerm_linux_virtual_machine.WG-VPN.identity[0].principal_id
}

# TODO: Add zone back

/*
resource "azurerm_dns_a_record" "target" {
  name                = "vpn"
  zone_name           = var.domain-name
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.pip.id
}
*/