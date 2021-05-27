variable "region" {
  type = string
}

variable "az" {
  type    = list(string)
  default = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "vpc_cidr_block" {
  type = string
}

variable "eks_cluster_name" {
  type = string
  default = "security"
}

variable "acm_vault_arn" {
  type = string
}

variable "private_network_config" {
  type = map(object({
      cidr_block               = string
      associated_public_subnet = string
  }))

  default = {
    "private-security-1" = {
        cidr_block               = "10.0.0.0/23"
        associated_public_subnet = "public-security-1"
    },
    "private-security-2" = {
        cidr_block               = "10.0.2.0/23"
        associated_public_subnet = "public-security-2"
    },
    "private-security-3" = {
        cidr_block               = "10.0.4.0/23"
        associated_public_subnet = "public-security-3"
    }
  }
}

locals {
    private_nested_config = flatten([
        for name, config in var.private_network_config : [
            {
                name                     = name
                cidr_block               = config.cidr_block
                associated_public_subnet = config.associated_public_subnet
            }
        ]
    ])
}

variable "public_network_config" {
  type = map(object({
      cidr_block              = string
  }))

  default = {
    "public-security-1" = {
        cidr_block = "10.0.8.0/23"
    },
    "public-security-2" = {
        cidr_block = "10.0.10.0/23"
    },
    "public-security-3" = {
        cidr_block = "10.0.12.0/23"
    }
  }
}

locals {
    public_nested_config = flatten([
        for name, config in var.public_network_config : [
            {
                name                    = name
                cidr_block              = config.cidr_block
            }
        ]
    ])
}

variable "public_dns_name" {
  type    = string
}

variable "authorized_source_ranges" {
  type        = string
  description = "Addresses or CIDR blocks which are allowed to connect to the Vault IP address. The default behavior is to allow anyone (0.0.0.0/0) access. You should restrict access to external IPs that need to access the Vault cluster."
  default     = "0.0.0.0/0"
}
