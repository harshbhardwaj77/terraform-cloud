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
  # var.GOOGLE_CREDENTIALS_JSON must be a BASE64 string of your SA JSON
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
      image = data.google_compute_image.ubuntu_2404.self_link
      size  = 30
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  # Pass user’s choice & (optionally) SSH key into instance metadata
  metadata = {
    app_type = var.app_type
    # Ensure var.ssh_public_key is a single-line OpenSSH key (ssh-ed25519/ssh-rsa ...)
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  # Use a plain Bash startup script (no Terraform templating)
  # Directory layout assumes this file lives in infra/ and the script is in ../scripts/
  metadata_startup_script = file("${path.module}/../scripts/setup.sh")

  depends_on = [google_compute_firewall.allow_web]
}
