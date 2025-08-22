variable "instance_name" {
  description = "The name of the VM instance"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
}

variable "zone" {
  description = "GCP zone"
  type        = string
}

variable "ssh_public_key" {
  description = "Public SSH key for VM access"
  type        = string
}

# Optional: If you are using metadata_startup_script
# and no longer using provisioners, remove the following:
# variable "install_script_path" {}
# variable "ssh_private_key" {}
