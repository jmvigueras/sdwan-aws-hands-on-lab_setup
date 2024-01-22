// Create FAZ
module "eu_faz" {
  source  = "jmvigueras/ftnt-aws-modules/aws//modules/faz"
  version = "0.0.3"

  prefix         = local.prefix
  keypair        = aws_key_pair.eu_keypair.key_name
  rsa-public-key = trimspace(tls_private_key.ssh.public_key_openssh)

  subnet_id       = module.eu_spoke_to_tgw["${local.eu_spoke_to_tgw_prefix}-0"].subnet_ids["az1"]["vm"]
  subnet_cidr     = module.eu_spoke_to_tgw["${local.eu_spoke_to_tgw_prefix}-0"].subnet_cidrs["az1"]["vm"]
  security_groups = [module.eu_spoke_to_tgw["${local.eu_spoke_to_tgw_prefix}-0"].sg_ids["default"]]
  cidr_host       = 12

  faz_build    = "build2308"
  license_type = "byol"
  license_file = "./licenses/licenseFAZ.lic"
}