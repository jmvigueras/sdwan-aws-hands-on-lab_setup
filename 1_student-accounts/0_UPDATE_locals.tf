locals {
  # Provide a common tag prefix value that will be used in the name tag for all resources
  prefix = "aws"

  # Tags
  tags = {
    Project = "aws2024hol"
  }

  # List of regions where deploy users
  regions = [
    "eu-west-1", //Ireland
    "eu-west-2", //London
    //"eu-west-3"  //Paris
  ]

  # Number of users peer region
  user_number_peer_region = 1

  # Path prefix for users (regex /path-prefix/)
  user_path_prefix = "/aws2024hol/"

  # DNS zone
  dns_domain = "fortidemoscloud.com"
}

#-------------------------------------------------------------------------------------
# Necessary data and resources
#-------------------------------------------------------------------------------------
# Get account id
data "aws_caller_identity" "current" {}

# Create new random string External ID for assume role
resource "random_string" "externalid_token" {
  length  = 30
  special = false
  numeric = true
}
