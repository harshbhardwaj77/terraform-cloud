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

# Ubuntu 24.04 LTS public image
data "google_compute_image" "ubuntu_2404" {
  family  = "ubuntu-2404-lts"
  project = "ubuntu-os-cloud"
}

# Allow HTTP and HTTPS traffic
resource "google_compute_firewall" "allow_web" {
  name    = "allow-web-80-443"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

# Create the VM
resource "google_compute_instance" "cloudpanel_vm" {
  name         = var.instance_name
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
    network       = "default"
    access_config {} # for external IP
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  metadata_startup_script = file("${path.module}/scripts/cloudpanel.sh")

  depends_on = [google_compute_firewall.allow_web]
}
