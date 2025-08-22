# ----------------------------
# modules/firewall/variables.tf
# ----------------------------
variable "name" {
description = "Name of the firewall rule"
type = string
}


variable "network" {
description = "Network to attach the firewall rule"
type = string
}


variable "protocol" {
description = "Protocol to allow (e.g. tcp, udp)"
type = string
}


variable "ports" {
description = "List of allowed ports"
type = list(string)
}


variable "source_ranges" {
description = "List of source CIDRs allowed"
type = list(string)
}