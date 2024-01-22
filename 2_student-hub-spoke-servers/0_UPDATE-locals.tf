#-----------------------------------------------------------------------------------------------------
# FortiGate Terraform deployment
# Active Passive High Availability MultiAZ with AWS Transit Gateway with VPC standard attachment
#-----------------------------------------------------------------------------------------------------
locals {
  #-----------------------------------------------------------------------------------------------------
  # General variables
  #-----------------------------------------------------------------------------------------------------
  prefix = "aws"

  tags = {
    Project = "aws2024hol"
  }

  eu_region = "eu-central-1"
  eu_azs    = ["eu-central-1a", "eu-central-1b"]

  route53_zone_name = "fortidemoscloud.com"

  #-----------------------------------------------------------------------------------------------------
  # FGT General
  #-----------------------------------------------------------------------------------------------------
  admin_port = "8443"
  admin_cidr = "${chomp(data.http.my-public-ip.response_body)}/32"
  //admin_cidr    = "0.0.0.0/0"
  instance_type = "c6i.large"
  fgt_build     = "build1575"
  license_type  = "payg"

  #--------------------------------------------------------------------------------------------
  # Server LAB variables
  #--------------------------------------------------------------------------------------------
  # LAB server FQDN
  lab_fqdn = "www.${data.aws_route53_zone.route53_zone.name}"

  # Lab server IP in bastion subnet
  lab_srv_private_ip = cidrhost(module.eu_spoke_to_tgw["${local.eu_spoke_to_tgw_prefix}-0"].subnet_cidrs["az1"]["vm"], 10) // "x.x.x.74"

  # External ID token generated in deployent student
  externalid_token = data.terraform_remote_state.student_accounts.outputs.externalid_token

  # Instance type 
  lab_srv_type = "t3.large"

  # Git repository
  git_uri          = "https://github.com/jmvigueras/sdwan-aws-hands-on-lab_setup.git"
  git_uri_app_path = "/sdwan-aws-hands-on-lab_setup/0_modules/hub-server/"

  # DB
  random_url_db = trimspace(random_string.db_url.result)

  db = {
    db_host  = "mysqldb"
    db_user  = "root"
    db_pass  = local.random_url_db
    db_name  = "students"
    db_table = "students"
    db_port  = "3306"
  }

  #-----------------------------------------------------------------------------------------------------
  # EU - EMEA HUB
  #-----------------------------------------------------------------------------------------------------
  # fgt_subnet_tags -> add tags to FGT subnets (port1, port2, public, private ...)
  eu_hub_fgt_subnet_tags = {
    "port1.public"  = "net-public"
    "port2.private" = "net-private"
    "port3.mgmt"    = ""
  }

  # General variables 
  eu_hub_number_peer_az = 1
  eu_hub_cluster_type   = "fgsp"
  eu_hub_vpc_cidr       = "10.10.0.0/24"

  # VPN HUB variables
  eu_id           = "EMEA"
  eu_hub_bgp_asn  = "65010" // iBGP RR server
  eu_hub_cidr     = "10.10.0.0/16"
  eu_hub_vpn_cidr = "172.16.100.0/24" // VPN DialUp spokes cidr
  eu_hub_vpn_ddns = "eu-hub-vpn"
  eu_hub_vpn_fqdn = "${local.eu_hub_vpn_ddns}.${local.route53_zone_name}"

  # VXLAN HUB to HUB variables
  eu_hub_vxlan_cidr = "172.16.11.0/24" // VXLAN cluster members cidr
  eu_hub_vxlan_vni  = "1101"           // VXLAN cluster members vni ID 

  eu_hub_to_op_vxlan_cidr = "172.16.12.0/24" // VXLAN to OP cidr
  eu_hub_to_op_vxlan_vni  = "1102"           // VXLAN to OP VNI ID

  eu_hub_to_us_hub_vxlan_cidr = "172.16.13.0/24" // VXLAN to US cidr
  eu_hub_to_us_hub_vxlan_vni  = "1103"           // VXLAN to US VNI ID

  # EU HUB TGW
  eu_tgw_cidr    = "10.10.10.0/24"
  eu_tgw_bgp_asn = "65011"

  # EU VPC SPOKE TO TGW
  eu_spoke_to_tgw_number = 2
  eu_spoke_to_tgw_prefix = "eu-spoke-to-tgw"
  eu_spoke_to_tgw = { for i in range(0, local.eu_spoke_to_tgw_number) :
    "${local.eu_spoke_to_tgw_prefix}-${i}" => "10.10.${i + 100}.0/24"
  }

  #-----------------------------------------------------------------------------------------------------
  # EU - EMEA SDWAN SPOKE
  #-----------------------------------------------------------------------------------------------------
  # General variables 
  eu_sdwan_number_peer_az = 1
  eu_sdwan_azs            = ["eu-central-1a"]

  # VPN HUB variables
  eu_sdwan_number  = 1
  eu_spoke_bgp_asn = "65000"

  eu_sdwan_spoke = [for i in range(0, local.eu_sdwan_number) :
    { "id"         = "${local.eu_region}-office-${i}"
      "cidr"       = "10.1.${i}.0/24"
      "bgp_asn"    = local.eu_spoke_bgp_asn
      "student_id" = "${local.prefix}-${local.eu_region}-user-${i}"
    }
  ]

  #-----------------------------------------------------------------------------------------------------
  # EU - EMEA ON-PREMISE HUB
  #-----------------------------------------------------------------------------------------------------
  us_region = "eu-central-1"
  us_azs    = ["eu-central-1a", "eu-central-1b"]

  # fgt_subnet_tags -> add tags to FGT subnets (port1, port2, public, private ...)
  eu_op_fgt_subnet_tags = {
    "port1.public"  = "net-public"
    "port2.private" = "net-private"
    "port3.mgmt"    = "net-mgmt"
  }

  # General variables 
  eu_op_number_peer_az = 1
  eu_op_cluster_type   = "fgcp"
  eu_op_vpc_cidr       = "10.20.0.0/24"

  # VPN HUB variables
  eu_op_bgp_asn  = "65020"
  eu_op_cidr     = "10.20.0.0/16"
  eu_op_vpn_cidr = "172.20.100.0/24" // VPN DialUp spokes cidr

  eu_op_vpn_ddns = "eu-op-vpn"
  eu_op_vpn_fqdn = "${local.eu_op_vpn_ddns}.${local.route53_zone_name}"

  #-----------------------------------------------------------------------------------------------------
  # US - NORAM HUB
  #-----------------------------------------------------------------------------------------------------
  # fgt_subnet_tags -> add tags to FGT subnets (port1, port2, public, private ...)
  us_hub_fgt_subnet_tags = {
    "port1.public"  = "net-public"
    "port2.private" = "net-private"
    "port3.mgmt"    = "net-mgmt"
  }

  # General variables 
  us_hub_number_peer_az = 1
  us_hub_cluster_type   = "fgcp"
  us_hub_vpc_cidr       = "10.30.0.0/24"

  # VPN HUB variables
  us_id           = "NORAM"
  us_hub_bgp_asn  = "65030"
  us_hub_cidr     = "10.30.0.0/16"
  us_hub_vpn_cidr = "172.30.100.0/24" // VPN DialUp spokes cidr
  us_hub_vpn_ddns = "us-hub-vpn"
  us_hub_vpn_fqdn = "${local.us_hub_vpn_ddns}.${local.route53_zone_name}"

  # US HUB TGW
  us_tgw_cidr    = "10.30.10.0/24"
  us_tgw_bgp_asn = "65031"

  # US VPC SPOKE TO TGW
  us_spoke_to_tgw_number = 1
  us_spoke_to_tgw = { for i in range(0, local.us_spoke_to_tgw_number) :
    "us-spoke-to-tgw-${i}" => "10.30.${i + 100}.0/24"
  }

  #-----------------------------------------------------------------------------------------------------
  # US - NORAM SDWAN SPOKE
  #-----------------------------------------------------------------------------------------------------
  # General variables 
  us_sdwan_number_peer_az = 1
  us_sdwan_azs            = ["eu-central-1a"]

  # SPOKE SDWAN VPN HUB variables
  us_sdwan_number  = 1
  us_spoke_bgp_asn = "65000"

  us_sdwan_spoke = [for i in range(0, local.us_sdwan_number) :
    { "id"      = "us-office-${i}"
      "cidr"    = "10.3.${i}.0/24"
      "bgp_asn" = local.us_spoke_bgp_asn
    }
  ]
}
