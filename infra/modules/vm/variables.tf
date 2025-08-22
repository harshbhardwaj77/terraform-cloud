variable "instance_name" {
  description = "Name of the VM instance"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "GOOGLE_CREDENTIALS_JSON" {
  description = "Base64 encoded SA credentials JSON"
  type        = string
}
