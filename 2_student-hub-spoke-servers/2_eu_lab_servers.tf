#--------------------------------------------------------------------------------------------
# Create LAB Server
#--------------------------------------------------------------------------------------------
# Create master node LAB server
module "eu_hub_lab_server" {
  source = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vm?ref=v0.0.2"

  prefix        = "${local.prefix}-eu-hub"
  keypair       = aws_key_pair.eu_keypair.key_name
  instance_type = local.lab_srv_type
  linux_os      = "amazon"
  user_data     = data.template_file.srv_user_data.rendered

  subnet_id       = module.eu_hub_vpc.subnet_ids["az1"]["bastion"]
  subnet_cidr     = module.eu_hub_vpc.subnet_cidrs["az1"]["bastion"]
  security_groups = [module.eu_hub_vpc.sg_ids["default"]]

  tags = {
    Owner   = "${local.prefix}-lab-owner"
    Name    = "${local.prefix}-lab-portal"
    Project = local.tags["Project"]
  }
}
# Create user-data for server
data "template_file" "srv_user_data" {
  template = file("./templates/server_user-data.tpl")
  vars = {
    git_uri          = local.git_uri
    git_uri_app_path = local.git_uri_app_path
    docker_file      = data.template_file.srv_user_data_dockerfile.rendered
    nginx_config     = data.template_file.srv_user_data_nginx_config.rendered
    nginx_html       = data.template_file.srv_user_data_nginx_html.rendered
    redis_script     = ""

    db_host  = local.db["db_host"]
    db_user  = local.db["db_user"]
    db_pass  = local.db["db_pass"]
    db_name  = local.db["db_name"]
    db_table = local.db["db_table"]
    db_port  = local.db["db_port"]
  }
}
// Create dockerfile
data "template_file" "srv_user_data_dockerfile" {
  template = file("./templates/docker-compose.yaml")
  vars = {
    lab_fqdn      = local.lab_fqdn
    random_url_db = local.random_url_db
    db_host       = local.db["db_host"]
    db_user       = local.db["db_user"]
    db_pass       = local.db["db_pass"]
    db_name       = local.db["db_name"]
    db_table      = local.db["db_table"]
    db_port       = local.db["db_port"]
  }
}
// Create nginx config
data "template_file" "srv_user_data_nginx_config" {
  template = file("./templates/nginx_config.tpl")
  vars = {
    externalid_token = local.externalid_token
    random_url_db    = local.random_url_db
  }
}
// Create nginx html
data "template_file" "srv_user_data_nginx_html" {
  template = file("./templates/nginx_html.tpl")
  vars = {
    lab_fqdn = local.lab_fqdn
  }
}

#--------------------------------------------------------------------------------------------
# Create Student-0 server LAB
#--------------------------------------------------------------------------------------------
# Crate test VM in bastion subnet
module "eu_sdwan_vm" {
  for_each = { for i, v in local.eu_sdwan_spoke : i => v }
  source   = "git::github.com/jmvigueras/terraform-ftnt-aws-modules//vm?ref=v0.0.2"

  prefix   = "${local.prefix}-${each.value["id"]}"
  keypair  = aws_key_pair.eu_keypair.key_name
  linux_os = "amazon"

  subnet_id       = module.eu_sdwan_vpc[each.key].subnet_ids["az1"]["bastion"]
  subnet_cidr     = module.eu_sdwan_vpc[each.key].subnet_cidrs["az1"]["bastion"]
  security_groups = [module.eu_sdwan_vpc[each.key].sg_ids["default"]]
}