#------------------------------------------------------------------------------
# Create FGT cluster EU
# - VPC
# - FGT NI and SG
# - FGT instance
#------------------------------------------------------------------------------
# Create VPC for hub EU
module "eu_hub_vpc" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vpc?ref=v0.0.2"

  prefix     = "${local.prefix}-eu-hub"
  admin_cidr = local.admin_cidr
  region     = local.eu_region
  azs        = local.eu_azs

  cidr = local.eu_hub_vpc_cidr

  public_subnet_names  = local.eu_hub_fgt_vpc_public_subnet_names
  private_subnet_names = local.eu_hub_fgt_vpc_private_subnet_names
}
# Create FGT NIs
module "eu_hub_nis" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//fgt_ni_sg?ref=v0.0.2"

  prefix             = "${local.prefix}-eu-hub"
  azs                = local.eu_azs
  vpc_id             = module.eu_hub_vpc.vpc_id
  subnet_list        = module.eu_hub_vpc.subnet_list
  fgt_subnet_tags    = local.eu_hub_fgt_subnet_tags
  fgt_number_peer_az = local.eu_hub_number_peer_az
  cluster_type       = local.eu_hub_cluster_type
}
module "eu_hub_config" {
  for_each = { for k, v in module.eu_hub_nis.fgt_ports_config : k => v }
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//fgt_config?ref=v0.0.2"

  admin_cidr     = local.admin_cidr
  admin_port     = local.admin_port
  rsa_public_key = tls_private_key.ssh.public_key_openssh
  api_key        = random_string.api_key.result

  ports_config = each.value

  config_fgcp       = local.eu_hub_cluster_type == "fgcp" ? true : false
  config_fgsp       = local.eu_hub_cluster_type == "fgsp" ? true : false
  config_auto_scale = local.eu_hub_cluster_type == "fgsp" ? true : false

  fgt_id     = each.key
  ha_members = module.eu_hub_nis.fgt_ports_config

  config_hub = true
  hub        = local.eu_hub

  config_tgw_gre = true
  tgw_gre_peer = {
    tgw_ip        = one([for i, v in local.eu_hub_tgw_peers : v["tgw_ip"] if v["id"] == each.key])
    inside_cidr   = one([for i, v in local.eu_hub_tgw_peers : v["inside_cidr"] if v["id"] == each.key])
    twg_bgp_asn   = local.eu_tgw_bgp_asn
    route_map_out = "rm_out_hub_to_external_0" //created by default prepend routes with community 65001:10
    route_map_in  = ""
    gre_name      = "gre-to-tgw"
  }

  config_vxlan = true
  vxlan_peers  = local.eu_hub_vxlan_peers[each.key]

  config_fw_policy = false
  config_extra     = data.template_file.eu_hub_config_extra_config[each.key].rendered

  static_route_cidrs = [local.eu_hub_vpc_cidr, local.eu_tgw_cidr, local.eu_op_vpc_cidr, local.us_hub_vpc_cidr] //necessary routes to stablish BGP peerings and bastion connection
}

# Data template extra-config fgt (Create new VIP to lab server and policies to allow traffic)
data "template_file" "eu_hub_config_extra_config" {
  for_each = { for k, v in module.eu_hub_nis.fgt_ports_config : k => v }

  template = file("./templates/fgt_extra_config.tpl")
  vars = {
    external_ip   = element([for port in each.value : port["ip"] if port["tag"] == "public"], 0)
    mapped_ip     = local.lab_srv_private_ip
    external_port = "80"
    mapped_port   = "80"
    public_port   = element([for port in each.value : port["port"] if port["tag"] == "public"], 0)
    private_port  = element([for port in each.value : port["port"] if port["tag"] == "private"], 0)
    suffix        = "80"
  }
}

# Create FGT for hub EU
module "eu_hub" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//fgt?ref=v0.0.2"

  prefix        = "${local.prefix}-eu-hub"
  region        = local.eu_region
  instance_type = local.instance_type
  keypair       = aws_key_pair.eu_keypair.key_name

  license_type = local.license_type
  fgt_build    = local.fgt_build

  fgt_ni_list = module.eu_hub_nis.fgt_ni_list
  fgt_config  = { for k, v in module.eu_hub_config : k => v.fgt_config }
}
# Create TGW
module "eu_tgw" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//tgw"

  prefix = "${local.prefix}-eu-hub"

  tgw_cidr    = local.eu_tgw_cidr
  tgw_bgp_asn = local.eu_tgw_bgp_asn
}
# Create TGW attachment
module "eu_hub_vpc_tgw_attachment" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//tgw_attachment?ref=v0.0.2"

  prefix = "${local.prefix}-eu-hub"

  vpc_id         = module.eu_hub_vpc.vpc_id
  tgw_id         = module.eu_tgw.tgw_id
  tgw_subnet_ids = compact([for i, az in local.eu_azs : lookup(module.eu_hub_vpc.subnet_ids["az${i + 1}"], "tgw", "")])
  //rt_association_id  = module.eu_tgw.rt_default_id
  //rt_propagation_ids = [module.eu_tgw.rt_default_id]

  default_rt_association = true
  default_rt_propagation = true
  appliance_mode_support = "enable"
}
# Create TGW attachment connect
module "eu_hub_vpc_tgw_connect" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//tgw_connect?ref=v0.0.2"

  prefix = "${local.prefix}-eu-hub"

  vpc_attachment_id = module.eu_hub_vpc_tgw_attachment.id
  tgw_id            = module.eu_tgw.tgw_id
  peers             = local.eu_hub_tgw_peers

  rt_association_id  = module.eu_tgw.rt_post_inspection_id
  rt_propagation_ids = [module.eu_tgw.rt_pre_inspection_id]

  tags = local.tags
}
# Update private RT route RFC1918 cidrs to FGT NI and TGW
module "eu_hub_vpc_routes" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vpc_routes?ref=v0.0.2"

  tgw_id = module.eu_tgw.tgw_id
  ni_id  = module.eu_hub_nis.fgt_ids_map["az1.fgt1"]["port2.private"]

  ni_rt_ids  = local.eu_hub_ni_rt_ids
  tgw_rt_ids = local.eu_hub_tgw_rt_ids
}
#------------------------------------------------------------------------------
# VPC Spoke to TGW
#------------------------------------------------------------------------------
# Create VPC spoke to TGW
module "eu_spoke_to_tgw" {
  for_each = local.eu_spoke_to_tgw
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vpc?ref=v0.0.2"

  prefix = "${local.prefix}-eu-tgw-spoke"
  azs    = local.eu_azs

  cidr = each.value

  public_subnet_names  = ["vm"]
  private_subnet_names = ["tgw"]
}
# Create TGW attachment
module "eu_spoke_to_tgw_attachment" {
  for_each = local.eu_spoke_to_tgw
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//tgw_attachment?ref=v0.0.2"

  prefix = "${local.prefix}-${each.key}"

  vpc_id             = module.eu_spoke_to_tgw[each.key].vpc_id
  tgw_id             = module.eu_tgw.tgw_id
  tgw_subnet_ids     = compact([for i, az in local.eu_azs : lookup(module.eu_spoke_to_tgw[each.key].subnet_ids["az${i + 1}"], "tgw", "")])
  rt_association_id  = module.eu_tgw.rt_pre_inspection_id
  rt_propagation_ids = [module.eu_tgw.rt_post_inspection_id]

  appliance_mode_support = "disable"
}
# Update private RT route RFC1918 cidrs to FGT NI and TGW
module "eu_spoke_to_tgw_routes" {
  for_each = local.eu_spoke_to_tgw
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vpc_routes?ref=v0.0.2"

  tgw_id = module.eu_tgw.tgw_id
  tgw_rt_ids = { for pair in setproduct(["vm"], [for i, az in local.eu_azs : "az${i + 1}"]) :
    "${pair[0]}-${pair[1]}" => module.eu_spoke_to_tgw[each.key].rt_ids[pair[1]][pair[0]]
  }
}
# Crate test VM in bastion subnet
module "eu_spoke_to_tgw_vm" {
  for_each = local.eu_spoke_to_tgw
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vm?ref=v0.0.2"

  prefix          = "${local.prefix}-${each.key}"
  keypair         = aws_key_pair.eu_keypair.key_name
  subnet_id       = module.eu_spoke_to_tgw[each.key].subnet_ids["az1"]["vm"]
  subnet_cidr     = module.eu_spoke_to_tgw[each.key].subnet_cidrs["az1"]["vm"]
  security_groups = [module.eu_spoke_to_tgw[each.key].sg_ids["default"]]
}
/*
#------------------------------------------------------------------------------
# Create TGW peering EU-US
#------------------------------------------------------------------------------
# Create attachement between TGW (EU request to US)
resource "aws_ec2_transit_gateway_peering_attachment" "tgw_peer_eu_us" {
  peer_account_id         = module.us_tgw.tgw_owner_id
  peer_region             = local.us_region
  peer_transit_gateway_id = module.us_tgw.tgw_id
  transit_gateway_id      = module.eu_tgw.tgw_id

  tags = merge(
    { Name = "tgw-peering-to-us" },
    local.tags
  )
}
# Create static route in TGW RouteTable EU
resource "aws_ec2_transit_gateway_route" "eu_tgw_route_to_us_tgw" {
  depends_on = [aws_ec2_transit_gateway_peering_attachment.tgw_peer_eu_us]

  destination_cidr_block         = local.us_hub_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.tgw_peer_eu_us.id
  transit_gateway_route_table_id = module.eu_tgw.rt_default_id
}
locals {
  tgw_peer_eu_us_id = "" // Update from GUI after accept attachment  
}
/*
# Accept attachement at US side
resource "aws_ec2_transit_gateway_peering_attachment_accepter" "tgw_peer_eu_us_accepter" {
  depends_on = [aws_ec2_transit_gateway_peering_attachment.tgw_peer_eu_us]
  //provider = aws.us

  transit_gateway_attachment_id = local.tgw_peer_eu_us_id

  tags = merge(
    { Name = "tgw-peering-to-eu" },
    local.tags
  )
}
# Create static route in TGW RouteTable US
resource "aws_ec2_transit_gateway_route" "us_tgw_route_to_eu_tgw" {
  depends_on = [aws_ec2_transit_gateway_peering_attachment.tgw_peer_eu_us]
  //provider = aws.us

  destination_cidr_block         = local.eu_hub_vpc_cidr
  transit_gateway_attachment_id  = local.tgw_peer_eu_us_id
  transit_gateway_route_table_id = module.us_tgw.rt_default_id
}
*/