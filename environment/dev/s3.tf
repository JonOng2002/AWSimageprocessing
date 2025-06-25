module "spa_bucket" {
  source = "../../modules/terraform-aws-s3-bucket-master"
  bucket = "24-jun-2025-spa-bucket"

  website = {
    index_document = "index.html"
    error_document = "index.html"
  }
  tags = {
    Environment = "dev"
    Project     = "img"
  }

}

module "og_img_bucket" {
  source = "../../modules/terraform-aws-s3-bucket-master"
    bucket = "24-jun-2025-og-img-bucket"
  tags = {
    Environment = "dev"
    Project     = "img"
  }
}

module "processed_img_bucket" {
  source = "../../modules/terraform-aws-s3-bucket-master"
    bucket = "24-jun-2025-processed-img-bucket"
  tags = {
    Environment = "dev"
    Project     = "img"
  }
}

