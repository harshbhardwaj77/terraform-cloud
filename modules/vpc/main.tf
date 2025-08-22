# ----------------------------
# modules/vpc/main.tf
# ----------------------------
resource "google_compute_network" "vpc_network" {
name = var.name
auto_create_subnetworks = false
}


resource "google_compute_subnetwork" "subnetwork" {
name = "${var.name}-subnet"
ip_cidr_range = var.ip_cidr_range
region = var.region
network = google_compute_network.vpc_network.id
}