# LabAstraControl

Astra Control is NetApp's Application-aware data protection and mobility solution for both on-prem & cloud environments.  
It is currently available in 2 fashions:
- _Astra Control Center_: self-managed software installed on one of your Kubernetes clusters  
- _Astra Control Service_: fully managed service, provided & maintained by NetApp  
The choice is not really about features, but rather more whether you want manage the solution yourself.  

Also, Astra Control relies on Astra Trident & Astra Control Provisioner for persistent volumes as well as CSI Snapshots.  

The Lab on Demand currently has its fourth version of the Astra Control Center environment, available on https://labondemand.netapp.com/node/acc.  
This repo has been designed to go further with what is already available & also provide you with complete demo scenarios for both ACC & ACP.    

Scenarios for Astra Control Center
----------------------------------  
[1.](LoD_ACC_v1.4/Scenarios-ACC/Scenario01) Astra Control and logging  
[2.](LoD_ACC_v1.4/Scenarios-ACC/Scenario02) Deploying more wordpress apps to test all possible storage classes  
[3.](LoD_ACC_v1.4/Scenarios-ACC/Scenario03) Pacman to the rescue !  
[4.](LoD_ACC_v1.4/Scenarios-ACC/Scenario04) Protect your app with the Astra toolkit  
[5.](LoD_ACC_v1.4/Scenarios-ACC/Scenario05) Hook me up before you go-go!  
[6.](LoD_ACC_v1.4/Scenarios-ACC/Scenario06) Protect your app with the Astra Connector manually  
<!--[7.](LoD_ACC_v1.4/Scenarios-ACC/Scenario07) Protect your app with the Astra Connector with GitOps methodologies  -->
<!--[7.](LoD_ACC_v1.4/Scenarios-ACC/Scenario07) Switching storage class  -->

Scenarios for Astra Control Provisioner
----------------------------------------  
[1.](LoD_ACC_v1.4/Scenarios-ACP/Scenario01) In-Place Snapshot Restore  
[2.](LoD_ACC_v1.4/Scenarios-ACP/Scenario02) Snapshots & ONTAP-NAS-ECONOMY  

Addendum
--------
[1.](LoD_ACC_v1.4/Addendum/Addenda01) How to use Astra Control's REST API  
[2.](LoD_ACC_v1.4/Addendum/Addenda02) Upgrade Astra  
[3.](LoD_ACC_v1.4/Addendum/Addenda03) Configure the lab for iSCSI  
[4.](LoD_ACC_v1.4/Addendum/Addenda04) Complete the lab for NFS  
[5.](LoD_ACC_v1.4/Addendum/Addenda05) How to use the Astra Control Toolkit  
[6.](LoD_ACC_v1.4/Addendum/Addenda06) Container images management  
[7.](LoD_ACC_v1.4/Addendum/Addenda07) Install extra tools  