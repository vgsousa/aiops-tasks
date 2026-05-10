module "s3_data_lake" {
  source = "../../"

  name           = "data-lake"
  environment    = "production"
  owner          = "data-team"
  cost_center    = "CC-042"
  logging_bucket = "hvt-access-logs-production"

  enable_lifecycle       = true
  lifecycle_ia_days      = 30
  lifecycle_glacier_days = 90
}

output "bucket_name" {
  value = module.s3_data_lake.bucket_name
}
