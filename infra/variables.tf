variable "GOOGLE_CREDENTIALS_JSON" {
  description = "Base64-encoded GCP credentials JSON"
  type        = string
  sensitive   = true
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"

  validation {
    condition     = contains(["us-central1", "us-east1", "us-west1", "europe-west1", "asia-south1", "asia-southeast1"], var.region)
    error_message = "Invalid region."
  }
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "instance_name" {
  type = string
}

variable "create_vpc" {
  description = "Whether to create a new VPC"
  type        = bool
  default     = false
}

variable "create_firewall" {
  description = "Whether to create firewall rules"
  type        = bool
  default     = false
}

variable "create_bucket" {
  description = "Whether to create a GCS bucket"
  type        = bool
  default     = false
}

variable "create_vm" {
  description = "Whether to create a VM with CloudPanel"
  type        = bool
  default     = false
}




variable "ssh_private_key" {
  type = string
}

variable "install_script_path" {
  type = string
}

