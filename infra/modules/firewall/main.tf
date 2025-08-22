# ----------------------------
# modules/firewall/main.tf
# ----------------------------
resource "google_compute_firewall" "default" {
name = var.name
network = var.network


allow {
protocol = var.protocol
ports = var.ports
}


source_ranges = var.source_ranges
direction = "INGRESS"
}