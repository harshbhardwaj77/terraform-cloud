terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = base64decode(var.GOOGLE_CREDENTIALS_JSON)
}

# Optional: Source public Ubuntu 24.04 image once, can be reused in modules
data "google_compute_image" "ubuntu_2404" {
  family  = "ubuntu-2404-lts-amd64"
  project = "ubuntu-os-cloud"
}

# ---------------------------------------------
# Optional Resources (deployed based on flags)
# ---------------------------------------------

module "vpc" {
  source     = "./modules/vpc"
  project_id = var.project_id
  region     = var.region
  create     = var.create_vpc
}

module "firewall" {
  source     = "./modules/firewall"
  project_id = var.project_id
  network    = module.vpc.network_name
  create     = var.create_firewall
}

module "bucket" {
  source     = "./modules/bucket"
  project_id = var.project_id
  bucket_name = var.bucket_name
  location    = var.region
  create      = var.create_bucket
}

module "vm" {
  source        = "./modules/vm"
  instance_name = var.instance_name
  zone          = var.zone
  region        = var.region
  project_id    = var.project_id
  tags          = ["web"]
  network       = module.vpc.network_name
  ssh_public_key = var.ssh_public_key
  boot_image    = data.google_compute_image.ubuntu_2404.self_link
  app_type      = var.app_type
  create        = var.create_vm
}
