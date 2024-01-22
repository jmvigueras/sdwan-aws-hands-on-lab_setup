#-----------------------------------------------------------------------------------------------------
# EU - EMEA HUB
#-----------------------------------------------------------------------------------------------------
output "eu_hub_ids" {
  value = module.eu_hub.fgt_list
}

output "eu_hub_ni_list" {
  value = module.eu_hub_nis.fgt_ni_list
}

output "eu_spoke_to_tgw_vm" {
  value = { for k, v in module.eu_spoke_to_tgw_vm : k => v.vm }
}

#-----------------------------------------------------------------------------------------------------
# EU SDWAN SPOKES
#-----------------------------------------------------------------------------------------------------
output "eu_sdwan_ids" {
  value = { for k, v in module.eu_sdwan : k => v.fgt_list }
}

output "eu_sdwan_ni_list" {
  value = { for k, v in module.eu_sdwan_nis : k => v.fgt_ni_list }
}

#-----------------------------------------------------------------------------------------------------
# LAB Servers - Variables used in 3_ and 4_ steps of LAB setup
#-----------------------------------------------------------------------------------------------------
output "hub" {
  value = {
    public_ip   = local.eu_hub_vpn_fqdn
    public_fqdn = local.eu_hub_vpn_fqdn
  }
}

output "lab_server" {
  value = {
    private_ip = module.eu_hub_lab_server.vm["private_ip"]
    lab_uri    = "http://${module.eu_hub_lab_server.vm["public_ip"]}/${local.externalid_token}"
    phpadmin   = "http://${module.eu_hub_lab_server.vm["public_ip"]}/${local.random_url_db}"
    db_user    = "root"
    db_pass    = local.db["db_pass"]
  }
}

output "student_server" {
  value = {
    private_ip  = [for v in module.eu_sdwan_vm : v.vm["private_ip"]]
    public_ip   = [for v in module.eu_sdwan_vm : v.vm["public_ip"]]
    server_url  = [for v in module.eu_sdwan_vm : "http://${v.vm["public_ip"]}"]
    fgt_vip_url = [for k, v in module.eu_sdwan_nis : "http://${values(v.fgt_eips_map)[0]}"]
  }
}

output "lab_portal" {
  value = {
    portal   = "http://${local.lab_fqdn}/${local.externalid_token}"
    phpamdin = "http://${local.lab_fqdn}/${local.random_url_db}"
    db_user  = "root"
    db_pass  = local.db["db_pass"]
  }
}

#-----------------------------------------------------------------------------------------------------
# HUB ON-PREMISES
#-----------------------------------------------------------------------------------------------------
output "eu_op_ids" {
  value = module.eu_op.fgt_list
}

output "eu_op_ni_list" {
  value = module.eu_op_nis.fgt_ni_list
}

output "eu_op_vm" {
  value = module.eu_op_vm.vm
}

#-----------------------------------------------------------------------------------------------------
# US - NORAM HUB
#-----------------------------------------------------------------------------------------------------
output "us_hub_ids" {
  value = module.us_hub.fgt_list
}

output "us_hub_ni_list" {
  value = module.us_hub_nis.fgt_ni_list
}

output "us_hub_vm" {
  value = module.us_hub_vm.vm
}

output "us_spoke_to_tgw_vm" {
  value = { for k, v in module.us_spoke_to_tgw_vm : k => v.vm }
}

#-----------------------------------------------------------------------------------------------------
# US SDWAN SPOKES
#-----------------------------------------------------------------------------------------------------
output "us_sdwan_ids" {
  value = { for k, v in module.us_sdwan : k => v.fgt_list }
}

output "us_sdwan_ni_list" {
  value = { for k, v in module.us_sdwan_nis : k => v.fgt_ni_list }
}

output "us_sdwan_vm" {
  value = { for k, v in module.us_sdwan_vm : k => v.vm }
}


/*
#-------------------------------
# Debugging 
#-------------------------------
output "eu_hub_ni_list" {
  value = module.eu_hub_nis.ni_list
}
output "debugs" {
  value = { for k, v in module.eu_hub_config : k => v.debugs }
}
output "eu_sdwan_ni_list" {
  value = { for k, v in module.eu_sdwan_nis : k => v.ni_list }
}

output "eu_hub_public_eips" {
  value = local.eu_hub_public_eips
}
*/