$ServerInstance = ""
$csvExportFileName = "$(Get-Date -Format yyyyMMdd_HHmm)_$($ServerInstance)_UnusedIndexesDetails.csv"
$csvExportPath = ""
$exportCSV = $false

$query = "select name from sys.databases where database_id > 4 order by name"
$dbs = Invoke-Sqlcmd -ServerInstance $ServerInstance -TrustServerCertificate -Query $query
$unusedIndexes = @()
$dbs.name | % {
    $query = "
        SELECT DatabaseName = DB_NAME(),
            TableName = OBJECT_NAME(s.[object_id]),
            IndexName = i.name,
            [Index size (KB)] = SUM(sz.[used_page_count]) OVER(PARTITION BY (s.[object_id]), i.name) * 8,
            s.user_updates,
            s.system_updates
        FROM sys.dm_db_index_usage_stats s
            INNER JOIN sys.indexes i ON s.[object_id] = i.[object_id]
            AND s.index_id = i.index_id
            INNER JOIN sys.dm_db_partition_stats sz ON i.[object_id] = sz.[object_id]
            AND i.index_id = sz.index_id
        WHERE s.database_id = DB_ID()
            AND OBJECTPROPERTY(s.[object_id], 'IsMsShipped') = 0
            AND user_seeks = 0
            AND user_scans = 0
            AND user_lookups = 0
            AND i.name IS NOT NULL -- Ignore HEAP indexes.
            --AND user_updates > 10
        ORDER BY user_updates DESC"
    $unusedIndexes += Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $_ -TrustServerCertificate -Query $query -Verbose
}
$unusedIndexes | Format-Table -AutoSize
if ($exportCSV -eq $true) {
    $unusedIndexes | Export-Csv -Delimiter ';' -Path "$csvExportPath\$csvExportFileName"
}

$totalUnusedIndexSizeInMB = ($unusedIndexes | measure 'Index size (KB)' -sum).sum/1024

Write-Host "Total size of unused indexes' size:  $totalUnusedIndexSizeInMB MB"

$unusedIndexes | Group-Object -Property databasename | % {
    [PSCustomObject]@{
        DatabaseName = $_.Name
        UnusedIndexSizeMB = [int]($_.Group | measure 'Index size (KB)' -sum).sum
        Count = ($_.Group | measure).count
    }
} | Sort-Object UnusedIndexSizeMB -Descending
