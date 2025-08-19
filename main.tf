provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file(var.credentials_file)
}

resource "google_compute_instance" "web" {
  name         = "web-server"
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

  metadata_startup_script = file("scripts/setup.sh")

  tags = ["web"]

  # SSH connection for remote exec
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key)
    host        = self.network_interface[0].access_config[0].nat_ip
  }

  # Install based on user input
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup.sh",
      "sudo /tmp/setup.sh ${var.app_type}"
    ]
  }

  provisioner "file" {
    source      = "scripts/setup.sh"
    destination = "/tmp/setup.sh"
  }
}
