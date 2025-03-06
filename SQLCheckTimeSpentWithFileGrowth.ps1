function SQLCheckTimeSpentWithFileGrowth {
    <#
.SYNOPSIS
    Finds any database AutoGrow events in the Default Trace.

.DESCRIPTION
    This script was inspired by https://docs.dbatools.io/Find-DbaDbGrowthEvent
    It is used to measure the time spent with file growth, especially before and after using the SQLSetFileAutoGrowth.ps1.

.PARAMETER Servers
    A character string or SMO server object specifying the name of an instance of the Database Engine. For default instances, only specify the computer name: "MyComputer". For named instances, use the format "ComputerName\InstanceName".

.PARAMETER OutputFolder
    The Path parameter specifies the directory that the TimeSpentWithFileGrowth.csv file is saved at.

.EXAMPLE
    SQLCheckTimeSpentWithFileGrowth -servers 'Server1', 'Server2'

.EXAMPLE
    'Server1', 'Server2' | SQLCheckTimeSpentWithFileGrowth -OutputFolder "C:\WORK\TEMP\sql"

.EXAMPLE
    $instanceSelection = "server1\MSSQLSERVER", "server2"
    $selectedInstances = $instanceSelection | Out-GridView -PassThru | select
    SQLCheckTimeSpentWithFileGrowth -servers $selectedInstances -OutputFolder "C:\WORK\TEMP\sql" -Verbose

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
        [String[]]$OutputFolder
    )

    Begin {
        Write-Verbose "Importing dbatools module"
        Import-Module dbatools -ErrorAction SilentlyContinue -ErrorVariable ModuleError
        If ($ModuleError) {
            Write-Warning -Message "The specified module 'dbatools' was not loaded and it's required by this script to run"
            Break
        }
    } #begin
    Process {
        
        $AllResult = @()
        $servers | % {
            $server = $_

            $result = Find-DbaDbGrowthEvent -SqlInstance $server -UseLocalTime -EventType Growth
            if ($result) {
                $Last = $result | select -Last 1 -Property StartTime
                $First = $result | select -First 1 -Property StartTime
                $Diff = ($First.StartTime - $Last.StartTime)
                $sum = $result | measure duration -sum | select count, Sum
                Write-Verbose "On $server, File growth happened $($sum.Count) times, and that took $($sum.sum/1000) seconds / $($sum.sum/1000/60) minutes
Between $($Last.StartTime) - $($First.StartTime) in $($Diff | select days,hours,minutes)"

                $AllResult += [PSCustomObject]@{
                    ServerInstance = $server
                    From           = $Last.StartTime
                    To             = $First.StartTime
                    TotalDays      = $Diff.TotalDays
                    Count          = $sum.Count
                    Seconds        = $($sum.sum / 1000)
                    Minutes        = $($sum.sum / 1000 / 60)
                }
            }
        }
        if ($OutputFolder) {
            if (!(Test-Path "$OutputFolder")) { New-Item "$OutputFolder" -ItemType Directory }
            $AllResult | Export-Csv "$OutputFolder\$(Get-Date -Format yyyyMMdd-HHmm)_TimeSpentWithFileGrowth.csv" -Delimiter ';'
        }
        else {
            $AllResult | ft
        }
    } #process
}
