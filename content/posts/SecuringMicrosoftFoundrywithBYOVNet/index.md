---
title: 'Securing Microsoft Foundry with Bring Your Own VNET'
date: '2025-12-07'
draft: false
showComments: true
---

![alt](20251207080909.png)

## Introduction 
Microsoft Foundry (Previously called AI Foundry) provides powerful capabilities for building and deploying AI agents and solutions. For enterprise customers, securing these deployments within their own network infrastructure is critical for compliance, governance, and integration with existing landing zones. The Bring Your Own (BYO) VNET deployment pattern enables organizations to secure and control both inbound and outbound access to Foundry Agent services while maintaining network isolation. 
In this blog post, I'm sharing lessons learned from a recent Microsoft Foundry Agent Service deployment utilizing the BYO VNET pattern. This approach is particularly valuable for organizations that need to: 
- Integrate AI Foundry with existing hub-and-spoke network architectures 
- Enforce strict network security policies 
- Maintain compliance with regulatory requirements 
- Control data flow and access patterns
  
### Understanding AI Foundry Versions
It's important to note that there are multiple versions of Azure AI Foundry in the documentation. This blog focuses on **Azure AI Foundry Classic** Service. For a detailed explanation of the differences between Hub based and Projectbased Foundry experiences, refer to [this blog](link).

## Security Architecture Overview 
When deploying AI Foundry using the BYO VNET approach, there are three critical security layers to configure: 

1. **Individual Resource Configuration** - Network access settings for each Azure resource 
2. **Network Security Groups (NSGs)** - Subnet level traffic filtering for the delegated AI Foundry subnet 
3. **Azure Firewall Configuration** - Centralised outbound access control

## Prerequisites 
Before deploying AI Foundry with BYO VNET, ensure you have: 

- An existing VNET with available address space for dedicated subnets 
- Azure Firewall or equivalent network virtual appliance 
- Appropriate Azure RBAC permissions to create resources and configure networking 
- Understanding of your organization's network architecture and security requirements
### Deployment
Foundry team has published templates for both [Bicep](https://github.com/azure-ai-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/15-private-network-standard-agent-setup) and [Terraform](https://github.com/azure-ai-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-terraform/15b-private-network-standard-agent-setup-byovnet) that can be used for creating Foundry deployment using customer owned VNET. This deployment template requires below resources for a successful deployment 

**1. Agent Subnet with Delegation**
- Recommended minimum size: /26 or larger depending on scale requirements
- Agent subnet delegated to Foundry with Subnet delegating using "Microsoft.App/environments" as below 
![20251204054834](20251204054834.png)

**2. Private Endpoints Subnet**
- Dedicated subnet for hosting private endpoints to AI Foundry resources
- No delegation required
- Recommended size: /27 or larger

### Required Private DNS Zones
AI Foundry Agent Service must be able to resolve private endpoints. This can be achieved by either:
- Directly linking Private DNS zones to your VNETs, or
- Using custom DNS configuration on the VNET pointing to Azure Private DNS Resolver or other DNS resolver service

**Required DNS zones:**
- `privatelink.blob.core.windows.net`
- `privatelink.cognitiveservices.azure.com`
- `privatelink.documents.azure.com`
- `privatelink.openai.azure.com`
- `privatelink.search.windows.net`
- `privatelink.services.ai.azure.com`
- `privatelink.file.core.windows.net`
### Network Security Group Configuration 
NSG configuration is critical for controlling outbound access from the AI Foundry delegated agent subnet. The following outbound rules represent the minimum required configuration:
### NSG Rules
**1. Azure Active Directory (Required)**
- Service Tag: `AzureActiveDirectory`
- Required for identity access 
- Port: 443 (HTTPS)

**2. Container Apps Management**
- Service Tag: `AzureContainerAppsManagement`
- Required for Container Apps platform management
- Port: 443

**3. Container Registry**
- Service Tag: `AzureContainerRegistry`
- Required for pulling container images
- Port: 443

**4. Container Apps Internal Communication**
- Destination: - 100.100.0.0/17, 100.100.128.0/19,100.100.160.0/19,100.100.192.0/19
- Container Apps uses this range for internal platform communication
- Ports: Any
![20251206134928](20251206134928.png)

### Azure Firewall Configuration
Azure Firewall provides centralized control over outbound traffic from the AI Foundry environment. The firewall processes rules in the following order:  

1. **Network Rules** - Processed first
2. **Application Rules** - Processed if no network rule match
### Network Rules Configuration
Configure network rules to allow traffic to Azure service tags:
- `AzureActiveDirectory` - Port 443
- `InternalACATraffic`
**Key Configuration Note:** Create an IP Group containing the Container Apps internal IP ranges (100.64.0.0/10, 100.100.0.0/17, 100.100.128.0/19, 100.100.160.0/19, 100.100.192.0/19) to use as source addresses in firewall rules.

![20251206143806](20251206143806.png)

![20251206143750](20251206143750.png)
### Application Rules Configuration
Application rules provide FQDN-based filtering for outbound HTTPS traffic to specific domains required by AI Foundry services.

![20251206163443](20251206163443.png)
### Resource Configuration 
All AI Foundry project resources should be configured with network security in mind and with disabled public access. 

AI Foundry resource network configuration below 
![20251206172829](20251206172829.png)
Delegated subnet configuration 
![20251206172848](20251206172848.png)
Cosmos DB Network configuration - Disabled Public Access
![20251206172920](20251206172920.png)
AI Search Network configuration - Disabled Public Access
![20251206172943](20251206172943.png)
Azure Storage Network configuration - Disabled Public Access 
![20251206173023](20251206173023.png)

### Foundry Agent Validation
After deployment, validate that the AI Foundry Agent service functions correctly:

![20251206163823](20251206163823.png)
### 1. Create a New Agent
Use the AI Foundry Portal to create and configure a new agent. Successful agent creation indicates proper network connectivity and resource access.

![[Pasted image 20251206165637.png | 500]]
### 2. Upload Knowledge Files
Test file upload functionality, which demonstrates:
- Azure Storage connectivity via private endpoint
- AI Search integration for vector database population
- Authentication through Entra ID
![20251206165735](20251206165735.png)

### 3. Test Chat Playground
Validate agent responses using the chat playground. This tests:
- End-to-end agent functionality
- Knowledge retrieval from vector store
- OpenAI service connectivity
![20251206172131](20251206172131.png)
Thread logs functionality to trace requests
![20251206171540](20251206171540.png)

This is another example where we are asking a relevant question with the knowledge provided (Microsoft annual report 2025). We get expected response with reference to uploaded content. 

![20251206172131](20251206172131.png)
### 4. Review Thread Logs
Use the built-in thread logs functionality to:
- Observe tool calls against the vector store
- Validate response generation
- Troubleshoot any issues with agent behavior
![20251206172202](20251206172202.png)

### Observability 
Comprehensive observability is essential for operating AI Foundry in production. Enable diagnostic logging across all components to gain visibility into traffic flows and request patterns.
#### Observability - > Firewall
Having logs enabled on the firewall allows us to observe traffic flows from AI Foundry delegated subnet. Below is the behaviour. We can see communication from Foundry subnet, towards Microsoft Container Registry and towards Azure Container Apps endpoints. 

Application Rule Logs below
![20251206144211](20251206144211.png)

Network Rule Logs below 
![20251206144048](20251206144048.png)
#### Observability -> VNET Flow Logs 
Below are logs from the VNET hosting agents. We can observe ACA Traffic reaching Microsoft managed endpoinst 
![20251206175211](20251206175211.png)
#### Observability -> AI Foundry Logs 
Foundry Logs also demonstrates requests from User towards Foundry Private Endpoints and other services reaching foundry service. 
![20251204061350](20251204061350.png)
#### Observability -> CosmosDB Logs 
We are also able to see request logs from CosmosDB Logs showcasing request from Agent delegated Subnet. 
![20251204061529](20251204061529.png)

## Conclusion
Deploying Microsoft Foundry using the Bring Your Own VNET pattern provides enterprise grade security and network control for AI agent workloads. This blog post has demonstrated a comprehensive approach to securing Microsoft Foundry deployments through three critical layers: individual resource network configuration, subnet  NSG rules, and centralised Azure Firewall policies.
