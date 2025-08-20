variable "GOOGLE_CREDENTIALS_JSON" {
  description = "Base64 encoded GCP service account JSON"
  type        = string
  sensitive   = true
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
  validation {
    condition     = contains(["wordpress", "laravel"], var.app_type)
    error_message = "app_type must be 'wordpress' or 'laravel'."
  }
}


variable "ssh_public_key" {
  description = "OpenSSH public key (single line, e.g. ssh-ed25519 ... user@host)"
  type        = string
}
