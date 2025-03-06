function SQLSetAutoGrowth {
    <#
.SYNOPSIS
    This script automatically sets data file growth to 256MB,128MB,64MB increments and log file growth to 128MB,64MB increments based on current sizes on all user databases on the specified servers. No max file size specified for either file.

.DESCRIPTION
    This script was inspired by https://www.brentozar.com/blitz/blitz-result-percent-growth-use/
    It automatically sets data file growth to 256MB,128MB,64MB increments and log file growth to 128MB,64MB increments based on current sizes on all user databases on the specified servers. No max file size specified for either file.
    If the autogrowth is set to percent growth, it overwrites it with MB.
    In both cases, the script creates before/after csv's in the specified folder. If it is not set, the default path will be used.

.PARAMETER Servers
    A character string or SMO server object specifying the name of an instance of the Database Engine. For default instances, only specify the computer name: "MyComputer". For named instances, use the format "ComputerName\InstanceName".

.EXAMPLE
    SQLSetAutoGrowth -servers 'Server1', 'Server2'

.EXAMPLE
    'Server1', 'Server2' | SQLSetAutoGrowth -resultOutputFolder "C:\WORK\TEMP\sql"

.EXAMPLE
    $instanceSelection = "server1\MSSQLSERVER", "server2"
    $selectedInstances = $instanceSelection | Out-GridView -PassThru | select
    SQLSetAutoGrowth -servers $selectedInstances -resultOutputFolder "C:\WORK\TEMP\sql" -Verbose

.INPUTS
    String

.OUTPUTS
    CSV

.NOTES
    Author:  Robert Zachar
    Website: https://github.com/R0brZ
#>
    param (
        [Parameter(Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [String[]]$servers,
        $resultOutputFolder = "C:\WORK\TEMP\sql"
    )

    Begin {
        Write-Verbose "Importing sqlserver module"
        Import-Module sqlserver -ErrorAction SilentlyContinue -ErrorVariable ModuleError
        If ($ModuleError) {
            Write-Warning -Message "The specified module 'sqlserver' was not loaded and it's required by this script to run"
            Break
        }
    } #begin
    Process {
        $servers | % {
            if (Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query "SELECT 1") {
                $server = $_
                Write-Verbose "Test connection to $server was OK"
                if (!(Test-Path "$resultOutputFolder\$($server.replace('\','_'))")) { New-Item "$resultOutputFolder\$($server.replace('\','_'))" -ItemType Directory }

                $MBQuery = "
SELECT d.name as database_name,
    mf.name as file_name,
    mf.type_desc as file_type,
    mf.growth as current_percent_growth,
	mf.is_percent_growth
	--,mf.growth
	,mf.growth * 8 / 1024 as [Autogrowth(MB)]
	,size * 8 / 1024 as [CurrentSize(MB)]
	--,*
FROM sys.master_files mf (NOLOCK)
JOIN sys.databases d (NOLOCK) on mf.database_id=d.database_id
WHERE is_percent_growth=0
AND mf.database_id > 4
--AND (CONVERT(BIGINT, mf.growth) * 8 / 1024) < 50
--AND (size * 8 / 1024) > 128
order by database_name
"
                Write-Verbose "Collecting information about current autoGrowth settings where is_percent_growth=0"
                $MBResultBefore = Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query $MBQuery
                $MBResultBefore | ft
                $MBResultBefore | export-Csv "$resultOutputFolder\$($server.replace('\','_'))\$($server.replace('\','_'))_$(Get-Date -Format yyyyMMdd-HHmm)_AutoGrowthSizeMB_before.csv" -Delimiter ';' -Force

                $MBResultBefore | % {
                    switch ($_) {
                        { $_.file_type -eq 'ROWS' } {
                            switch ($_) {
                                { $_.'Autogrowth(MB)' -lt 128 -and $_.'Currentsize(MB)' -ge 128 } {
                                    $AlterDBQuery = "ALTER DATABASE [$($_.database_name)] MODIFY FILE (NAME='$($_.file_name)', FILEGROWTH = 256MB);
GO"
                                    Write-Verbose $AlterDBQuery
                                    Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query $AlterDBQuery
                                }
                                { $_.'Autogrowth(MB)' -lt 128 -and $_.'Currentsize(MB)' -in 64..127 } {
                                    $AlterDBQuery = "ALTER DATABASE [$($_.database_name)] MODIFY FILE (NAME='$($_.file_name)', FILEGROWTH = 128MB);
GO"
                                    Write-Verbose $AlterDBQuery
                                    Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query $AlterDBQuery
                                }
                                { $_.'Autogrowth(MB)' -lt 64 -and $_.'Currentsize(MB)' -lt 64 } {
                                    $AlterDBQuery = "ALTER DATABASE [$($_.database_name)] MODIFY FILE (NAME='$($_.file_name)', FILEGROWTH = 64MB);
GO"
                                    Write-Verbose $AlterDBQuery
                                    Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query $AlterDBQuery
                                }
                            }
                        }
                        { $_.file_type -eq 'LOG' } {
                            switch ($_) {
                                { $_.'Autogrowth(MB)' -lt 128 -and $_.'Currentsize(MB)' -ge 128 } {
                                    $AlterDBQuery = "ALTER DATABASE [$($_.database_name)] MODIFY FILE (NAME='$($_.file_name)', FILEGROWTH = 128MB);
GO"
                                    Write-Verbose $AlterDBQuery
                                    Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query $AlterDBQuery
                                }
                                { $_.'Autogrowth(MB)' -lt 128 -and $_.'Currentsize(MB)' -lt 128 } {
                                    $AlterDBQuery = "ALTER DATABASE [$($_.database_name)] MODIFY FILE (NAME='$($_.file_name)', FILEGROWTH = 64MB);
GO"
                                    Write-Verbose $AlterDBQuery
                                    Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query $AlterDBQuery
                                }
                            }
                        }
                    }
                }


                $MBResultAfter = Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query $MBQuery
                $MBResultAfter | ft
                $MBResultAfter | export-Csv "$resultOutputFolder\$($server.replace('\','_'))\$($server.replace('\','_'))_$(Get-Date -Format yyyyMMdd-HHmm)_AutoGrowthSizeMB_After.csv" -Delimiter ';' -Force



                $PercentQuery = "
SELECT d.name as database_name,
    mf.name as file_name,
    mf.type_desc as file_type,
    mf.growth as current_percent_growth,
	mf.is_percent_growth
	--,mf.growth
	,mf.growth * 8 / 1024 as [Autogrowth(MB)]
	,size * 8 / 1024 as [CurrentSize(MB)]
	--,*
FROM sys.master_files mf (NOLOCK)
JOIN sys.databases d (NOLOCK) on mf.database_id=d.database_id
WHERE is_percent_growth=1
AND mf.database_id > 4
order by database_name
"

                Write-Verbose "Collecting information about current autoGrowth settings where is_percent_growth=1"
                $PercentResultBefore = Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query $PercentQuery
                $PercentResultBefore | ft
                $PercentResultBefore | export-Csv "$resultOutputFolder\$($server.replace('\','_'))\$($server.replace('\','_'))_$(Get-Date -Format yyyyMMdd-HHmm)_AutoGrowthSizePercent_before.csv" -Delimiter ';' -Force

                $PercentResultBefore | % {
                    switch ($_) {
                        { $_.file_type -eq 'ROWS' } {
                            switch ($_) {
                                { $_.'Autogrowth(MB)' -lt 128 -and $_.'Currentsize(MB)' -ge 128 } {
                                    $AlterDBQuery = "ALTER DATABASE [$($_.database_name)] MODIFY FILE (NAME='$($_.file_name)', FILEGROWTH = 256MB);
GO"
                                    Write-Verbose $AlterDBQuery
                                    Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query $AlterDBQuery
                                }
                                { $_.'Autogrowth(MB)' -lt 128 -and $_.'Currentsize(MB)' -in 64..127 } {
                                    $AlterDBQuery = "ALTER DATABASE [$($_.database_name)] MODIFY FILE (NAME='$($_.file_name)', FILEGROWTH = 128MB);
GO"
                                    Write-Verbose $AlterDBQuery
                                    Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query $AlterDBQuery
                                }
                                { $_.'Autogrowth(MB)' -lt 64 -and $_.'Currentsize(MB)' -lt 64 } {
                                    $AlterDBQuery = "ALTER DATABASE [$($_.database_name)] MODIFY FILE (NAME='$($_.file_name)', FILEGROWTH = 64MB);
GO"
                                    Write-Verbose $AlterDBQuery
                                    Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query $AlterDBQuery
                                }
                            }
                        }
                        { $_.file_type -eq 'LOG' } {
                            switch ($_) {
                                { $_.'Autogrowth(MB)' -lt 128 -and $_.'Currentsize(MB)' -ge 128 } {
                                    $AlterDBQuery = "ALTER DATABASE [$($_.database_name)] MODIFY FILE (NAME='$($_.file_name)', FILEGROWTH = 128MB);
GO"
                                    Write-Verbose $AlterDBQuery
                                    Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query $AlterDBQuery
                                }
                                { $_.'Autogrowth(MB)' -lt 128 -and $_.'Currentsize(MB)' -lt 128 } {
                                    $AlterDBQuery = "ALTER DATABASE [$($_.database_name)] MODIFY FILE (NAME='$($_.file_name)', FILEGROWTH = 64MB);
GO"
                                    Write-Verbose $AlterDBQuery
                                    Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query $AlterDBQuery
                                }
                            }
                        }
                    }
                }

                $PercentResultAfter = @()
                $PercentResultBefore | % {
                    $PercentQueryAfter = "
SELECT d.name as database_name,
    mf.name as file_name,
    mf.type_desc as file_type,
    mf.growth as current_percent_growth,
	mf.is_percent_growth
	--,mf.growth
	,mf.growth * 8 / 1024 as [Autogrowth(MB)]
	,size * 8 / 1024 as [CurrentSize(MB)]
	--,*
FROM sys.master_files mf (NOLOCK)
JOIN sys.databases d (NOLOCK) on mf.database_id=d.database_id
WHERE mf.database_id > 4
AND d.name = '$($_.database_name)'
AND mf.name = '$($_.file_name)'
order by database_name
"
                    $PercentResultAfter += Invoke-Sqlcmd -TrustServerCertificate -ServerInstance $server -Query $PercentQueryAfter
                }
                $PercentResultAfter | ft
                $PercentResultAfter | export-Csv "$resultOutputFolder\$($server.replace('\','_'))\$($server.replace('\','_'))_$(Get-Date -Format yyyyMMdd-HHmm)_AutoGrowthSizePercent_After.csv" -Delimiter ';' -Force
            } #ifConnectAttemptOK
        } #servers
    } #process
}
