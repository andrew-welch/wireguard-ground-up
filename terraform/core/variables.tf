variable "resource_location" {
  default = "australiaeast"
}

variable "resource_group_name" {
  default = "az-wireguard-ground-up"
}


variable "VM_PASSWORD" {
  type = string
  # Pulled from GitHub secrets
}

variable "domain-name" {
  default = "example.com"
}