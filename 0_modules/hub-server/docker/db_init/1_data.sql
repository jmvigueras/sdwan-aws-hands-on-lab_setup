USE students;
INSERT INTO `students` (`user_id`, `user_sort`, `server_ip`, `vpc_cidr`, `email`, `access_key`, `secret_key`, `user_password`, `externalid_token`, `server_test`, `server_check`, `region`, `region_az1`, `accountid`, `hub_fgt_fqdn`, `cloud9_url`) VALUES 
('aws-eu-central-1-user-0', 'user-0', '10.1.0.74', '10.1.0.0/24', 'jvigueras@fortinet.com', 'access_key', "secret_key", "user_password", 'token', '0', '00:00:00 AM', 'eu-central-1', 'eu-central-1a', 'accountid', 'hub-vpn.fqdn.com', 'https://cloud9.x.amazon.com/IDE');
COMMIT;