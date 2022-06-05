packer {
  required_plugins {
    azure-arm = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/azure"
    }
  }
}

source "azure-arm" "image-create" {
    client_id           = sensitive_client_id
    client_secret       = sensitive_client_secret
    subscription_id     = sensitive_subscription_id
    tenant_id           = sensitive_tenant_id

      managed_image_name = "az-wireguard-image-noconfig"
    managed_image_resource_group_name = "az-wireguard-ground-up"

    os_type         = "Linux"
    image_publisher = "canonical"
    image_offer     = "0001-com-ubuntu-server-focal"
    image_sku       = "20_04-lts-gen2"

    azure_tags = {
        managed = "packer"
    }

    location = "australiaeast"
    vm_size  = "Standard_B1s"
}

build {
  name    = "packer-wireguard"
  sources = ["sources.azure-arm.image-create"]

  provisioner "shell" {
    # Install wireguard, configure network and associated settings
    script = "wireguard-install.sh"
    pause_before = "10s"
    timeout = "10s"
  }

  provisioner "shell" {
    # Azure generalising script
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    inline_shebang = "/bin/sh -x"
  }

}
