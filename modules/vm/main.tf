resource "google_compute_instance" "this" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.boot_image
    }
  }

  network_interface {
    network = var.network
    access_config {}
  }

  tags = var.tags

  metadata_startup_script = <<-EOT
    #!/bin/bash
    echo "Startup script run - waiting for SSH"
  EOT

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = var.ssh_private_key
    host        = self.network_interface[0].access_config[0].nat_ip
  }

  provisioner "file" {
    source      = var.install_script_path
    destination = "/tmp/install-cloudpanel.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/install-cloudpanel.sh",
      "sudo /tmp/install-cloudpanel.sh"
    ]
  }
}
