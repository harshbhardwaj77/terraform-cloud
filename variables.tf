variable "GOOGLE_CREDENTIALS_JSON" {
  description = "Base64 encoded GCP credentials JSON"
  type        = string
  sensitive   = true  # Marked as sensitive for security
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "zone" {
  description = "The GCP zone"
  type        = string
}

variable "app_type" {
  description = "Choose the app type: wordpress or laravel"
  type        = string
  default     = "wordpress"  # Default value
}

variable "ssh_private_key" {
  description = "The private SSH key for accessing the instance"
  type        = string
  sensitive   = true  # Marked as sensitive for security
}

variable "ssh_public_key" {
  description = "The public SSH key for the instance"
  type        = string
}
