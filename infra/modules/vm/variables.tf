variable "instance_name" {
  description = "Name of the compute instance"
  type        = string
}

variable "zone" {
  description = "GCP zone"
  type        = string
}

variable "machine_type" {
  description = "Machine type for the instance"
  type        = string
  default     = "e2-medium"
}

variable "boot_image" {
  description = "Boot disk image to use"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2004-lts"
}

variable "network" {
  description = "Network name to use"
  type        = string
  default     = "default"
}

variable "tags" {
  description = "List of network tags"
  type        = list(string)
  default     = ["cloudpanel"]
}
