Various utility scripts cobbled together for installer dev work.

# oscontrol

Provides simple facility for creating, dropping and listing slice hosts based
on beaker hosts configuration. Uses the fog/openstack gem underneath. Requires
.fog to have these openstack parameters set:

```yaml
  :default:
    :openstack_auth_token: 'something'
    # Note that the cache_ttl has no effect on how long the token is cached by
    # openstack. It just affects whether the fog-openstack gem caches the token
    # info so that we can find it to push back into ~/.fog ...
    :openstack_cache_ttl: 86400
    :openstack_auth_url: 'https://slice-pdx1-prod.ops.puppetlabs.net:5000/v3/auth/tokens'
    :openstack_username: "joshua.partlow"
    :openstack_project_name: "joshua.partlow"
    :openstack_domain_id: "default"
```

and that the openstack_auth_token is valid.

# refresh_openstack_fog_token

Checks that the :openstack_auth_token in .fog is still valid, if it is not,
requests LDAP password for the :openstack_username, gets a new token and
updates .fog with it.
