locals {
  ## Generate locals needed at modules ##

  #-----------------------------------------------------------------------------------------------------
  # FGT VPC generic variables
  #-----------------------------------------------------------------------------------------------------
  # List of subnet names to add a route to FGT NI
  ni_rt_subnet_names = ["bastion", "tgw"]
  # List of subnet names to add a route to a TGW
  tgw_rt_subnet_names = [local.eu_hub_fgt_subnet_tags["port2.private"]]

  #-----------------------------------------------------------------------------------------------------
  # HUB EMEA (EU)
  #-----------------------------------------------------------------------------------------------------
  # List of public and private subnet to create FGT VPC
  eu_hub_fgt_vpc_public_subnet_names  = [local.eu_hub_fgt_subnet_tags["port1.public"], local.eu_hub_fgt_subnet_tags["port3.mgmt"], "bastion"]
  eu_hub_fgt_vpc_private_subnet_names = [local.eu_hub_fgt_subnet_tags["port2.private"], "tgw"]

  # Config VPN DialUps FGT HUB
  eu_hub = [
    {
      id                = local.eu_id
      bgp_asn_hub       = local.eu_hub_bgp_asn
      bgp_asn_spoke     = local.eu_spoke_bgp_asn
      vpn_cidr          = local.eu_hub_vpn_cidr
      vpn_psk           = local.externalid_token
      cidr              = local.eu_hub_cidr
      ike_version       = "2"
      network_id        = "1"
      dpd_retryinterval = "5"
      mode_cfg          = true
      vpn_port          = "public"
      local_gw          = ""
    }
  ]
  # Create map of RT IDs where add routes pointing to a FGT NI
  eu_hub_ni_rt_ids = {
    for pair in setproduct(local.ni_rt_subnet_names, [for i, az in local.eu_azs : "az${i + 1}"]) :
    "${pair[0]}-${pair[1]}" => module.eu_hub_vpc.rt_ids[pair[1]][pair[0]]
  }
  # Create map of RT IDs where add routes pointing to a TGW ID
  eu_hub_tgw_rt_ids = {
    for pair in setproduct(local.tgw_rt_subnet_names, [for i, az in local.eu_azs : "az${i + 1}"]) :
    "${pair[0]}-${pair[1]}" => module.eu_hub_vpc.rt_ids[pair[1]][pair[0]]
  }
  # Map of public IPs of EU HUB
  eu_hub_public_eips = module.eu_hub_nis.fgt_eips_map

  # EU HUB TGW variables (used for module tgw_connect)
  eu_hub_tgw_peers = [
    for i in range(0, length(keys(module.eu_hub_nis.fgt_ips_map))) :
    { "inside_cidr" = "169.254.${i + 101}.0/29",
      "tgw_ip"      = cidrhost(local.eu_tgw_cidr, 10 + i),
      "id"          = keys(module.eu_hub_nis.fgt_ips_map)[i],
      "fgt_ip"      = values(module.eu_hub_nis.fgt_ips_map)[i]["port2.private"]
      "fgt_bgp_asn" = local.eu_hub_bgp_asn
    }
  ]
  # VXLAN list of peers peer HUB cluster with values need in config module
  eu_hub_cluster_vxlan_peers_list = [
    for i in range(0, length(keys(module.eu_hub_nis.fgt_ips_map))) :
    { external_ip   = join(",", [for ii, ip in values(module.eu_hub_nis.fgt_ips_map) : ip["port2.private"] if ii != i])
      remote_ip     = join(",", [for ii in range(0, length(module.eu_hub_nis.fgt_ips_map)) : cidrhost(local.eu_hub_vxlan_cidr, ii + 1) if ii != i])
      local_ip      = cidrhost(local.eu_hub_vxlan_cidr, i + 1)
      vni           = local.eu_hub_vxlan_vni
      vxlan_port    = "private"
      bgp_asn       = local.eu_hub_bgp_asn
      route_map_out = "rm_out_hub_to_hub_0" //created by default add community 65001:10
    }
  ]
  # VXLAN list of peers peer HUB to ON-PREMISES HUB with values need in config module
  eu_hub_to_op_vxlan_peers_list = [
    for i in range(0, length(keys(module.eu_hub_nis.fgt_ips_map))) :
    { external_ip   = join(",", [for ii, ip in values(module.eu_op_nis.fgt_ips_map) : ip["port2.private"]])
      remote_ip     = join(",", [for ii in range(0, length(module.eu_op_nis.fgt_ips_map)) : cidrhost(local.eu_hub_to_op_vxlan_cidr, ii + 1 + length(module.eu_hub_nis.fgt_ips_map))])
      local_ip      = cidrhost(local.eu_hub_to_op_vxlan_cidr, i + 1)
      vni           = local.eu_hub_to_op_vxlan_vni
      vxlan_port    = "private"
      bgp_asn       = local.eu_op_bgp_asn
      route_map_out = "rm_out_hub_to_hub_0" //created by default add community 65001:10
    }
  ]
  # VXLAN list of peers peer HUB to US HUB with values need in config module
  eu_hub_to_us_hub_vxlan_peers_list = [
    for i in range(0, length(keys(module.eu_hub_nis.fgt_ips_map))) :
    { external_ip   = join(",", [for ii, ip in values(module.us_hub_nis.fgt_ips_map) : ip["port2.private"]])
      remote_ip     = join(",", [for ii in range(0, length(module.us_hub_nis.fgt_ips_map)) : cidrhost(local.eu_hub_to_us_hub_vxlan_cidr, ii + 1 + length(module.us_hub_nis.fgt_ips_map))])
      local_ip      = cidrhost(local.eu_hub_to_us_hub_vxlan_cidr, i + 1)
      vni           = local.eu_hub_to_us_hub_vxlan_vni
      vxlan_port    = "private"
      bgp_asn       = local.us_hub_bgp_asn
      route_map_out = "rm_out_hub_to_hub_0" //created by default add community 65001:10
    }
  ]
  # Generate a map for each deployed FGT HUB with vxlan peers values
  eu_hub_vxlan_peers = zipmap(
    keys(module.eu_hub_nis.fgt_ips_map), [
      for i in range(0, length(keys(module.eu_hub_nis.fgt_ips_map))) : [
        local.eu_hub_cluster_vxlan_peers_list[i],
        local.eu_hub_to_op_vxlan_peers_list[i],
        local.eu_hub_to_us_hub_vxlan_peers_list[i]
      ]
    ]
  )

  #-----------------------------------------------------------------------------------------------------
  # EU - EMEA SDWAN SPOKE
  #-----------------------------------------------------------------------------------------------------
  # EU HUBs variables
  eu_hub_public_ip  = ""
  eu_hub_private_ip = ""
  eu_op_public_ip   = ""
  eu_op_private_ip  = ""

  //eu_hubs = concat(local.eu_hubs_cloud, local.eu_hubs_op)
  eu_hubs = concat(local.eu_hubs_cloud, local.eu_hubs_op)

  # Define SDWAN HUB EMEA CLOUD
  eu_hubs_cloud = [for hub in local.eu_hub :
    {
      id      = hub["id"]
      bgp_asn = hub["bgp_asn_hub"]
      // external_ip       = hub["vpn_port"] == "public" ? local.eu_hub_public_ip : local.eu_hub_private_ip
      external_fqdn     = hub["vpn_port"] == "public" ? local.eu_hub_vpn_fqdn : local.eu_hub_private_ip
      hub_ip            = cidrhost(cidrsubnet(hub["vpn_cidr"], 0, 0), 1)
      site_ip           = hub["mode_cfg"] ? "" : cidrhost(cidrsubnet(hub["vpn_cidr"], 0), 3)
      hck_ip            = cidrhost(cidrsubnet(hub["vpn_cidr"], 0, 0), 1)
      vpn_psk           = hub["vpn_psk"]
      cidr              = hub["cidr"]
      ike_version       = hub["ike_version"]
      network_id        = hub["network_id"]
      dpd_retryinterval = hub["dpd_retryinterval"]
      sdwan_port        = hub["vpn_port"]
    }
  ]
  # Define SDWAN HUB EMEA ON-PREM
  eu_hubs_op = [for hub in local.eu_op :
    {
      id      = hub["id"]
      bgp_asn = hub["bgp_asn_hub"]
      // external_ip       = hub["vpn_port"] == "public" ? local.eu_hub_public_ip : local.eu_hub_private_ip
      external_fqdn     = hub["vpn_port"] == "public" ? local.eu_op_vpn_fqdn : local.eu_op_private_ip
      hub_ip            = cidrhost(cidrsubnet(hub["vpn_cidr"], 0, 0), 1)
      site_ip           = hub["mode_cfg"] ? "" : cidrhost(cidrsubnet(hub["vpn_cidr"], 0), 3)
      hck_ip            = cidrhost(cidrsubnet(hub["vpn_cidr"], 0, 0), 1)
      vpn_psk           = hub["vpn_psk"]
      cidr              = hub["cidr"]
      ike_version       = hub["ike_version"]
      network_id        = hub["network_id"]
      dpd_retryinterval = hub["dpd_retryinterval"]
      sdwan_port        = hub["vpn_port"]
    }
  ]
  # Create map of RT IDs where add routes pointing to a TGW ID
  eu_sdwan_ni_rt_ids = [
    for i in range(0, local.eu_sdwan_number) : {
      for pair in setproduct(local.ni_rt_subnet_names, [for i, az in local.eu_sdwan_azs : "az${i + 1}"]) :
      "${pair[0]}-${pair[1]}" => module.eu_sdwan_vpc[i].rt_ids[pair[1]][pair[0]]
    }
  ]
  # Create FGTs config (auxiliary local list)
  eu_sdwan_config = flatten([
    for i in range(0, local.eu_sdwan_number) :
    [for ii, v in local.eu_sdwan_azs :
      { "sdwan_id" = "${i}"
        "fgt_id"   = "az${ii + 1}.fgt${ii + 1}"
      }
    ]
    ]
  )

  #-----------------------------------------------------------------------------------------------------
  # HUB EMEA ON-PREMISES 
  #-----------------------------------------------------------------------------------------------------
  # List of public and private subnet to create FGT VPC
  eu_op_fgt_vpc_public_subnet_names  = [local.eu_op_fgt_subnet_tags["port1.public"], local.eu_op_fgt_subnet_tags["port3.mgmt"], "bastion"]
  eu_op_fgt_vpc_private_subnet_names = [local.eu_op_fgt_subnet_tags["port2.private"], "tgw"]

  # Config VPN DialUps FGT HUB
  eu_op = [
    {
      id                = local.eu_id
      bgp_asn_hub       = local.eu_op_bgp_asn
      bgp_asn_spoke     = local.eu_spoke_bgp_asn
      vpn_cidr          = local.eu_op_vpn_cidr
      vpn_psk           = local.externalid_token
      cidr              = local.eu_op_cidr
      ike_version       = "2"
      network_id        = "1"
      dpd_retryinterval = "5"
      mode_cfg          = true
      vpn_port          = "public"
      local_gw          = ""
    }
  ]
  # Create map of RT IDs where add routes pointing to a FGT NI
  eu_op_ni_rt_ids = {
    for pair in setproduct(local.ni_rt_subnet_names, [for i, az in local.eu_azs : "az${i + 1}"]) :
    "${pair[0]}-${pair[1]}" => module.eu_op_vpc.rt_ids[pair[1]][pair[0]]
  }
  eu_op_tgw_rt_ids = {
    for pair in setproduct(local.tgw_rt_subnet_names, [for i, az in local.eu_azs : "az${i + 1}"]) :
    "${pair[0]}-${pair[1]}" => module.eu_op_vpc.rt_ids[pair[1]][pair[0]]
  }
  # Map of public IPs of EU HUB
  eu_op_public_eips = module.eu_op_nis.fgt_eips_map

  # VXLAN list of peers peer OP cluster with values need in config module
  eu_op_to_hub_vxlan_peers_list = [
    for i in range(0, length(keys(module.eu_op_nis.fgt_ips_map))) :
    { external_ip   = join(",", [for ii, ip in values(module.eu_hub_nis.fgt_ips_map) : ip["port2.private"]])
      remote_ip     = join(",", [for ii in range(0, length(module.eu_hub_nis.fgt_ips_map)) : cidrhost(local.eu_hub_to_op_vxlan_cidr, ii + 1)])
      local_ip      = cidrhost(local.eu_hub_to_op_vxlan_cidr, i + 1 + length(module.eu_hub_nis.fgt_ips_map))
      vni           = local.eu_hub_to_op_vxlan_vni
      vxlan_port    = "private"
      bgp_asn       = local.eu_hub_bgp_asn
      route_map_out = "rm_out_hub_to_hub_0" //created by default add community 65001:10
    }
  ]
  # Generate a map for each deployed FGT HUB with vxlan peers values
  eu_op_vxlan_peers = zipmap(
    keys(module.eu_op_nis.fgt_ips_map), [
      for i in range(0, length(keys(module.eu_hub_nis.fgt_ips_map))) : [
        local.eu_op_to_hub_vxlan_peers_list[i]
      ]
    ]
  )

  #-----------------------------------------------------------------------------------------------------
  # HUB US
  #-----------------------------------------------------------------------------------------------------
  # List of public and private subnet to create FGT VPC
  us_hub_fgt_vpc_public_subnet_names  = [local.us_hub_fgt_subnet_tags["port1.public"], local.us_hub_fgt_subnet_tags["port3.mgmt"], "bastion"]
  us_hub_fgt_vpc_private_subnet_names = [local.us_hub_fgt_subnet_tags["port2.private"], "tgw"]

  # Config VPN DialUps FGT HUB
  us_hub = [
    {
      id                = local.us_id
      bgp_asn_hub       = local.us_hub_bgp_asn
      bgp_asn_spoke     = local.us_spoke_bgp_asn
      vpn_cidr          = local.us_hub_vpn_cidr
      vpn_psk           = local.externalid_token
      cidr              = local.us_hub_cidr
      ike_version       = "2"
      network_id        = "1"
      dpd_retryinterval = "5"
      mode_cfg          = true
      vpn_port          = "public"
      local_gw          = ""
    }
  ]
  # Create map of RT IDs where add routes pointing to a FGT NI
  us_hub_ni_rt_ids = {
    for pair in setproduct(local.ni_rt_subnet_names, [for i, az in local.us_azs : "az${i + 1}"]) :
    "${pair[0]}-${pair[1]}" => module.us_hub_vpc.rt_ids[pair[1]][pair[0]]
  }
  us_hub_tgw_rt_ids = {
    for pair in setproduct(local.tgw_rt_subnet_names, [for i, az in local.us_azs : "az${i + 1}"]) :
    "${pair[0]}-${pair[1]}" => module.us_hub_vpc.rt_ids[pair[1]][pair[0]]
  }
  # Map of public IPs of EU HUB
  us_hub_public_eips = module.us_hub_nis.fgt_eips_map

  # US HUB TGW variables (used for module tgw_connect)
  us_hub_tgw_peers = [
    for i in range(0, length(keys(module.us_hub_nis.fgt_ips_map))) :
    { "inside_cidr" = "169.254.${i + 101}.0/29",
      "tgw_ip"      = cidrhost(local.us_tgw_cidr, 10 + i),
      "id"          = keys(module.us_hub_nis.fgt_ips_map)[i],
      "fgt_ip"      = values(module.us_hub_nis.fgt_ips_map)[i]["port2.private"]
      "fgt_bgp_asn" = local.us_hub_bgp_asn
    }
  ]

  # VXLAN list of peers peer OP cluster with values need in config module
  us_hub_to_hub_vxlan_peers_list = [
    for i in range(0, length(keys(module.us_hub_nis.fgt_ips_map))) :
    { external_ip   = join(",", [for ii, ip in values(module.eu_hub_nis.fgt_ips_map) : ip["port2.private"]])
      remote_ip     = join(",", [for ii in range(0, length(module.eu_hub_nis.fgt_ips_map)) : cidrhost(local.eu_hub_to_us_hub_vxlan_cidr, ii + 1)])
      local_ip      = cidrhost(local.eu_hub_to_us_hub_vxlan_cidr, i + 1 + length(module.eu_hub_nis.fgt_ips_map))
      vni           = local.eu_hub_to_us_hub_vxlan_vni
      vxlan_port    = "private"
      bgp_asn       = local.eu_hub_bgp_asn
      route_map_out = "rm_out_hub_to_hub_0" //created by default add community 65001:10
    }
  ]
  # Generate a map for each deployed FGT HUB with vxlan peers values
  us_hub_vxlan_peers = zipmap(
    keys(module.us_hub_nis.fgt_ips_map), [
      for i in range(0, length(keys(module.eu_hub_nis.fgt_ips_map))) : [
        local.us_hub_to_hub_vxlan_peers_list[i]
      ]
    ]
  )

  #-----------------------------------------------------------------------------------------------------
  # US - SDWAN SPOKE
  #-----------------------------------------------------------------------------------------------------
  # US HUBs variables
  us_hub_public_ip  = ""
  us_hub_private_ip = ""
  us_op_public_ip   = ""
  us_op_private_ip  = ""

  us_hubs = concat(local.us_hubs_cloud)

  # Define SDWAN HUB EMEA CLOUD
  us_hubs_cloud = [for hub in local.us_hub :
    {
      id      = hub["id"]
      bgp_asn = hub["bgp_asn_hub"]
      // external_ip       = hub["vpn_port"] == "public" ? local.us_hub_public_ip : local.us_hub_private_ip
      external_fqdn     = hub["vpn_port"] == "public" ? local.us_hub_vpn_fqdn : local.us_hub_private_ip
      hub_ip            = cidrhost(cidrsubnet(hub["vpn_cidr"], 0, 0), 1)
      site_ip           = hub["mode_cfg"] ? "" : cidrhost(cidrsubnet(hub["vpn_cidr"], 0), 3)
      hck_ip            = cidrhost(cidrsubnet(hub["vpn_cidr"], 0, 0), 1)
      vpn_psk           = hub["vpn_psk"]
      cidr              = hub["cidr"]
      ike_version       = hub["ike_version"]
      network_id        = hub["network_id"]
      dpd_retryinterval = hub["dpd_retryinterval"]
      sdwan_port        = hub["vpn_port"]
    }
  ]
  # Create map of RT IDs where add routes pointing to a TGW ID
  us_sdwan_ni_rt_ids = [
    for i in range(0, local.us_sdwan_number) : {
      for pair in setproduct(local.ni_rt_subnet_names, [for i, az in local.us_sdwan_azs : "az${i + 1}"]) :
      "${pair[0]}-${pair[1]}" => module.us_sdwan_vpc[i].rt_ids[pair[1]][pair[0]]
    }
  ]
  # Create FGTs config (auxiliary local list)
  us_sdwan_config = flatten([
    for i in range(0, local.us_sdwan_number) :
    [for ii, v in local.us_sdwan_azs :
      { "sdwan_id" = "${i}"
        "fgt_id"   = "az${ii + 1}.fgt${ii + 1}"
      }
    ]
    ]
  )

}

#-----------------------------------------------------------------------------------------------------
# DATA
#-----------------------------------------------------------------------------------------------------
# Read data from deployment 1_student-accounts
data "terraform_remote_state" "student_accounts" {
  backend = "local"
  config = {
    path = "../1_student-accounts/terraform.tfstate"
  }
}

data "http" "my-public-ip" {
  url = "http://ifconfig.me/ip"
}

# Create key-pairs
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "aws_key_pair" "eu_keypair" {
  key_name   = "${local.prefix}-eu-keypair"
  public_key = tls_private_key.ssh.public_key_openssh
}
resource "aws_key_pair" "us_keypair" {
  key_name   = "${local.prefix}-us-keypair"
  public_key = tls_private_key.ssh.public_key_openssh
}
resource "local_file" "ssh_private_key_pem" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "./ssh-key/${local.prefix}-ssh-key.pem"
  file_permission = "0600"
}
# Create new random API key to be provisioned in FortiGates.
resource "random_string" "api_key" {
  length  = 30
  special = false
  numeric = true
}
# Create new random API key to be provisioned in FortiGates.
resource "random_string" "vpn_psk" {
  length  = 20
  special = false
  numeric = true
}
# Create random string for DB phpmyadmin url name
resource "random_string" "db_url" {
  length  = 10
  special = false
  numeric = false
}

