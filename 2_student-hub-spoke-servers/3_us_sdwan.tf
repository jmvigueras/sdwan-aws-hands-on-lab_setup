#------------------------------------------------------------------------------
# Create FGT cluster US
# - VPC
# - FGT NI and SG
# - FGT instance
#------------------------------------------------------------------------------
# Create VPC for hub US
module "us_sdwan_vpc" {
  for_each = { for i, v in local.us_sdwan_spoke : i => v }
  source   = "jmvigueras/ftnt-aws-modules/aws//modules/vpc"
  version  = "0.0.2"

  prefix     = "${local.prefix}-${each.value["id"]}"
  admin_cidr = local.admin_cidr
  region     = local.us_region
  azs        = local.us_sdwan_azs

  cidr = each.value["cidr"]

  public_subnet_names  = local.us_hub_fgt_vpc_public_subnet_names
  private_subnet_names = local.us_hub_fgt_vpc_private_subnet_names
}
# Create FGT NIs
module "us_sdwan_nis" {
  for_each = { for i, v in local.us_sdwan_spoke : i => v }
  source   = "jmvigueras/ftnt-aws-modules/aws//modules/fgt_ni_sg"
  version  = "0.0.2"

  prefix             = "${local.prefix}-${each.value["id"]}"
  azs                = local.us_sdwan_azs
  vpc_id             = module.us_sdwan_vpc[each.key].vpc_id
  subnet_list        = module.us_sdwan_vpc[each.key].subnet_list
  fgt_subnet_tags    = local.us_hub_fgt_subnet_tags
  fgt_number_peer_az = local.us_sdwan_number_peer_az
}
# Create FGT config peer each FGT
module "us_sdwan_config" {
  for_each = { for i, v in local.us_sdwan_config : "${v["sdwan_id"]}.${v["fgt_id"]}" => v }
  source   = "jmvigueras/ftnt-aws-modules/aws//modules/fgt_config"
  version  = "0.0.2"

  admin_cidr     = local.admin_cidr
  admin_port     = local.admin_port
  rsa_public_key = tls_private_key.ssh.public_key_openssh
  api_key        = random_string.api_key.result

  ports_config = module.us_sdwan_nis[each.value["sdwan_id"]].fgt_ports_config[each.value["fgt_id"]]
  fgt_id       = each.value["fgt_id"]
  ha_members   = module.us_sdwan_nis[each.value["sdwan_id"]].fgt_ports_config

  config_spoke = true
  spoke        = local.us_sdwan_spoke[each.value["sdwan_id"]]
  hubs         = local.us_hubs

  static_route_cidrs = [local.us_sdwan_spoke[each.value["sdwan_id"]]["cidr"]]
}
# Create FGT for hub US
module "us_sdwan" {
  for_each = { for i, v in local.us_sdwan_spoke : i => v }
  source   = "jmvigueras/ftnt-aws-modules/aws//modules/fgt"
  version  = "0.0.2"

  prefix        = "${local.prefix}-${each.value["id"]}"
  region        = local.us_region
  instance_type = local.instance_type
  keypair       = aws_key_pair.us_keypair.key_name

  license_type = local.license_type
  fgt_build    = local.fgt_build

  fgt_ni_list = module.us_sdwan_nis[each.key].fgt_ni_list
  fgt_config  = { for i, v in local.us_sdwan_config : v["fgt_id"] => module.us_sdwan_config["${v["sdwan_id"]}.${v["fgt_id"]}"].fgt_config if tostring(v["sdwan_id"]) == each.key }
}
# Update private RT route RFC1918 cidrs to FGT NI and TGW
module "us_sdwan_vpc_routes" {
  for_each = { for i, v in local.us_sdwan_spoke : i => v }
  source   = "jmvigueras/ftnt-aws-modules/aws//modules/vpc_routes"
  version  = "0.0.2"

  ni_id     = module.us_sdwan_nis[each.key].fgt_ids_map["az1.fgt1"]["port2.private"]
  ni_rt_ids = local.us_sdwan_ni_rt_ids[each.key]
}
# Crate test VM in bastion subnet
module "us_sdwan_vm" {
  for_each = { for i, v in local.us_sdwan_spoke : i => v }
  source   = "jmvigueras/ftnt-aws-modules/aws//modules/vm"
  version  = "0.0.2"

  prefix          = "${local.prefix}-${each.value["id"]}"
  keypair         = aws_key_pair.us_keypair.key_name
  subnet_id       = module.us_sdwan_vpc[each.key].subnet_ids["az1"]["bastion"]
  subnet_cidr     = module.us_sdwan_vpc[each.key].subnet_cidrs["az1"]["bastion"]
  security_groups = [module.us_sdwan_vpc[each.key].sg_ids["default"]]
}