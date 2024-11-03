# hub-kickstart
Scripts and policies to kickstart ACM hub


## Vault initial config

This expects some initial configuration on Vault to be done. The following objects are required:

A Kubernetes auth method, at ocp_hub_config/, pointing towards `https://api.<hub-domain>:6443` for the kubernetes host and `Disable use of local CA and service account JWT` enabled.

This should have a role called `vault-configurator`, bound service account name `vault-configurator` in namespace `open-cluster-management`, with the following policy: `vault-configurator`.

This policy should look like this:

```hcl
path "/sys/policies/acl/ocp-spoke-*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list"]
}

path "/sys/auth" {
  capabilities = ["read", "list", "sudo"]
}

path "/sys/auth/ocp/*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list", "sudo"]
}

path "/auth/ocp/+/config" {
  capabilities = ["read", "update", "patch"]
}

path "/auth/ocp/+/role/*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list"]
}

path "/secrets/data/ocp_hub_config/*" {
  capabilities = ["read"]
}
```
