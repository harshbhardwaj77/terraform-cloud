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
  credentials = base64decode(var.GOOGLE_CREDENTIALS_JSON) # base64 of SA JSON
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
      # Track latest Ubuntu 24.04 LTS image
      image_family  = "ubuntu-2404-lts"
      image_project = "ubuntu-os-cloud"
      size          = 30
    }
  }

  network_interface {
    network = "default"
    access_config {} # public IP
  }

  # Inject SSH key (optional) and also pass app_type in metadata
  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
    app_type = var.app_type
  }

  # Run the setup script at first boot with app_type templated in
  metadata_startup_script = templatefile(
    "${path.module}/scripts/setup.sh.tftpl",
    { app_type = var.app_type }
  )

  depends_on = [google_compute_firewall.allow_web]
}
