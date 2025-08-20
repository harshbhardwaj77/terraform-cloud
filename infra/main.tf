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

# Resolve latest Ubuntu 24.04 LTS from family
data "google_compute_image" "ubuntu_2404" {
  family  = "ubuntu-2404-lts"
  project = "ubuntu-os-cloud"
}

# Allow HTTP/HTTPS to instances tagged "web"
resource "google_compute_firewall" "allow_web" {
  name    = "allow-web-80-443"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  target_tags   = ["web"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "web" {
  name         = "terraform-instance"
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["web"]

  boot_disk {
    initialize_params {
      source_image = data.google_compute_image.ubuntu_2204.self_link
      size         = 30
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  # Optional SSH access + pass app_type via metadata as well
  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
    app_type = var.app_type
  }

  # Use a template so only ${app_type} is interpolated by Terraform
  metadata_startup_script = templatefile(
    "${path.module}/scripts/setup.sh.tftpl",
    { app_type = var.app_type }
  )

  depends_on = [google_compute_firewall.allow_web]
}
