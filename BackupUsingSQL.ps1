# ExecutionPolicy
# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# 1. User Input
$serverInstance   = Read-Host "Enter Server Name (e.g., localhost)"
$database         = Read-Host "Enter Database Name"
$backupDir        = Read-Host "Enter Backup Path"
$useWindowsAuth   = Read-Host "Use Windows Authentication? (Y/N)"
$useWindowsAuth   = $useWindowsAuth.Trim().ToUpper()

# 2. File Names
$timestamp        = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFileName   = "${database}_Backup_$timestamp.bak"
$txtFileName      = "LogFileBackup_${database}_$timestamp.txt"
$backupPath       = Join-Path $backupDir $backupFileName
$txtPath          = Join-Path $backupDir $txtFileName

# 3. Create directory if not exists
if (-not (Test-Path $backupDir)) {
    try {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    } catch {
        Write-Host " Failed to create directory $backupDir. Check permissions." -ForegroundColor Red
        return
    }
}

# 4. SQL Report Query
$query = @"
WITH AllocationSize AS (
    SELECT container_id, SUM(total_pages) AS total_pages
    FROM sys.allocation_units
    GROUP BY container_id
),
TableSizes AS (
    SELECT t.name AS ObjectName, 'Table' AS ObjectType, SUM(p.rows) AS TotalRows,
           SUM(a.total_pages) * 8.0 / 1024 AS ObjectSizeMB
    FROM sys.tables t
    INNER JOIN sys.partitions p ON t.object_id = p.object_id AND p.index_id IN (0,1)
    INNER JOIN AllocationSize a ON p.partition_id = a.container_id
    GROUP BY t.name
),
ViewSizes AS (
    SELECT v.name AS ObjectName, 'View' AS ObjectType, NULL AS TotalRows, 0.0 AS ObjectSizeMB
    FROM sys.views v
    INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE s.name NOT IN ('sys', 'INFORMATION_SCHEMA')
),
CombinedObjects AS (
    SELECT *, 1 AS SortOrder FROM TableSizes
    UNION ALL
    SELECT *, 2 AS SortOrder FROM ViewSizes
),
DatabaseSize AS (
    SELECT SUM(size) * 8.0 / 1024 AS TotalDBSizeMB
    FROM sys.master_files WHERE DB_NAME(database_id) = DB_NAME()
),
TotalObjectSize AS (
    SELECT N'--- Size Objects ---' AS ObjectName, 'Total' AS ObjectType, NULL AS TotalRows,
           SUM(ObjectSizeMB) AS ObjectSizeMB, 3 AS SortOrder FROM CombinedObjects
),
DBSizeRow AS (
    SELECT N'--- DB All Size ---' AS ObjectName, 'DB Total' AS ObjectType, NULL AS TotalRows,
           TotalDBSizeMB AS ObjectSizeMB, 4 AS SortOrder FROM DatabaseSize
)
SELECT DB_NAME() AS Database_Name, CONVERT(VARCHAR, GETDATE(), 120) AS Date_Report,
       ObjectName, ObjectType, ISNULL(CAST(TotalRows AS VARCHAR), N'--') AS Total_Rows,
       CAST(ObjectSizeMB AS DECIMAL(10,2)) AS [Size (MB)]
FROM (
    SELECT * FROM CombinedObjects
    UNION ALL
    SELECT * FROM TotalObjectSize
    UNION ALL
    SELECT * FROM DBSizeRow
) AS FinalResult
ORDER BY SortOrder, [Size (MB)] DESC;
"@

try {
    # 5. Prepare connection
    if ($useWindowsAuth -eq "Y") {
        $connectionString = "Server=$serverInstance;Database=$database;Trusted_Connection=True;"
    } else {
        $credential = Get-Credential -Message "Enter SQL Login"
        $username   = $credential.UserName
        $password   = $credential.GetNetworkCredential().Password
        $connectionString = "Server=$serverInstance;Database=$database;User ID=$username;Password=$password;"
    }

    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $connection.Open()

    # 6. Run report query
    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
    $dataSet = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null
    $results = $dataSet.Tables[0]

    # 7. Get server info
    $infoCommand = $connection.CreateCommand()
    $infoCommand.CommandText = "SELECT SERVERPROPERTY('ProductVersion') AS ProductVersion, SERVERPROPERTY('Edition') AS Edition, SERVERPROPERTY('ProductLevel') AS ProductLevel;"
    $infoAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $infoCommand
    $infoSet = New-Object System.Data.DataSet
    $infoAdapter.Fill($infoSet) | Out-Null
    $infoRow = $infoSet.Tables[0].Rows[0]

    # 8. Backup database
    $escapedPath = $backupPath.Replace("\", "\\")
    $backupQuery = "BACKUP DATABASE [$database] TO DISK = N'$escapedPath' WITH INIT, FORMAT"
    $backupCmd = $connection.CreateCommand()
    $backupCmd.CommandText = $backupQuery
    $backupCmd.ExecuteNonQuery()

    # 9. Verify backup
    $verifyQuery = "RESTORE VERIFYONLY FROM DISK = N'$escapedPath'"
    $verifyCmd = $connection.CreateCommand()
    $verifyCmd.CommandText = $verifyQuery
    try {
        $verifyCmd.ExecuteNonQuery() | Out-Null
        $verifyStatus = "Passed"
    } catch {
        $verifyStatus = "Failed: $($_.Exception.Message)"
    }

    $connection.Close()

    # 10. Create report
    $cleanedResults = $results | Select-Object Database_Name, Date_Report, ObjectName, ObjectType, Total_Rows, 'Size (MB)'
    $backupDate     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $dbSizeMB       = ($cleanedResults | Where-Object { $_.ObjectType -eq "DB Total" })."Size (MB)"
    if (-not $dbSizeMB) { $dbSizeMB = "Unknown" }
    $tableText      = $cleanedResults | Format-Table -AutoSize | Out-String
    $backupSizeMB   = [math]::Round(((Get-Item $backupPath).Length / 1MB), 2)
    $backupStatus   = if (Test-Path $backupPath) { "Completed" } else { "Error" }

    $txtContent = @"
SQL Server Info:
 - Version        : $($infoRow.ProductVersion)
 - Edition        : $($infoRow.Edition)
 - Product Level  : $($infoRow.ProductLevel)

--------------------------------------------
Objects Include:
$tableText

--------------------------------------------
Backup Info:
 - Backup Date    : $backupDate
 - Backup Size    : $backupSizeMB MB
 - Status         : $backupStatus
 - Verify Status  : $verifyStatus

--------------------------------------------
Dev Script By Meshary alali (:
--------------------------------------------
"@

    Set-Content -Path $txtPath -Value $txtContent -Encoding UTF8

    # 11. Done message
    Write-Host "`n=== Backup Summary ===" -ForegroundColor Green
    Write-Host " Backup File  : $backupPath" -ForegroundColor Cyan
    Write-Host " Log File     : $txtPath" -ForegroundColor Cyan

}
catch {
    Write-Host "`n Error occurred:" -ForegroundColor Red
    Write-Host "$($_.Exception.Message)" -ForegroundColor Yellow
}
