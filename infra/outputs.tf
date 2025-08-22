output "bucket_name" {
  description = "Name of the created GCS bucket"
  value       = try(module.bucket.bucket_name, null)
}

output "vm_ip" {
  description = "External IP of the created VM"
  value       = try(module.vm.instance_ip, null)
}
