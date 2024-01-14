#------------------------------------------------------------------------------
# Create FGT cluster US
# - VPC
# - FGT NI and SG
# - FGT instance
#------------------------------------------------------------------------------
# Create VPC for hub US
module "us_hub_vpc" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vpc"

  prefix     = "${local.prefix}-us-hub"
  admin_cidr = local.admin_cidr
  region     = local.us_region
  azs        = local.us_azs

  cidr = local.us_hub_vpc_cidr

  public_subnet_names  = local.us_hub_fgt_vpc_public_subnet_names
  private_subnet_names = local.us_hub_fgt_vpc_private_subnet_names
}
# Create FGT NIs
module "us_hub_nis" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//fgt_ni_sg"

  prefix             = "${local.prefix}-us-hub"
  azs                = local.us_azs
  vpc_id             = module.us_hub_vpc.vpc_id
  subnet_list        = module.us_hub_vpc.subnet_list
  fgt_subnet_tags    = local.us_hub_fgt_subnet_tags
  fgt_number_peer_az = local.us_hub_number_peer_az
  cluster_type       = local.us_hub_cluster_type
}
module "us_hub_config" {
  for_each = { for k, v in module.us_hub_nis.fgt_ports_config : k => v }
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//fgt_config"

  admin_cidr     = local.admin_cidr
  admin_port     = local.admin_port
  rsa_public_key = tls_private_key.ssh.public_key_openssh
  api_key        = random_string.api_key.result

  ports_config = each.value

  config_fgcp       = local.us_hub_cluster_type == "fgcp" ? true : false
  config_fgsp       = local.us_hub_cluster_type == "fgsp" ? true : false
  config_auto_scale = local.us_hub_cluster_type == "fgsp" ? true : false

  fgt_id     = each.key
  ha_members = module.us_hub_nis.fgt_ports_config

  config_hub = true
  hub        = local.us_hub

  /*
  config_tgw_gre = true
  tgw_gre_peer = {
    tgw_ip        = one([for i, v in local.us_hub_tgw_peers : v["tgw_ip"] if v["id"] == each.key])
    inside_cidr   = one([for i, v in local.us_hub_tgw_peers : v["inside_cidr"] if v["id"] == each.key])
    twg_bgp_asn   = local.us_tgw_bgp_asn
    route_map_out = "rm_out_hub_to_external_0" //created by default prepend routes with community 65001:10
    route_map_in  = ""
    gre_name      = "gre-to-tgw"
  }
  */

  config_vxlan = true
  vxlan_peers  = local.us_hub_vxlan_peers[each.key]

  static_route_cidrs = [local.us_hub_vpc_cidr, local.us_tgw_cidr, local.eu_hub_vpc_cidr] //necessary routes to stablish BGP peerings and bastion connection
}
# Create FGT for hub US
module "us_hub" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//fgt"

  prefix        = "${local.prefix}-us-hub"
  region        = local.us_region
  instance_type = local.instance_type
  keypair       = aws_key_pair.us_keypair.key_name

  license_type = local.license_type
  fgt_build    = local.fgt_build

  fgt_ni_list = module.us_hub_nis.fgt_ni_list
  fgt_config  = { for k, v in module.us_hub_config : k => v.fgt_config }
}
# Create TGW
module "us_tgw" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//tgw"

  prefix = "${local.prefix}-us-hub"

  tgw_cidr    = local.us_tgw_cidr
  tgw_bgp_asn = local.us_tgw_bgp_asn
}
# Create TGW attachment
module "us_hub_vpc_tgw_attachment" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//tgw_attachment"

  prefix = "${local.prefix}-us-hub"

  vpc_id             = module.us_hub_vpc.vpc_id
  tgw_id             = module.us_tgw.tgw_id
  tgw_subnet_ids     = compact([for i, az in local.us_azs : lookup(module.us_hub_vpc.subnet_ids["az${i + 1}"], "tgw", "")])
  rt_association_id  = module.us_tgw.rt_post_inspection_id
  rt_propagation_ids = [module.us_tgw.rt_pre_inspection_id]

  appliance_mode_support = "enable"
  default_rt_propagation = true
}
# Create static route in TGW RouteTable to default VPC FGT attachment
resource "aws_ec2_transit_gateway_route" "us_tgw_route_default_to_hub_vpc" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.us_hub_vpc_tgw_attachment.id
  transit_gateway_route_table_id = module.us_tgw.rt_pre_inspection_id
}
/*
# Create TGW attachment connect
module "us_hub_vpc_tgw_connect" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//tgw_connect"

  prefix = "${local.prefix}-us-hub"

  vpc_attachment_id = module.us_hub_vpc_tgw_attachment.id
  tgw_id            = module.us_tgw.tgw_id
  peers             = local.us_hub_tgw_peers

  rt_association_id  = module.us_tgw.rt_post_inspection_id
  rt_propagation_ids = [module.us_tgw.rt_pre_inspection_id]

  tags = local.tags
}
*/
# Update private RT route RFC1918 cidrs to FGT NI and TGW
module "us_hub_vpc_routes" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vpc_routes"

  tgw_id = module.us_tgw.tgw_id
  ni_id  = module.us_hub_nis.fgt_ids_map["az1.fgt1"]["port2.private"]

  ni_rt_ids  = local.us_hub_ni_rt_ids
  tgw_rt_ids = local.us_hub_tgw_rt_ids
}

# Crate test VM in bastion subnet
module "us_hub_vm" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vm"

  prefix          = "${local.prefix}-us-hub"
  keypair         = aws_key_pair.us_keypair.key_name
  subnet_id       = module.us_hub_vpc.subnet_ids["az1"]["bastion"]
  subnet_cidr     = module.us_hub_vpc.subnet_cidrs["az1"]["bastion"]
  security_groups = [module.us_hub_vpc.sg_ids["default"]]
}
#------------------------------------------------------------------------------
# VPC Spoke to TGW
#------------------------------------------------------------------------------
# Create VPC spoke to TGW
module "us_spoke_to_tgw" {
  for_each = local.us_spoke_to_tgw
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vpc"

  prefix = "${local.prefix}-us-tgw-spoke"
  azs    = local.us_azs

  cidr = each.value

  public_subnet_names  = ["vm"]
  private_subnet_names = ["tgw"]
}
# Create TGW attachment
module "us_spoke_to_tgw_attachment" {
  for_each = local.us_spoke_to_tgw
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//tgw_attachment"

  prefix = "${local.prefix}-${each.key}"

  vpc_id             = module.us_spoke_to_tgw[each.key].vpc_id
  tgw_id             = module.us_tgw.tgw_id
  tgw_subnet_ids     = compact([for i, az in local.us_azs : lookup(module.us_spoke_to_tgw[each.key].subnet_ids["az${i + 1}"], "tgw", "")])
  rt_association_id  = module.us_tgw.rt_pre_inspection_id
  rt_propagation_ids = [module.us_tgw.rt_post_inspection_id]

  appliance_mode_support = "disable"
}
# Update private RT route RFC1918 cidrs to FGT NI and TGW
module "us_spoke_to_tgw_routes" {
  for_each = local.us_spoke_to_tgw
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vpc_routes"

  tgw_id = module.us_tgw.tgw_id
  tgw_rt_ids = { for pair in setproduct(["vm"], [for i, az in local.us_azs : "az${i + 1}"]) :
    "${pair[0]}-${pair[1]}" => module.us_spoke_to_tgw[each.key].rt_ids[pair[1]][pair[0]]
  }
}
# Crate test VM in bastion subnet
module "us_spoke_to_tgw_vm" {
  for_each = local.us_spoke_to_tgw
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vm"

  prefix          = "${local.prefix}-${each.key}"
  keypair         = aws_key_pair.us_keypair.key_name
  subnet_id       = module.us_spoke_to_tgw[each.key].subnet_ids["az1"]["vm"]
  subnet_cidr     = module.us_spoke_to_tgw[each.key].subnet_cidrs["az1"]["vm"]
  security_groups = [module.us_spoke_to_tgw[each.key].sg_ids["default"]]
}