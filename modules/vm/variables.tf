variable "instance_name" {
  description = "Name of the VM instance"
  type        = string
}

variable "zone" {
  description = "GCP zone"
  type        = string
}

variable "machine_type" {
  description = "e2-micro, e2-medium, etc."
  type        = string
  default     = "e2-medium"
}

variable "boot_image" {
  description = "Ubuntu image to use"
  type        = string
  default     = "ubuntu-2204-lts"
}

variable "network" {
  description = "Network name (usually default)"
  type        = string
  default     = "default"
}

variable "tags" {
  description = "List of network tags"
  type        = list(string)
  default     = []
}

variable "ssh_user" {
  description = "SSH username (e.g., ubuntu)"
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key" {
  description = "Contents of private key for SSH"
  type        = string
  sensitive   = true
}

variable "install_script_path" {
  description = "Path to install-cloudpanel.sh"
  type        = string
}
