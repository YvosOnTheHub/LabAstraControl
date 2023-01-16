#########################################################################################
# Astra Control Center Lab description
#########################################################################################

This lab is really complete & can help you test or demo most of ACC features:
- Snapshots
- Backup & Restore
- Clone
- DRP (Disaster Recovery Plan)

It hosts the following:
- 2 RKE clusters (_RKE1_ & _RKE2_) each one running Kubernetes v1.23 & composed of 5 nodes
- 2 ONTAP clusters running v9.11.1 (_cluster1_ & _cluster3_)
- one S3 bucket configured with ONTAP on _cluster3_
- Astra Trident v22.10
- Astra Control Center v22.11.0 (hosted on _RKE1_)  