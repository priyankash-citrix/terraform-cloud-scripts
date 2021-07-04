# Configure Citrix ADC High Availability pair with availability zones

This document provides the configuration scripts to deploy Citrix ADC High Availability pair with availability zones.

* A Virtual network with three subnets, associated security groups, and routing tables.
* Two Citrix ADC instances configured in a High Availability mode.
* An ubuntu bastion host with one NIC.

## Resource group

All resources must be deployed in a single resource group.

The name of the resource group can be changed through the `resource_group_name` input variable.

## Configure Virtual Network

All network interfaces are deployed inside a single Virtual Network. There are three subnets:

* Management
* Client
* Server

The Management subnet contains the ADC management interface to which the NSIP address is assigned
and the interface of the ubuntu bastion host.

The Client subnet contains the ADC client interface to which the VIP address is assigned.

The server subnet contains the ADC server interface to which the SNIP is assigned.
Any backed service hosts deployed must have an interface defined within this subnet
so that the ADC can communicate with them through the SNIP address.

## Security groups

There are three security groups each attached to a single subnet.

The management security group contains a security rule which
allows SSH, HTTP and HTTPS inbound traffic
from the controlling subnet.

The controlling subnet can be as restrictive as a single /32 ip address
or as permissive as 0.0.0.0/0.

The client security group allows HTTP and HTTPS access from the internet.

The server security group restricts traffic flow within the subnet.
That means network interfaces belonging to this subnet will only able to
send and receive traffic only to other interfaces inside the subnet.

## Citrix ADC configuration

The Citrix ADC instances can be deployed as instances with three separate
NICs each in a separate subnet. 

The ADC bootstrap code will assign IP addresses to each interface
according to the IP addresses assigned by Azure.

The NSIP address is assigned to the management network interface. 
There are no additional security rules attached to the interface.
This means that access is only restricted by the subnet attached security group,
which allows access from the controlling subnet for SSH, HTTP and HTTPS.

There is a public IP address associated with this interface so that it is reachable from
outside the Virtual Network.

To enhance security, you can remove the public IP address.
In such case, the management interface can only be accessible only from within the
Virtual Network.

It means that all SSH connections and NITRO API calls must go through
the bastion host.

the VIP address is assigned to the client network interface.
This private VIP address is not used for incoming traffic in an HA mode.

Instead, the IP address that is used for traffic is the public IP address of the
Azure Load Balancer. This address must be assigned to a Vserver (LB/CS) with
functioning backend services. From that point on the ALB public IP address
starts load balancing the instances.

You can find a sample LB configuration [here](../simple_lb_ha).

In the case of a fail over the ALB detects the details through the probe one node going down
and the secondary taking over at which point it starts sending traffic to the
new primary node. Traffic may be impacted for a few seconds until the ALB probe
can determine the functional state of the HA pair.

There are no additional security rules attached to the interface.
This means access is only restricted by the subnet attached security group,
which allows HTTP and HTTPS traffic from anywhere.

The SNIP address is assigned to the server network interface.
No public IP address is associated with this interface.
There are no additional security rules attached to the interface.
This means access is only restricted by the subnet attached security group,
which only allows traffic from the subnet.

An SSH key is required when creating the ADC host.

Password authentication is also allowed.
You must hoose a strong password to enhance security.

## Bastion host

Along with the Citrix ADC, an ubuntu bastion host is deployed.

Its role is to provide access to the Virtual Network from
a secured host.

The host requires an SSH key for access.

It has a single network interface which belongs to the management subnet.
As such, it can be accessed form the controlling subnet.

In case the public IP address associated with the ADC management network interface
is removed the bastion host is the only other way to access the NSIP.

This means that all SSH and NITRO API calls must be executed from
the bastion host.

## Explanation of the Input Variables

| Variable                           | Description                          |
| ---------------------------------- | ------------------------------------ |
| `resource_group_name`              | Specify Azure Resource Group Name which is used for deploying Citrix ADC VPX. |
| `location`                         | Specify Azure Region name to be used for Citrix ADC VPX.                     |
| `virtual_network_address_space`    | Specify the CIDR block to be used for Azure VNet.                            |
| `management_subnet_address_prefix` | Specify the CIDRs for the Management Subnet.                                 |
| `client_subnet_address_prefix`     | Specify the CIDR  for the Client Subnet.                                     |
| `server_subnet_address_prefix`     | Specify the CIDRs for the Server Subnet.                                     |
| `adc_admin_password`               | Specify password to be configured on Citrix ADC VPX.                                 |
| `controlling_subnet`               | Specify the CIDR which has access to the deployed Citrix ADC instances. |

## Create VPX HA across availability Zones for Cloud Native deployments

**For Kubernetes Cluster**

For Cloud Native deployment, in which Citrix ADC VPX is outside the Kubernetes cluster acts as Ingress, set the variable; `create_ILB_for_management` as `true`.

Th following is a sample Terraform Variable file:

```
resource_group_name="my-ha-inc-rg"
location="southeastasia"
virtual_network_address_space="192.168.0.0/16"
management_subnet_address_prefix="192.168.0.0/24"
client_subnet_address_prefix="192.168.1.0/24"
server_subnet_address_prefix="192.168.2.0/24"
adc_admin_password="<Provide a strong VPX Password>"
controlling_subnet="<CIDR to allow Management Access>"
create_ILB_for_management=true
```

For more information on Cloud Native deployments, see [Citrix Ingress Controller GitHub](https://github.com/citrix/citrix-k8s-ingress-controller)

**For Openshift Cluster**

This terraform can also be used to deploy Citrix ADC VPX in HA-INC mode for an OpenShift Cluster. For this, you need to provide some additional parameters related to the OpenShift cluster deployed on Azure.

**High Level Additonal Configuration Entities created by the Terraform**

### Networking
1. VNet peering between VNet of VPX HA and VNet of OpenShift cluster.
2. Route table and routes for VPX HA to reach pod network of OpenShift cluster.

### Citrix ADC
1. Routes in ADC VPX for reaching Openshift worker subnet through the Server subnet of VPX HA.
2. Routes in ADC VPX for reaching Openshift pod network through the Server subnet of VPX HA.

### Openshift Cluster
1. Network security rule in Network security group of openshift cluster for allowing traffic from ADC VPX SNIPs.

### High Level Additonal Configuration Entities created by the Bash script.
As the OpenShift cluster is already created by `openshift-installer` before running this terraform, there are some configurations which cannot be performed with the terraform. For this, a bash script is available. Run the bash script after running terraform for performing the rest of the configurations.

The following configuration is added by Bash script:
1. OpenShift worker and master subnet association with the route table created for HA and pod network of OpenShift.
2. Enables `IP Fordwording` in all the worker node VM's NIC to allow traffic from HA to the pod network of the Openshift Cluster.

For more information on Cloud Native deployment, see [Citrix Ingress Controller GitHub](https://github.com/citrix/citrix-k8s-ingress-controller).

### Steps to Deploy:

#### Prerequisites
1. Ensure that you have Terraform.
2. Ensure that you have AWS CLI installed and configured using the command: `aws configure`.
3. Ensure that you have Kubernetes configuration utility `kubectl` installed.
4. Ensure that you have OpenShift Cluster up and running in Azure platform.

#### Clone the GitHub Repo

```
git clone https://github.com/citrix/terraform-cloud-scripts.git
cd terraform-cloud-scripts/terraform-cloud-scripts/azure/ha_availability_zones
```

#### Initialise the terraform deployment

The following is a sample input variable file that contains the input variables to run the entire deployment.

##### Sample Input Variables

```
resource_group_name="priyanka-ha-inc-test"
location="southeastasia"
virtual_network_address_space="1.1.0.0/16"
management_subnet_address_prefix="1.1.1.0/24"
client_subnet_address_prefix="1.1.2.0/24"
server_subnet_address_prefix="1.1.3.0/24"
adc_admin_password="CitrixADC"
controlling_subnet="2.2.2.2"
create_ILB_for_management=true
create_ha_for_openshift=true
openshift_cluster_name = "cnn-oc-cluster-1234"
openshift_cluster_host_network_details={"10.128.2.0/23": "10.0.32.4", "10.129.2.0/23": "10.0.32.5", "10.131.0.0/23": "10.0.32.6"}
```
**Important:** Make sure you input values in the file in accordance with your deployment topology.

##### Explanation of the Additional Input Variables

| Variable                               | Description                          |
| -------------------------------------- | ------------------------------------ |
| create_ILB_for_management              | Enable this to configure ILB whose IP will be used by CIC for configuring Citrix ADC VPX HA. |
| create_ha_for_openshift                | Set this to `true` for creating HA for OpenShift cluster. |
| openshift_cluster_name                 | Provide the name of the Openshift cluster deployed in Azure. |
| openshift_cluster_host_network_details | Provide details of Openshift pod network and node IPaddresses. This should be list of dictionaries and the key for each dictionary is pod network prefix and value should be OpenShift cluster node IP address. |

**Important:** After creating a variable file in accordance with your requirements, ensure to name the file with the suffix `.auto.tfvars`. For example, `my-vpx-ha-deployment.auto.tfvars`.

After you create an input variable file, you can initialize the terraform using the following command.

```
terraform init
```

#### Terraform Plan and Apply

```
terraform plan
terraform apply -auto-approve
```

#### Run the bash scipt:
Run the bash scipt for additinal configuration inside the same folder:

```
chmod +x openshift.sh
./openshift.sh
```

