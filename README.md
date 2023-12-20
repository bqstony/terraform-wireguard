# Wireguard VPN Server Sample Terraform Deployment

## Automatisches Deployment

Deployment aller Ressourcen mit terraform.

**Documentation Links:**

- [Terraform install](https://developer.hashicorp.com/terraform/downloads)
- [Terraform Language Documentation](https://developer.hashicorp.com/terraform/language)
- [Store Terraform state in Azure Storage](https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage?tabs=azure-cli) 
- Terraform Providers
  - [azurerm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
  - [azapi](https://registry.terraform.io/providers/Azure/azapi/latest/docs)
  - [random](https://registry.terraform.io/providers/hashicorp/random/latest/docs)


- wireguard
  - [wireguard](https://www.wireguard.com/)
  - [Simple config sample](https://blog.yumdap.net/mit-wireguard-die-corporate-firewall-knacken/)
  - [sample azure deplyomend of wireguard](https://github.com/oroddlokken/terraform-azure-vm-wireguard)

**Kick-start**

WireGuard does not have usernames or passwords, instead it relies on public-key cryptography for authentication. The server has a pair with a private and public key, and the clients has their own pairs of private and public keys

```bash	
# Wireguard Server generate private and public keys
cd cicd/azure/vpnserver/keys

wg genkey | tee wg_server_private.key | wg pubkey > wg_server_public.key
wg genkey | tee wg_user1_private.key | wg pubkey > wg_user1_public.key
wg genkey | tee wg_user2_private.key | wg pubkey > wg_user2_public.key
```

Azure Storage Account container erstellen für Speichern der *.terraform.tfstate file pro Environment

```bash
az group create \
    --name infra-chn-terraform-rg \
    --location switzerlandnorth

az storage account create \
    --name infrachnmiheterraform \
    --resource-group infra-chn-terraform-rg \
    --location switzerlandnorth \
    --sku Standard_ZRS 

az storage container create \
    --account-name infrachnmiheterraform \
    --name tfstate
```

```bash
az login

cd cicd/azure/vpnserver/

# Terraform Initialisierung (einmalig)
terraform init -backend-config environment/dev/backend.hcl

# Optional: Update terraform modules
terraform init -upgrade

# Terraform deploymend nach dev
terraform plan -var-file environment/dev/variables.tfvars
terraform apply -var-file environment/dev/variables.tfvars --auto-approve
```

## Cleanup

```bash
terraform apply -destroy -var-file environment/dev/variables.tfvars --auto-approve
```


# Verbinden zu Wireguard per Client

Für den client `user1`

```
[Interface]
# {your_user1_private_key}
PrivateKey = GM43R9Gah3sGvf5VwBFwplQXRMC5LMVTMXu6a1QQY0o=
# the ip address of the client
Address = 192.168.2.2/24
# the ip address of the server dns (is the same as the vpn server address)
DNS = 192.168.2.1

[Peer]
# {your_server_public_key}
PublicKey = +O5xzqXAu6WT6OLP7aRgXGaP6lRXcASHetEtX9LNGl0=
# Set to 0.0.0.0/0 to route all traffic via the tunnel.
# AllowedIPs = 0.0.0.0/0
# To Route only the subnet request to the VPN tunnel
AllowedIPs = 192.168.2.0/24
# {your_server_fqdn}:51820 -> Public ip
Endpoint = 20.203.164.205:51820
```
