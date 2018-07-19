set -x
environment=${1}
ssldir=/etc/puppetlabs/puppet/ssl
host=$(facter fqdn)
uri="https://${host?}:8140/puppet-admin-api/v1/environment-cache"
if [ -n "$environment" ]; then
  uri="${uri:?}?environment=${environment:?}"
fi

curl -i --cert "${ssldir?}/certs/${host?}.pem" --key "${ssldir?}/private_keys/${host?}.pem" --cacert "${ssldir?}/ca/ca_crt.pem" -X DELETE "${uri?}"
