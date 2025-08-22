output "bucket_name" {
  description = "Name of the created GCS bucket"
  value       = module.bucket.bucket_name
  condition   = var.create_bucket
}

output "vm_ip" {
  description = "External IP of the created VM"
  value       = module.vm.instance_ip
  condition   = var.create_vm
}
