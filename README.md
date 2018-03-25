# quickstart-sios-datakeeper
## SIOS DataKeeper Cluster Edition on AWS

This Quick Start sets up an AWS architecture for SIOS DataKeeper Cluster Edition and deploys it into your AWS account in a few easy steps.

SIOS DataKeeper Cluster Edition is a highly optimized, host-based replication solution that helps configure and manage high-availability SQL Server clusters on the cloud, and integrates seamlessly with Windows Server Failover Clustering (WSFC). WSFC features, such as cross-subnet failover and tunable heartbeat parameters, make it possible for administrators to deploy geographically dispersed clusters. SIOS DataKeeper provides the data replication mechanism that extends WSFC, and enables administrators to take advantage of these advanced features to support high availability and disaster recovery configurations without the need for shared storage.

This Quick Start uses AWS CloudFormation templates to deploy SIOS DataKeeper Cluster Edition into a virtual private cloud (VPC) in a single AWS Region, across two Availability Zones. You can build a new VPC for SIOS DataKeeper, or deploy the software into your existing VPC.

![Quick Start architecture for SIOS DataKeeper on AWS](https://d0.awsstatic.com/partner-network/QuickStart/datasheets/sios-datakeeper-on-aws-architecture.png)

For architectural details, best practices, step-by-step instructions, and customization options, see the [deployment guide](https://fwd.aws/RaPKr)
