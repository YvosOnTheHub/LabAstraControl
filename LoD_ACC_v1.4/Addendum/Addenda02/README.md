#########################################################################################
# Addenda 2: Upgrade Astra Control
#########################################################################################

This lab run Astra Control Center v23.07.  
Currently, Astra Control needs to be upgraded from one version to the next.  

You will find in this chapter procedures to:  
[1.](1_Upgrade_Trident_23.07_to_23.10) upgrade Trident from 23.07 to 23.10, and enable ACP  
[2.](2_Upgrade_ACC_23.07_to_23.10) upgrade ACC from 23.07.0 to 23.10.0  
[3.](3_Upgrade_Trident_23.10_to_24.02) upgrade Trident & ACP from 23.10 to 24.02  
[4.](4_Upgrade_ACC_23.10_to_24.02) upgrade ACC from 23.10.0 to 24.02.0  
[5.](5_Install_Connector_on_RKE2) install the AC Connector on RKE2  

Astra Control Center 23.10 introduced the following features:  
- B&R capability for _ontap-nas-economy_ workloads
- immutable backups  
- Astra Control Provisioner
- support for applications running with NVMe/TCP  
- and [more](https://docs.netapp.com/us-en/astra-control-center/release-notes/whats-new.html#7-november-2023-23-10-0)   

Astra Control Center 24.02 introduces the following fearures:  
- private registry is not required anymore  
- declarative resource management as tech preview  
read more [here](https://docs.netapp.com/us-en/astra-control-center/release-notes/whats-new.html#15-march-2023-24-02-0)  