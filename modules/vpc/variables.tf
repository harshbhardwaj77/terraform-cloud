# ----------------------------
# modules/vpc/variables.tf
# ----------------------------
variable "name" {
description = "The name of the VPC network"
type = string
}


variable "region" {
description = "The region where the subnetwork will be created"
type = string
}

variable "ip_cidr_range" {
description = "CIDR range for the subnetwork"
type = string
}