variable "project_id"            { type = string }
variable "region"                { type = string }
variable "zone"                  { type = string }
variable "GOOGLE_CREDENTIALS_JSON" { type = string }  # base64 SA JSON
variable "ssh_public_key"        { type = string }
variable "app_type"              { type = string }     # "wordpress" or "laravel"
variable "instance_name"         { type = string }     # e.g. "terraform-instance"
