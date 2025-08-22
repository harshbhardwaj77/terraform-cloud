# ----------------------------
# modules/vpc/outputs.tf
# ----------------------------
output "name" {
value = google_compute_network.vpc_network.name
}


output "subnet_name" {
value = google_compute_subnetwork.subnetwork.name
}


output "network_self_link" {
value = google_compute_network.vpc_network.self_link
}