module "s3_app_assets" {
  source = "../../"

  name           = "app-assets"
  environment    = "production"
  owner          = "platform-team"
  cost_center    = "CC-001"
  logging_bucket = "hvt-access-logs-production"
}

output "bucket_name" {
  value = module.s3_app_assets.bucket_name
}

output "bucket_arn" {
  value = module.s3_app_assets.bucket_arn
}
