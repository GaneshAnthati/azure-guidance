ECHO OFF
SETLOCAL

IF "%~1"=="" (
    ECHO Usage: %0 subscription-id
    EXIT /B
    )

:: Set up variables to build out the naming conventions for deploying
:: the cluster

SET LOCATION=eastus2
SET APP_NAME=app1
SET ENVIRONMENT=dev
SET USERNAME=testuser
SET PASSWORD=AweS0me@PW

:: Explicitly set the subscription to avoid confusion as to which subscription
:: is active/default
SET SUBSCRIPTION=%1

:: Set up the names of things using recommended conventions
SET RESOURCE_GROUP=%APP_NAME%-%ENVIRONMENT%-rg
SET VM_NAME=%APP_NAME%-vm0

SET IP_NAME=%APP_NAME%-pip
SET NIC_NAME=%VM_NAME%-0nic
SET NSG_NAME=%APP_NAME%-nsg
SET SUBNET_NAME=%APP_NAME%-subnet
SET VNET_NAME=%APP_NAME%-vnet
SET VHD_STORAGE=%VM_NAME:-=%st0
SET DIAGNOSTICS_STORAGE=%VM_NAME:-=%diag

:: For Windows, use the following command to get the list of URN's:
:: azure vm image list %LOCATION% MicrosoftWindowsServer WindowsServer 2012-R2-Datacenter
SET WINDOWS_BASE_IMAGE=MicrosoftWindowsServer:WindowsServer:2012-R2-Datacenter:4.0.20160126

:: For a list of VM sizes see...
SET VM_SIZE=Standard_DS1

:: Set up the postfix variables attached to most CLI commands
SET POSTFIX=--resource-group %RESOURCE_GROUP% --location %LOCATION% --subscription %SUBSCRIPTION%

call azure config mode arm

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Create resources

:: Create the enclosing resource group
call azure group create --name %RESOURCE_GROUP% --location %LOCATION%

:: Create the VNet
call azure network vnet create --address-prefixes 172.17.0.0/16 --name %VNET_NAME% %POSTFIX%

:: Create the subnet
call azure network vnet subnet create --vnet-name %VNET_NAME% --address-prefix 172.17.0.0/24 --name %SUBNET_NAME% --resource-group %RESOURCE_GROUP% --subscription %SUBSCRIPTION%

:: Create the public IP address (dynamic)
call azure network public-ip create --name %IP_NAME% %POSTFIX%

:: Create the network security group
call azure network nsg create --name %NSG_NAME% %POSTFIX%

:: Create the NIC
call azure network nic create --network-security-group-name %NSG_NAME% --public-ip-name %IP_NAME% --subnet-name %SUBNET_NAME% --subnet-vnet-name %VNET_NAME%  --name %NIC_NAME% %POSTFIX%

:: Create the storage account for the OS VHD
call azure storage account create --type PLRS %POSTFIX% %VHD_STORAGE%

:: Create the storage account for diagnostics logs
call azure storage account create --type LRS %POSTFIX% %DIAGNOSTICS_STORAGE%

call azure vm create --os-type Windows --image-urn %WINDOWS_BASE_IMAGE% --vm-size %VM_SIZE%   --vnet-subnet-name %SUBNET_NAME% --nic-name %NIC_NAME% --vnet-name %VNET_NAME% --storage-account-name %VHD_STORAGE% --os-disk-vhd "%VM_NAME%-osdisk.vhd" --admin-username "%USERNAME%" --admin-password "%PASSWORD%" --boot-diagnostics-storage-uri "https://%DIAGNOSTICS_STORAGE%.blob.core.windows.net/" --name %VM_NAME% %POSTFIX%

:: Attach data disk
call azure vm disk attach-new -g %RESOURCE_GROUP% --vm-name %VM_NAME% --size-in-gb 128 --vhd-name data1.vhd --storage-account-name %VHD_STORAGE%

:: Allow RDP
call azure network nsg rule create -g %RESOURCE_GROUP% --nsg-name %NSG_NAME% --direction Inbound --protocol Tcp --destination-port-range 3389 --source-port-range * --priority 100 --access Allow RDPAllow
