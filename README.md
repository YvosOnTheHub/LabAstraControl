# LabAstraControl

Astra Control is NetApp's Application-aware data protection and mobility solution for both on-prem & cloud environments.  
It is currently available in 2 fashions:
- _Astra Control Center_: self-managed software installed on one of your Kubernetes clusters  
- _Astra Control Service_: fully managed service, provided & maintained by NetApp  
The choice is not really about features, but rather more whether you want manage the solution yourself.  

Also, Astra Control relies on Astra Trident for persistent volumes as well as CSI Snapshots.  

The Lab on Demand currently has its third version of the Astra Control Center environment, available on https://labondemand.netapp.com/lab/sl10896.  
This repo has been designed to go further with what is already available & also provide you with complete demo scenarios.  

Scenarios  
---------  
[1.](LoD_ACC_v1.3/Scenarios/Scenario01) Configure the lab for iSCSI  
[2.](LoD_ACC_v1.3/Scenarios/Scenario02) Astra Control and logging   
[3.](LoD_ACC_v1.3/Scenarios/Scenario03) Pacman to the rescue !  
<!--
[4.](LoD_ACC_v1.3/Scenarios/Scenario04) Astra Control and LDAP    
5. Jenkins (_still in brain cells, work in progress_)
-->

Addendum
--------
[1.](LoD_ACC_v1.3/Addendum/Addenda01) How to use Astra Control's REST API  
[2.](LoD_ACC_v1.3/Addendum/Addenda02) Upgrade ACC to v23.04  
[3.](LoD_ACC_v1.3/Addendum/Addenda03) How to use the Astra Control Toolkit  