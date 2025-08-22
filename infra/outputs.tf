output "vm_ip" {
  description = "External IP of the CloudPanel VM"
  value       = google_compute_instance.cloudpanel_vm.network_interface[0].access_config[0].nat_ip
}
