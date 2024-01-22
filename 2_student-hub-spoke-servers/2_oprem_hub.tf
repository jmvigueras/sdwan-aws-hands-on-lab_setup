#------------------------------------------------------------------------------
# Create FGT cluster EU
# - VPC
# - FGT NI and SG
# - FGT instance
#------------------------------------------------------------------------------
# Create VPC for hub EU
module "eu_op_vpc" {
  source  = "jmvigueras/ftnt-aws-modules/aws//modules/vpc"
  version = "0.0.2"

  prefix     = "${local.prefix}-eu-op"
  admin_cidr = local.admin_cidr
  region     = local.eu_region
  azs        = local.eu_azs

  cidr = local.eu_op_vpc_cidr

  public_subnet_names  = local.eu_op_fgt_vpc_public_subnet_names
  private_subnet_names = local.eu_op_fgt_vpc_private_subnet_names
}
# Create FGT NIs
module "eu_op_nis" {
  source  = "jmvigueras/ftnt-aws-modules/aws//modules/fgt_ni_sg"
  version = "0.0.2"

  prefix             = "${local.prefix}-eu-op"
  azs                = local.eu_azs
  vpc_id             = module.eu_op_vpc.vpc_id
  subnet_list        = module.eu_op_vpc.subnet_list
  fgt_subnet_tags    = local.eu_op_fgt_subnet_tags
  fgt_number_peer_az = local.eu_op_number_peer_az
  cluster_type       = local.eu_op_cluster_type
}
module "eu_op_config" {
  for_each = { for k, v in module.eu_op_nis.fgt_ports_config : k => v }
  source   = "jmvigueras/ftnt-aws-modules/aws//modules/fgt_config"
  version  = "0.0.2"

  admin_cidr     = local.admin_cidr
  admin_port     = local.admin_port
  rsa_public_key = tls_private_key.ssh.public_key_openssh
  api_key        = random_string.api_key.result

  ports_config = each.value

  config_fgcp       = local.eu_op_cluster_type == "fgcp" ? true : false
  config_fgsp       = local.eu_op_cluster_type == "fgsp" ? true : false
  config_auto_scale = local.eu_op_cluster_type == "fgsp" ? true : false

  fgt_id     = each.key
  ha_members = module.eu_op_nis.fgt_ports_config

  config_hub = true
  hub        = local.eu_op

  config_vxlan = true
  vxlan_peers  = local.eu_op_vxlan_peers[each.key]

  static_route_cidrs = [local.eu_hub_vpc_cidr, local.eu_op_vpc_cidr] // necessary routes to stablish BGP peerings and bastion connection
}
# Create FGT for hub EU
module "eu_op" {
  source  = "jmvigueras/ftnt-aws-modules/aws//modules/fgt"
  version = "0.0.2"

  prefix        = "${local.prefix}-eu-op"
  region        = local.eu_region
  instance_type = local.instance_type
  keypair       = aws_key_pair.eu_keypair.key_name

  license_type = local.license_type
  fgt_build    = local.fgt_build

  fgt_ni_list = module.eu_op_nis.fgt_ni_list
  fgt_config  = { for k, v in module.eu_op_config : k => v.fgt_config }
}
# Create TGW attachment
module "eu_op_vpc_tgw_attachment" {
  source  = "jmvigueras/ftnt-aws-modules/aws//modules/tgw_attachment"
  version = "0.0.2"

  prefix = "${local.prefix}-eu-op"

  vpc_id         = module.eu_op_vpc.vpc_id
  tgw_id         = module.eu_tgw.tgw_id
  tgw_subnet_ids = compact([for i, az in local.eu_azs : lookup(module.eu_op_vpc.subnet_ids["az${i + 1}"], "tgw", "")])
  //rt_association_id  = module.eu_tgw.rt_default_id
  //rt_propagation_ids = [module.eu_tgw.rt_default_id]

  default_rt_association = true
  default_rt_propagation = true
  appliance_mode_support = "enable"
}
# Update private RT route RFC1918 cidrs to FGT NI and TGW
module "eu_op_vpc_routes" {
  source  = "jmvigueras/ftnt-aws-modules/aws//modules/vpc_routes"
  version = "0.0.2"

  tgw_id = module.eu_tgw.tgw_id
  ni_id  = module.eu_op_nis.fgt_ids_map["az1.fgt1"]["port2.private"]

  ni_rt_ids  = local.eu_op_ni_rt_ids
  tgw_rt_ids = local.eu_op_tgw_rt_ids
}
# Crate test VM in bastion subnet
module "eu_op_vm" {
  source  = "jmvigueras/ftnt-aws-modules/aws//modules/vm"
  version = "0.0.2"

  prefix          = "${local.prefix}-eu-op"
  keypair         = aws_key_pair.eu_keypair.key_name
  subnet_id       = module.eu_op_vpc.subnet_ids["az1"]["bastion"]
  subnet_cidr     = module.eu_op_vpc.subnet_cidrs["az1"]["bastion"]
  security_groups = [module.eu_op_vpc.sg_ids["default"]]
}