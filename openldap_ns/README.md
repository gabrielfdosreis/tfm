# SIMPLE OPEN-LDAP CHART

Descriptors that installs an openldap version 1.2.1 chart in a K8s cluster

There is one VNF (openldap\_vnf) with only one KDU.

There is one NS that connects the VNF to a mgmt network

## Onboarding and instantiation

```bash
osm nfpkg-create openldap_knf.tar.gz
osm nspkg-create openldap_ns.tar.gz

osm ns-create --ns_name ldap --nsd_name openldap_ns --vim_account ost9-canonical-fortville --ssh_keys ${HOME}/.ssh/id_rsa.pub --wait
```

### Instantiation option

Some parameters could be passed during the instantiation.

* replicaCount: Number of Open LDAP replicas that will be created

```bash
osm ns-create --ns_name ldap --nsd_name openldap_ns --vim_account ost9-canonical-fortville --config '{additionalParamsForVnf: [{"member-vnf-index": "openldap", "additionalParams": {"replicaCount": "2"}}]}'
```
