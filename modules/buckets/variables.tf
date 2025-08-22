# ----------------------------
# modules/bucket/variables.tf
# ----------------------------
variable "bucket_name" {
description = "Name of the bucket"
type = string
}


variable "location" {
description = "GCP region for the bucket"
type = string
}


variable "force_destroy" {
description = "Whether to force delete even if not empty"
type = bool
default = false
}