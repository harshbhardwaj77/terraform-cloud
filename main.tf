provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = base64decode(var.GOOGLE_CREDENTIALS_JSON)
  # Use variable for base64 encoded credentials
}

resource "google_compute_instance" "web" {
  name         = "terraform-instance"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-lts"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata_startup_script = file("scripts/setup.sh")  # Make sure the script exists

  tags = ["web"]

  # SSH connection for remote exec
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key)  # Reference the path to private key
    host        = self.network_interface[0].access_config[0].nat_ip
  }

  # Install based on user input
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup.sh",
      "sudo /tmp/setup.sh ${var.app_type}"  # Ensure app_type is defined as a variable
    ]
  }

  provisioner "file" {
    source      = "scripts/setup.sh"
    destination = "/tmp/setup.sh"
  }
}

