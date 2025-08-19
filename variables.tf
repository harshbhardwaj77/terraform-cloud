variable "project_id" {}
variable "region"     {}
variable "zone"       {}
variable "credentials_file" {}
variable "ssh_private_key" {}
variable "app_type" {
  description = "Choose app type: wordpress or laravel"
  type        = string
  default     = "wordpress"
}
