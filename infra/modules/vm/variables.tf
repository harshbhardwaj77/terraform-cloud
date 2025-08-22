variable "instance_name" {
  description = "Name of the GCE instance"
  type        = string
}

variable "zone" {
  description = "Zone in which to launch the instance"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "tags" {
  description = "Network tags for the instance"
  type        = list(string)
  default     = []
}

variable "network" {
  description = "VPC network name"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for accessing the VM"
  type        = string
}

variable "boot_image" {
  description = "Boot image self link"
  type        = string
}

variable "app_type" {
  description = "Application type to decide install script"
  type        = string
  default     = "default"
}

variable "create" {
  description = "Boolean to control creation of the VM"
  type        = bool
  default     = true
}
