#########################################################################################
# Addenda 1: How to use Astra Control's REST APIs
#########################################################################################

Astra Control's GUI is vry useful to visualise all the tasks you can perform with this application management solution.  
All these tasks can also be achieved with REST APIs in order to automate your processes.  

For instance, one could include those API in an existing CI/CD pipeline to clone a stateful application in a consistant way !  

To use Astra Control's API, you first need to generate a token. Let's review how to do this:

## A. Let's first navigate to the Administrator page
<p align="center"><img src="Images/1_API_Access.png" width="1024"></p>

## B. You can find here the _Account ID_ which is also required in all API calls
<p align="center"><img src="Images/2_Account_ID.png" width="512"></p>

## C. Finally, by clicking on the _Generate new API token_ button, you will be able to retrieve the precious token
<p align="center"><img src="Images/3_API_Token.png" width="512"></p>

## D. Let's give it a try !

In my case, I have the following values for the Account ID & the token:  
- Account ID: 6912cacd-a03a-4f8f-85cb-713ef5253eff
- API Token: 9OPB9UnhrLsnWzXr7n03IbXzi6gVOWE-P2lrhw09hBo=

Let's run a command to retrieve the current ONTAP systems configured to run with ACC:
```bash
$ curl -X 'GET' 'https://astra.demo.netapp.com/accounts/6912cacd-a03a-4f8f-85cb-713ef5253eff/topology/v1/storageBackends' \
  -H 'accept: application/json' \
  -H 'Authorization: Bearer 9OPB9UnhrLsnWzXr7n03IbXzi6gVOWE-P2lrhw09hBo='

{"items":[{"backendCredentialsName":"192.168.0.101","backendName":"cluster1","backendType":"ontap","backendVersion":"9.11.1","configVersion":"Not applicable","healthState":"normal","healthStateUnready":[],"id":"a874e182-d4ef-4d22-97fd-506c2d31d3e6","location":"Not applicable","metadata":{"labels":null,"creationTimestamp":"2022-04-02T00:51:16Z","modificationTimestamp":"2023-01-16T10:20:51Z","createdBy":"15c83a9d-f109-4ab1-b831-5f0446235de9"},"ontap":{"backendManagementIP":"192.168.0.101","managementIPs":["192.168.0.101","192.168.0.111","192.168.0.112"]},"protectionPolicy":"Not applicable","protectionStateUnready":null,"region":"Not applicable","state":"running","stateUnready":[],"managedState":"managed","managedStateUnready":[],"tridentBackendUUID":["9604cbd3-3dee-4cc7-aa02-9ddf07f008d8"],"type":"application/astra-storageBackend","version":"1.1","zone":"Not applicable"},{"backendCredentialsName":"192.168.0.103","backendName":"cluster3","backendType":"ontap","backendVersion":"9.11.1","configVersion":"Not applicable","healthState":"normal","healthStateUnready":[],"id":"5fb8d84b-a35a-4324-a872-89d0fe810be3","location":"Not applicable","metadata":{"labels":[],"creationTimestamp":"2022-10-22T21:48:30Z","modificationTimestamp":"2023-01-16T10:20:51Z","createdBy":"15c83a9d-f109-4ab1-b831-5f0446235de9"},"ontap":{"backendManagementIP":"192.168.0.103","managementIPs":["192.168.0.103","192.168.0.115"]},"protectionPolicy":"Not applicable","protectionState":"unknown","protectionStateUnready":[],"region":"Not applicable","state":"running","stateUnready":[],"managedState":"managed","managedStateUnready":[],"tridentBackendUUID":["014ca078-eb62-48d2-8af6-00a34b828e13"],"type":"application/astra-storageBackend","version":"1.1","zone":"Not applicable"}]}
```

Pretty easy, right?  
A tool such as _jq_ (JSON Parser) becomes quite useful when working with API results in order to get the information you need.