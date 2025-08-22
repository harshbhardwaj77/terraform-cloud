terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }
}

provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = base64decode(var.GOOGLE_CREDENTIALS_JSON)
}

# Use Ubuntu 24.04 LTS image from Google Cloud's public image repository
data "google_compute_image" "ubuntu_2404" {
  family  = "ubuntu-2404-lts"
  project = "ubuntu-os-cloud"
}

# Create a firewall rule to allow HTTP and HTTPS traffic
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

# Create the VM instance with CloudPanel startup script
resource "google_compute_instance" "cloudpanel_vm" {
  name         = var.instance_name
  machine_type = "e2-medium"
  zone         = var.zone
  tags         = ["web"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu_2404.self_link  # Reference Ubuntu 24.04 LTS image
      size  = 30  # 30 GB boot disk size
    }
  }

  network_interface {
    network       = "default"
    access_config {}  # This creates an external IP for the VM
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"  # Add SSH keys for accessing the VM
  }

  metadata_startup_script = file("${path.module}/scripts/cloudpanel.sh")  # Path to the startup script

  depends_on = [google_compute_firewall.allow_web]  # Ensure the firewall is created first
}

# Output the external IP address of the VM
output "vm_ip" {
  description = "The external IP address of the VM"
  value       = google_compute_instance.cloudpanel_vm.network_interface[0].access_config[0].nat_ip
}
