# Oracle Breeze Always Free infrastructure

Terraform deployment for two purpose-separated Ubuntu VMs on Oracle Cloud Infrastructure (OCI):

| VM | Always Free allocation | Addressing | Purpose |
| --- | --- | --- | --- |
| `breeze-trading` | `VM.Standard.E2.1.Micro`, 50 GB boot volume | Reserved public IPv4 plus private IPv4 | Live ICICI Breeze trading only |
| `vscode-dev` | `VM.Standard.A1.Flex`, 1 OCPU, 6 GB RAM, 50 GB boot volume | Ephemeral public IPv4 plus private IPv4 | ARM64 VS Code Remote-SSH development |

Both hosts share one VCN, public subnet, internet gateway, route table, and security list. Inbound traffic is limited to SSH from one explicitly trusted IPv4 `/32`; all other unsolicited public ingress is denied.

## Installed software

`breeze-trading` receives Python 3, pip, Git, a Python virtual environment, pinned `breeze-connect`, Tailscale, unattended security upgrades, and a hardened systemd-ready service layout. The placeholder service is disabled until trading code and credentials are configured.

`vscode-dev` receives Git, Python 3, pip, venv, build-essential, OpenSSH Server, Node.js 24 LTS with npm, Docker Engine, Buildx, Docker Compose v2, Tailscale, and unattended security upgrades. Docker's official ARM64 packages are used. The `ubuntu` account is added to the `docker` group; membership in that group is effectively root-level access and is appropriate only for this dedicated development VM.

Neither host is automatically authenticated to Tailscale, and no Breeze credentials are placed in cloud-init, instance metadata, Terraform state, or GitHub Actions.

## Always Free guardrails

The configuration fixes the following values in code rather than exposing paid-size variables:

- `breeze-trading`: `VM.Standard.E2.1.Micro`.
- `vscode-dev`: `VM.Standard.A1.Flex`, reduced to exactly 1 OCPU and 6 GB RAM to improve the chance of placement when A1 capacity is constrained.
- Two 50 GB boot volumes: 100 GB total against the 200 GB Always Free block-storage allocation.
- Compatible Canonical Ubuntu 22.04 platform images selected separately for x86 and ARM64.
- One reserved public IPv4 for trading and the normal instance-lifetime public IPv4 for development.
- No NAT gateway, load balancer, database, backups, or additional block volumes.

Every workflow run requires confirmation that `OCI_REGION` is the tenancy home region. Terraform assertions verify both shapes, A1 CPU/RAM, total boot allocation, and the reserved lifetime of the trading address.

OCI eligibility still depends on remaining tenancy quota, home-region placement, and host capacity. Terraform cannot inspect whether other resources have already consumed the free allocation and cannot guarantee a zero invoice. Check the OCI Console and generated plan before every apply. An out-of-host-capacity error is not permission to substitute a paid shape.

References: [OCI Always Free resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm), [Terraform native OCI backend](https://developer.hashicorp.com/terraform/language/backend/oci), [Docker Engine for Ubuntu](https://docs.docker.com/engine/install/ubuntu/), and [Node.js release status](https://nodejs.org/en/about/previous-releases).

## Prerequisites

1. Create an OCI compartment, or deliberately use the tenancy root compartment.
2. Create a least-privilege OCI API user/group and upload an API signing public key. It needs permission to manage instances, volumes, virtual-network resources, and public IPs in the target compartment, plus object access to the state bucket.
3. In the tenancy home region, create a private OCI Object Storage bucket for Terraform state. Enable object versioning, disable public access, and grant the API user `OBJECT_INSPECT`, `OBJECT_CREATE`, `OBJECT_DELETE`, and `OBJECT_READ` on that bucket. The bucket is a bootstrap dependency and cannot safely be created from the state it stores.
4. Create GitHub Environments named `planning` and `production`. Add required reviewers to `production` when deployment protection rules are available.
5. Generate one SSH key pair for administration. Only its public key goes into GitHub Actions.

## Exact GitHub Actions secrets

Create these repository or environment secrets under **Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `OCI_TENANCY_OCID` | Tenancy OCID (`ocid1.tenancy...`) |
| `OCI_USER_OCID` | API user's OCID (`ocid1.user...`) |
| `OCI_FINGERPRINT` | Fingerprint of the uploaded OCI API signing key |
| `OCI_PRIVATE_KEY` | Entire PEM-encoded OCI API signing private key, including header, footer, and newlines |
| `OCI_REGION` | Tenancy home-region identifier, such as `ap-mumbai-1` |
| `OCI_COMPARTMENT_OCID` | Target compartment OCID, or tenancy OCID for the root compartment |
| `OCI_OBJECT_STORAGE_NAMESPACE` | Object Storage namespace shown on the tenancy page |
| `OCI_STATE_BUCKET` | Existing private, versioned Object Storage bucket name |
| `SSH_AUTHORIZED_KEY` | OpenSSH public key, such as the contents of `~/.ssh/id_ed25519.pub` |
| `SSH_ALLOWED_CIDR` | Trusted current public IPv4 with `/32`, for example `203.0.113.10/32` |

Never commit OCI credentials, SSH private keys, `*.tfvars`, Terraform state, Tailscale auth keys, or ICICI Breeze credentials. Breeze credentials should be added directly on the trading VM or supplied by a dedicated secret manager.

## Deploy with GitHub Actions

1. Open **Actions → Terraform OCI → Run workflow**.
2. Select `plan`, check the home-region confirmation, and inspect every planned resource and shape.
3. Run it again with `apply`. The exact plan generated in that job is applied. Protect the `production` environment with reviewers for an additional approval gate.
4. Read `breeze_trading_public_ip` and `vscode_dev_public_ip` from the apply outputs.

The workflow uses Terraform's native OCI Object Storage backend with locking. Plan files remain on the ephemeral runner and are removed in the final step.

If the first availability domain lacks capacity, use the workflow's optional `breeze_availability_domain` and `vscode_availability_domain` inputs independently. E2 micro availability can be restricted to one AD.

## VS Code Remote-SSH

Wait for bootstrap completion first:

```bash
ssh ubuntu@VSCODE_DEV_PUBLIC_IP
sudo cloud-init status --wait
node --version
npm --version
docker --version
docker compose version
```

On your workstation, install Visual Studio Code and the **Remote - SSH** extension. Add this entry to `~/.ssh/config`:

```sshconfig
Host oracle-vscode-dev
  HostName VSCODE_DEV_PUBLIC_IP
  User ubuntu
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
```

Confirm the connection with `ssh oracle-vscode-dev`. In VS Code, run **Remote-SSH: Connect to Host...** from the Command Palette and choose `oracle-vscode-dev`, then open `/home/ubuntu/workspace`.

The A1 VM is ARM64. Use ARM64-compatible binaries and container images, or multi-platform images that include `linux/arm64`. After the first login, run `sudo tailscale up`; once private Tailscale connectivity works, prefer its address in `HostName`. You can then remove public SSH exposure by changing the OCI ingress policy in a deliberate follow-up deployment.

## Trading VM setup

Wait for cloud-init, authenticate Tailscale, and install credentials locally:

```bash
ssh ubuntu@BREEZE_TRADING_PUBLIC_IP
sudo cloud-init status --wait
sudo tailscale up
sudo cp /etc/breeze/breeze.env.example /etc/breeze/breeze.env
sudo chmod 0640 /etc/breeze/breeze.env
sudoedit /etc/breeze/breeze.env
```

Deploy reviewed trading code to `/opt/breeze/app/main.py`, keep it root-owned and group-readable, test it, and only then enable the service:

```bash
sudo chown root:breeze /opt/breeze/app/main.py
sudo chmod 0640 /opt/breeze/app/main.py
sudo -u breeze /opt/breeze/venv/bin/python /opt/breeze/app/main.py
sudo systemctl enable --now breeze-trading.service
sudo systemctl status breeze-trading.service
```

Do not use `breeze-trading` for development workloads. Keep trading code minimal, review every change, and never emit credentials or session tokens into logs.

## Local validation

Terraform 1.12 or newer is required. Export the `TF_VAR_*` values or copy `terraform/terraform.tfvars.example` to the ignored `terraform/terraform.tfvars`, then initialize the backend:

```bash
cd terraform
export OCI_tenancy_ocid="$TF_VAR_tenancy_ocid"
export OCI_user_ocid="$TF_VAR_user_ocid"
export OCI_fingerprint="$TF_VAR_fingerprint"
export OCI_private_key_path="$TF_VAR_private_key_path"
export OCI_region="$TF_VAR_region"
terraform init \
  -backend-config="bucket=YOUR_PRIVATE_STATE_BUCKET" \
  -backend-config="namespace=YOUR_OBJECT_STORAGE_NAMESPACE"
terraform fmt -check -recursive
terraform validate
terraform plan
```

## Repository layout

- `terraform/` — OCI infrastructure, immutable free-tier sizes, validations, and outputs.
- `cloud-init/cloud-config.yaml` — dedicated Breeze trading host bootstrap.
- `cloud-init/vscode-dev.yaml` — ARM64 development host and Remote-SSH toolchain bootstrap.
- `.github/workflows/terraform.yml` — manual format, validate, plan, and apply workflow.
- `.github/workflows/retry-vscode.yml` — guarded 30-minute capacity retry for only `vscode-dev`; it disables itself after success.

`terraform destroy` is intentionally not exposed by the workflow. Destroying the complete stack releases the reserved trading address. Keep remote state and its version history until all resources have been verified as removed.
