variable "project_id" {
  description = "Your GCP project ID"
  type        = string
}

variable "region" {
  description = "Region for VM deployment"
  type        = string
}

variable "zone" {
  description = "Zone for VM deployment"
  type        = string
}

variable "instance_name" {
  description = "Name of the VM instance"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key to access the VM"
  type        = string
}

variable "GOOGLE_CREDENTIALS_JSON" {
  description = "Base64-encoded Google Cloud service account JSON"
  type        = string
}
