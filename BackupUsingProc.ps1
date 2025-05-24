# ============================================
# PowerShell Script: SQL Server Backup Utility
# Dev Script By: Meshary Alali
# ============================================

# Temporarily bypass ExecutionPolicy for this process
#Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

# ========== Inputs ==========
$serverInstance = Read-Host "Enter Server Name (e.g. localhost or IP)"
$database = Read-Host "Enter Database Name"
$backupDir = Read-Host "Enter Backup Path (e.g. C:\SQLBackups)"

# Ensure path is valid
if (-not (Test-Path $backupDir)) {
    try {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    } catch {
        Write-Host "Failed to create or access directory: $backupDir" -ForegroundColor Red
        exit
    }
}

$useWindowsAuth = Read-Host "Use Windows Authentication? (Y/N)"
$useWindowsAuth = $useWindowsAuth.Trim().ToUpper()

# ========== Generate File Names ==========
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFileName = "${database}_Backup_$timestamp.bak"
$txtFileName = "BackupReport_${database}_$timestamp.txt"

$backupPath = Join-Path $backupDir $backupFileName
$txtPath = Join-Path $backupDir $txtFileName

# ========== Setup Connection ==========
try {
    if ($useWindowsAuth -eq "Y") {
        $connectionString = "Server=$serverInstance;Database=$database;Trusted_Connection=True;"
    } else {
        $credential = Get-Credential -Message "Enter SQL Server Login"
        $username = $credential.UserName
        $password = $credential.GetNetworkCredential().Password
        $connectionString = "Server=$serverInstance;Database=$database;User ID=$username;Password=$password;"
    }

    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $connection.Open()
} catch {
    Write-Host "Failed to connect to the database. Please check credentials or server name." -ForegroundColor Red
    exit
}

try {
    # ========== 1. Get DB Size Info (via SP) ==========
    $command = $connection.CreateCommand()
    $command.CommandType = [System.Data.CommandType]::StoredProcedure
    $command.CommandText = "dbo.GetDatabaseSizeReport"

    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
    $dataSet = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null
    $results = $dataSet.Tables[0]

    # ========== 2. Get SQL Server Info ==========
    $infoQuery = "SELECT SERVERPROPERTY('ProductVersion') AS ProductVersion, SERVERPROPERTY('Edition') AS Edition, SERVERPROPERTY('ProductLevel') AS ProductLevel;"
    $infoCommand = $connection.CreateCommand()
    $infoCommand.CommandText = $infoQuery

    $infoAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $infoCommand
    $infoDataSet = New-Object System.Data.DataSet
    $infoAdapter.Fill($infoDataSet) | Out-Null

    $infoRow = $infoDataSet.Tables[0].Rows[0]
    $productVersion = $infoRow.ProductVersion
    $edition = $infoRow.Edition
    $productLevel = $infoRow.ProductLevel

    # ========== 3. Backup Database ==========
    $escapedPath = $backupPath.Replace("\", "\\")
    $backupQuery = "BACKUP DATABASE [$database] TO DISK = N'$escapedPath' WITH INIT, FORMAT"
    $backupCmd = $connection.CreateCommand()
    $backupCmd.CommandText = $backupQuery
    $backupCmd.ExecuteNonQuery()

    # ========== 4. Verify Backup ==========
    $verifyQuery = "RESTORE VERIFYONLY FROM DISK = N'$escapedPath'"
    $verifyCmd = $connection.CreateCommand()
    $verifyCmd.CommandText = $verifyQuery

    try {
        $verifyCmd.ExecuteNonQuery() | Out-Null
        $verifyStatus = "Passed"
    } catch {
        $verifyStatus = "Failed: $($_.Exception.Message)"
    }

    # ========== 5. Create Report ==========
    $cleanedResults = $results | Select-Object Database_Name, Date_Report, Object_Name, Object_Type, Total_Rows, 'Size (MB)'
    $backupDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $dbSizeMB = ($cleanedResults | Where-Object { $_."Object_Type" -eq "DB Total" })."Size (MB)"
    $tableText = $cleanedResults | Format-Table -AutoSize | Out-String
    $backupSizeMB = [math]::Round(((Get-Item $backupPath).Length / 1MB), 2)
    $backupStatus = if (Test-Path $backupPath) { "Completed" } else { "Error" }

    $txtContent = @"
SQL Server Info:
 - Version       : $productVersion
 - Edition       : $edition
 - Product Level : $productLevel

--------------------------------------------
Database Objects:
$tableText

--------------------------------------------
Backup Info:
 - Backup Date   : $backupDate
 - Backup Size   : $backupSizeMB MB
 - Status        : $backupStatus
 - Verify Status : $verifyStatus

--------------------------------------------
Dev Script By Meshary Alali
--------------------------------------------
"@

    Set-Content -Path $txtPath -Value $txtContent -Encoding UTF8

    # ========== Final Message ==========
    Write-Host "✅ All Tasks Completed Successfully!" -ForegroundColor Green
    Write-Host "📄 Report Saved: $txtPath" -ForegroundColor Cyan
    Write-Host "💾 Backup Saved: $backupPath" -ForegroundColor Cyan
}
catch {
    Write-Host "❌ An error occurred:" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Yellow
}
finally {
    if ($connection.State -eq 'Open') {
        $connection.Close()
    }
}