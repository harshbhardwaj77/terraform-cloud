resource "google_compute_instance" "this" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.tags

  boot_disk {
    initialize_params {
      image = var.boot_image
    }
  }

  network_interface {
    network = var.network
    access_config {}
  }

  metadata_startup_script = file("${path.module}/install-cloudpanel.sh")
}
