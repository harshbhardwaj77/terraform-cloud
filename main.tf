provider "google" {
  project     = var.project_id
  region      = var.region
  # var.GOOGLE_CREDENTIALS_JSON should be a BASE64 string of the service-account JSON
  credentials = base64decode(var.GOOGLE_CREDENTIALS_JSON)
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

  # Inject your SSH public key so the VM accepts your connection
  # Make sure var.ssh_public_key is like: ssh-ed25519 AAAA... user@host
  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }

  # Optional: also run your startup script automatically at boot
  # (keep this only if scripts/setup.sh exists in the repo)
  metadata_startup_script = file("scripts/setup.sh")

  tags = ["web"]

  # ==== Provisioners ====
  # Use key CONTENTS from a TFC variable, not file() (file() looks on runner's filesystem)
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = var.ssh_private_key
    host        = self.network_interface[0].access_config[0].nat_ip
  }

  # 1 Upload the script first
  provisioner "file" {
    source      = "scripts/setup.sh"
    destination = "/tmp/setup.sh"
  }

  # 2 Then execute it with your selected app type
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup.sh",
      "sudo /tmp/setup.sh ${var.app_type}"
    ]
  }
}
