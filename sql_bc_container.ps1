docker run --storage-opt size=250G `
           -v "$tempDirectory\db\:C:\data\backup\" `
           -e "ACCEPT_EULA=Y" `
           -e "SA_PASSWORD=Password02!" `
           -p 1433:1433 `
           --name $sqlContainerName `
           -d your-custom-sql-server-image:v1.0
    
$sqlIp = docker container inspect --format '{{.NetworkSettings.Networks.nat.IPAddress }}' $sqlContainerName

Print -string "Copy $databaseName.bak file to container SQL Server root"
docker exec $sqlContainerName powershell "C:\copy-db.ps1"

Print -string "Run restore 'database file list only' in container SQL Server"
$tempSqlQueryFilelistonly = "RESTORE FILELISTONLY FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\BACKUP\" + $databaseName + ".bak';"
docker exec $sqlContainerName sqlcmd -S localhost `
            -U SA -P "Password02!" `
            -Q $tempSqlQueryFilelistonly 

Print -string "Run database restore"
$tempSqlQuerryRestore = "RESTORE DATABASE [" + $databaseName + "] FROM DISK = 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\BACKUP\" + $databaseName + ".bak' 
WITH MOVE 'Demo Database NAV (17-0)_Data' TO 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\" + $databaseName + "_Data.mdf', 
MOVE 'Demo Database NAV (17-0)_Log' TO 'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\DATA\" + $databaseName + "_Log.ldf',
RECOVERY, REPLACE, STATS = 10;"
docker exec $sqlContainerName sqlcmd `
            -S localhost -U SA -P "Password02!" `
            -Q $tempSqlQuerryRestore

$segments = "$PSScriptRoot".Split('\')
$rootFolder = "$($segments[0])\$($segments[1])"
$additionalParameters = @("--volume ""$($rootFolder):C:\Agent""", "-e locale=""$($myCoulture)""")

Print -string "Start BC container $mainContainerName"
New-BCContainer `
    -accept_eula `
    -containerName $mainContainerName `
    -imageName $mainContainerImage `
    -updateHosts `
    -memoryLimit 6G `
    -auth NavUserPassword `
    -isolation hyperv `
    -Credential $credential `
    -databaseServer $sqlIp `
    -databaseInstance '' `
    -licenseFile $licenceFile `
    -databaseName $databaseName `
    -additionalParameters $additionalParameters `
    -EnableTaskScheduler:$false `
    -databaseCredential $credential
