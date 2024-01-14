#------------------------------------------------------------------------------
# Create FGT cluster EU
# - VPC
# - FGT NI and SG
# - FGT instance
#------------------------------------------------------------------------------
# Create VPC for hub EU
module "eu_sdwan_vpc" {
  for_each = { for i, v in local.eu_sdwan_spoke : i => v }
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vpc?ref=v0.0.3"

  prefix     = "${local.prefix}-${each.value["id"]}"
  admin_cidr = local.admin_cidr
  region     = local.eu_region
  azs        = local.eu_sdwan_azs

  cidr = each.value["cidr"]

  public_subnet_names  = local.eu_hub_fgt_vpc_public_subnet_names
  private_subnet_names = local.eu_hub_fgt_vpc_private_subnet_names
}
# Create FGT NIs
module "eu_sdwan_nis" {
  for_each = { for i, v in local.eu_sdwan_spoke : i => v }
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//fgt_ni_sg?ref=v0.0.3"

  prefix             = "${local.prefix}-${each.value["id"]}"
  azs                = local.eu_sdwan_azs
  vpc_id             = module.eu_sdwan_vpc[each.key].vpc_id
  subnet_list        = module.eu_sdwan_vpc[each.key].subnet_list
  fgt_subnet_tags    = local.eu_hub_fgt_subnet_tags
  fgt_number_peer_az = local.eu_sdwan_number_peer_az
}
# Create FGT config peer each FGT
module "eu_sdwan_config" {
  for_each = { for i, v in local.eu_sdwan_config : "${v["sdwan_id"]}.${v["fgt_id"]}" => v }
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//fgt_config?ref=v0.0.3"

  admin_cidr     = local.admin_cidr
  admin_port     = local.admin_port
  rsa_public_key = tls_private_key.ssh.public_key_openssh
  api_key        = random_string.api_key.result

  ports_config = module.eu_sdwan_nis[each.value["sdwan_id"]].fgt_ports_config[each.value["fgt_id"]]
  fgt_id       = each.value["fgt_id"]
  ha_members   = module.eu_sdwan_nis[each.value["sdwan_id"]].fgt_ports_config

  config_spoke = true
  spoke        = local.eu_sdwan_spoke[each.value["sdwan_id"]]
  hubs         = local.eu_hubs

  config_fw_policy = false
  config_extra     = data.template_file.eu_sdwan_config_extra[each.key].rendered

  static_route_cidrs = [local.eu_sdwan_spoke[each.value["sdwan_id"]]["cidr"]]
}
# Data template extra-config fgt (Create new VIP to lab server and policies to allow traffic)
data "template_file" "eu_sdwan_config_extra" {
  for_each = { for i, v in local.eu_sdwan_config : "${v["sdwan_id"]}.${v["fgt_id"]}" => v }

  template = file("./templates/fgt_config_student.tpl")
  vars = {
    external_ip         = element([for port in module.eu_sdwan_nis[each.value["sdwan_id"]].fgt_ports_config[each.value["fgt_id"]] : port["ip"] if port["tag"] == "public"], 0)
    mapped_ip           = cidrhost(module.eu_sdwan_vpc[each.value["sdwan_id"]].subnet_cidrs["az1"]["bastion"], 10)
    external_port       = "80"
    mapped_port         = "80"
    public_port         = element([for port in module.eu_sdwan_nis[each.value["sdwan_id"]].fgt_ports_config[each.value["fgt_id"]] : port["port"] if port["tag"] == "public"], 0)
    private_port        = element([for port in module.eu_sdwan_nis[each.value["sdwan_id"]].fgt_ports_config[each.value["fgt_id"]] : port["port"] if port["tag"] == "private"], 0)
    suffix              = "80"
    tag_project_server  = "${local.tags["Project"]}-lab-server"
    tag_project_student = "please-use-student-id" 
  }
}
# Create FGT for hub EU
module "eu_sdwan" {
  for_each = { for i, v in local.eu_sdwan_spoke : i => v }
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//fgt?ref=v0.0.3"

  prefix        = "${local.prefix}-${each.value["id"]}"
  region        = local.eu_region
  instance_type = local.instance_type
  keypair       = aws_key_pair.eu_keypair.key_name

  license_type = local.license_type
  fgt_build    = local.fgt_build

  fgt_ni_list = module.eu_sdwan_nis[each.key].fgt_ni_list
  fgt_config  = { for i, v in local.eu_sdwan_config : v["fgt_id"] => module.eu_sdwan_config["${v["sdwan_id"]}.${v["fgt_id"]}"].fgt_config if tostring(v["sdwan_id"]) == each.key }
}
# Update private RT route RFC1918 cidrs to FGT NI and TGW
module "eu_sdwan_vpc_routes" {
  for_each = { for i, v in local.eu_sdwan_spoke : i => v }
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vpc_routes?ref=v0.0.3"

  ni_id     = module.eu_sdwan_nis[each.key].fgt_ids_map["az1.fgt1"]["port2.private"]
  ni_rt_ids = local.eu_sdwan_ni_rt_ids[each.key]
}
