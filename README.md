This template will deploy an Azure Data Factory linked to an Azure SQL Database and Azure Storage account. Additional resources are also deployed to support this infrastructure. All resources are deployed to the Australia East region.

Azure Bastion is also deployed. It is a costly resource for development environments at AU$0.25/hour. It is only deployed for installation of the Integration Runtime on the VM and can be removed after.

The cost of the solution is around **AU$0.45/hour**, however if Bastion and the VM are removed it drops to **AU$0.12/hour**. This includes:

* 5GB of Azure Storage
* 5GB of SQL storage
* 10 hours of Data Factory pipeline activity
* 10 hours of Data Factory data flow activity.