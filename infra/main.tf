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
  # var.GOOGLE_CREDENTIALS_JSON should be a BASE64 string of the SA JSON
  credentials = base64decode(var.GOOGLE_CREDENTIALS_JSON)
}

# Ubuntu 24.04 LTS (Noble) for amd64 from public images
data "google_compute_image" "ubuntu_2404" {
  # Either family works; this one is explicitly amd64:
  family  = "ubuntu-2404-lts-amd64"
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
  name         = var.instance_name                # <- variablized
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
    access_config {} # ephemeral public IP
  }

  # Pass user's choice and SSH key via metadata
  metadata = {
    app_type = var.app_type
    # Ensure var.ssh_public_key is a one-line OpenSSH key (ssh-ed25519/ssh-rsa ...)
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  # Plain Bash startup script (no TF templating):
  # This file assumes infra/ is the current module and script lives in ../scripts/
  metadata_startup_script = file("${path.module}/../scripts/setup.sh")

  depends_on = [google_compute_firewall.allow_web]
}
