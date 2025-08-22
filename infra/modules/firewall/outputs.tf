# ----------------------------
# modules/firewall/outputs.tf
# ----------------------------
output "firewall_name" {
value = google_compute_firewall.default.name
}
