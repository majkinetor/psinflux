<#
.SYNOPSIS
    Send array of data points to InfluxDb
.PARAMETER Lines
    Array of strings that contain line protocol:

    <measurement>[,<tag_key>=<tag_value>[,<tag_key>=<tag_value>]] <field_key>=<field_value>[,<field_key>=<field_value>] [<timestamp>]

.PARAMETER Db
    Which database to use, by default $Env:INFLUX_DB

.PARAMETER RoundTripTime
    Time is passed in UTC roundtrip format https://msdn.microsoft.com/en-us/library/az4se3k1(v=vs.110).aspx#Roundtrip
    This format is specified with [DateTime]::UtcNow.ToString('o'). 
    Any supplied time argument will be converted using this format to nanosecond time since Unix Epoch Start.
.EXAMPLE
    Send-Data "cpu,host=$Env:COMPUTERNAME,user=$Env:USERNAME value=$(Get-Counter '\Processor(_Total)\% Processor Time' | % CounterSamples | % CookedValue)"

    Send current CPU load to InfluxDb. No time is used so local InfluxDB server time will be used

.EXAMPLE
    $time = [DateTime]::UtcNow.ToString('o')
    Send-Data "test1 value=1 $time", "test2 value=2 $time" -RoundTripTime

    Send 2 points using roundtrip data format.

.LINK
    https://docs.influxdata.com/influxdb/v1.2/write_protocols/line_protocol_reference/

#>

function Send-Data( [string[]]$Lines, [string]$Server=$Env:INFLUX_SERVER, [string]$Db=$Env:INFLUX_DB, [switch]$RoundTripTime ) {
    $unixEpochStart = new-object DateTime 1970,1,1,0,0,0,([DateTimeKind]::Utc)

    if ($RoundTripTime) {
        $metrics = @()
        foreach($line in $Lines) {
            $a = $line -split ' '
            if ($a.Length -ne 3) { continue }
            $a[-1] = [int64]((([datetime]$a[-1]) - $unixEpochStart).TotalMilliseconds*1000000)
            $metrics += $a -join ' '
        }
    } else { $metrics = $Lines }

    #$authheader = "Basic " + ([Convert]::ToBase64String([System.Text.encoding]::ASCII.GetBytes("<username>:<password>")))
    #-Headers @{Authorization=$authheader}
    #$uri=”http://<hostname>:8086/write?db=test&precision=s”
    iwr -UseBasicParsing -Method Post "$Server/write?db=$Db" -Body ($metrics -join "`n") | select StatusCode, StatusDescription, Headers
}

<#
.SYNOPSIS
    Send metrics to statsd server.
.DESCRIPTION
    Function sends metric data to statsd server.
.PARAMETER Lines
    Array of strings that contain statsd line protocol. If string is not enclosed in quotes (single or double), the pipe character needs to be escaped.
.PARAMETER Ip
    IP address of the statsd server.
.PARAMETER Port
    Port that statsd server is listening to, by default 8125
.EXAMPLE
    Send-Statsd "my_metric:123|g"
.EXAMPLE
    Send-Statsd "my_metric:123|g" -ip 127.0.0.1 -port 8125
.EXAMPLE
    Send-Statsd my_metric:321`|g -ip 10.0.0.10 -port 8180
.EXAMPLE
    Send-Statsd 'my_metric:321|g' -ip 10.0.0.10 -port 8180
.LINK
    https://www.influxdata.com/getting-started-with-sending-statsd-metrics-to-telegraf-influxdb/
    https://github.com/etsy/statsd/blob/master/docs/metric_types.md
#>
function Send-Statsd {

    param(
        [parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string[]] $Lines,

        [parameter(Mandatory=$true)]
        [string] $Ip,

        [int]    $Port = 8125
    )

    $ipAddress = [System.Net.IPAddress]::Parse($ip)

    $endPoint  = New-Object System.Net.IPEndPoint($ipAddress, $Port)
    $udpclient = New-Object System.Net.Sockets.UdpClient

    foreach ($line in $Lines) {
        $encodedData = [System.Text.Encoding]::ASCII.GetBytes($line)
        $bytesSent = $udpclient.Send($encodedData, $encodedData.Length, $endPoint)
    }

    $udpclient.Close()
}

<#
.SYNOPSIS
    Execute parsed InfluxDb query over HTTP API

.DESCRIPTION
    This is parsed query (results are converted to PowerShell objects,
    so it will be slow for very large number of values returned and should
    generally be used with LIMIT option. Use Send-RawQuery if you don't
    want any parsing.

    Use the following env variables to set influx environment:
        - INFLUX_SERVER     - influx server uri
        - INFLUX_DB         - influx db to use

.LINK
    https://docs.influxdata.com/influxdb/v1.2/guides/writing_data/
    https://docs.influxdata.com/influxdb/v1.2/guides/querying_data/
#>
function Send-Query() {
    if (!$args.Length) { Write-Warning 'No query specified'; return }

    $series = Send-RawQuery @args

    $res = @{}
    foreach ($s in $series) {
        $name = if ( $s.name ) { $s.name } else { 'no_name' }
        $r = @()
        $cols = $s.columns
        $range = 0..($cols.Count-1)
        foreach ($value in $s.values) {
            $props = [ordered] @{}
            $range | % { $props[$cols[$_]] = $value[$_] }
            $r += [PSCustomObject]$props
        }
        $res[$name] += $r
    }
    if ($res.Count -eq 1) {
         $name = if ( $series[0].name ) { $series[0].name } else { 'no_name' }
         return $res[$name]
    }
    $res
}
sal iq Send-Query


<#
.SYNOPSIS
    Execute raw InfluxDb query over HTTP API

#>
function Send-RawQuery() {
    if (!$args.Length) { Write-Warning 'No query specified'; return }
    $query = ($args | % { if ($_ -is [array]) { $_ -join ', ' } else { $_ }}) -join ' '
    $db = $Env:INFLUX_DB
    ir "$query&db=$db" | % results | % series
}
sal iqr Send-RawQuery

<#
.SYNOPSIS
    Execute query templates

.DESCRIPTION
    Query templates are contained in the templates.txt file and contains 2 sections: powershell code and query sentences.
    Sections are separated by '---' line. Comments are marked with #.

    User can define small Powershell helper scriptblocks and Powershell variables that serve to replace query placeholders,
    marked with $PLACEHOLDER. There are 2 specially named placeholder, those starting with SELECT_ or INPUT_ that are replaced
    with scriptblock invocations.

    The template uses fzf.exe as fuzzy finder so the query or argument can quickly be selected from the list.


.PARAMETER Selection
    Word that uniquelly describes one query to be executed on the start.
.PARAMETER FilePath
    Template file path to be added in adition to the default one. By default $Env:INFLUX_TEMPLATE.
.LINK
    https://chocolatey.org/packages/fzf
#>
function Invoke-Template([string]$Selection, [string]$FilePath=$Env:INFLUX_TEMPLATE) {

    function load_template($path) {
        if (!$path) { throw 'Empty template path' }
        if (!(Test-Path $path)) { Write-Warning "Invalid template path: $path"; sleep 2; return }
        $t = gc $path -Raw
        $c = if ($t -match '(?s)^.+(?=\n---\s*\n)') { $matches[0] }
        $l = $t -replace '(?s)^.+\n---\s*\n|(?<=\n)#.+?\n'
        return ($c + "`n"), ($l + "`n")
    }

    $paths = @("$PSScriptRoot\templates.txt")
    if ($FilePath) { $paths += $FilePath }
    $local:code = $lines = ''
    foreach ($path in $paths) { $c, $l = load_template $path; $code += $c; $lines += $l }

    iex $code

    if ($Selection) {
        $sel = $Selection -replace '.', '$0*'
        $query = $lines -split "`n" | ? { $_ -like "*$sel" }
        if ($query.Count -gt 1) { Write-Host "Error - more then 1 query returned:`n"; $query | Write-Host; return }
    } else {
        $query = $lines | fzf $Env:INFLUX_DB.ToUpper()
    }
    if (!$query) { Write-Host 'Aborted'; return }

    $query = $query -replace '\$(SELECT|INPUT)[^ ]+', '$(. $0)'
    $query = $query -replace '\s+#.+$'
    $equery = iex """$query"""

    Write-Host "QUERY:`n" "    iq $equery"
    iq $equery
}
sal itemplate invoke-template

function fzf{
    param(
        [string]$Prompt='Fuzzy find',
        [switch]$Edit
    )

    if (!(gcm fzf.exe)) { throw "To use templates, fzf.exe must be on the PATH, see https://chocolatey.org/packages/fzf" }

    if ($Prompt) { $p = "--prompt=""${Prompt}: """ }
    if ($Edit)   { $e = "--print-query"  }
    $script:LAST_SELECTION = $input | fzf.exe -i -m --reverse $e $p
    $script:LAST_SELECTION
}

function ir([string]$q) {
    if (!$Env:INFLUX_SERVER) {throw "Define `$Env:INFLUX_SERVER to use this module"}
    $r = "$Env:INFLUX_SERVER/query?q=$q"
    irm $r -UseBasicParsing
}

Write-Host

if (!$Env:INFLUX_SERVER) { Write-Warning "Environment variable `$Env:INFLUX_SERVER not defined" } else {
    Write-Host -NoNewLine -Foreground green 'SERVER'.PadRight(10)
    Write-Host $ENV:INFLUX_SERVER
}
if (!$Env:INFLUX_DB) { Write-Warning "Environment variable `$Env:INFLUX_DB not defined" } else {
    Write-Host -NoNewLine -Foreground green 'DB'.PadRight(10)
    Write-Host $ENV:INFLUX_DB "`n"
}


<#
.SYNOPSIS
    Convert Custom PSoObjects to Line Protocol
.DESCRIPTION
    Funtion to convert Custom PSoObjects to Line Protocol strings
.PARAMETER Object
    Is a PSOject with names an values
.PARAMETER hostname
    Adds the host=exampelserver to the Line Protocol string 
    Default it gets the localhostname
.PARAMETER TagSet
    Here you can specify your tags
    Exampel -TagSet "region=uswest"
    Exampel -TagSet "region=uswest,user=foo"
.PARAMETER TimeStamp   
    Here you can specify a TimeStamp in a [datetime] fromat
    Exampel -TimeStamp (Get-Date)
    Exampel -TimeStamp ($time)

.EXAMPLE
    ConvertTo-LineProtocoll -object $object -TagSet "station=11b" -timestamp (Get-Date)
.EXAMPLE
    ConvertTo-LineProtocoll -object $object -TagSet "unixsrv01" -timestamp $timedate
.LINK
https://docs.influxdata.com/influxdb/v1.3/write_protocols/line_protocol_reference/#syntax

#>

Function ConvertTo-LineProtocoll {
    Param(
        [Parameter(Mandatory = $true, HelpMessage = 'Custom PSObject')]
        [psobject]$Object,
        [Parameter(HelpMessage = 'hostname' )]
        [string]$hostname = $Env:COMPUTERNAME,
        [Parameter(HelpMessage = 'TagSet ex. "region=us-west"' )]
        [string]$TagSet,
        [parameter(HelpMessage = 'Timestamp ex (Get-Date)')]
        [datetime]$TimeStamp
    )
    begin {
        if ($TagSet) {
            $TagSet = ',' + $TagSet
        }
        if ($TimeStamp) {
            $Unixtime = [int64](($TimeStamp) - (get-date "1/1/1970")).TotalMilliseconds
            $Unixtime = " " + $Unixtime.ToString()
        }     
    }
    process {
        $object.PSObject.Properties | ForEach-Object {
            $name = $_.Name 
            $value = $_.value
            $row = "$name$TagSet,host=$hostname value=$value$Unixtime`r`n"
            $lines += $row
        }
        return $lines
    }

}

# Export-ModuleMebers
Export-ModuleMember -Function 'Send-Query', 'Send-RawQuery', 'Invoke-Template', 'Send-Data', 'Send-Statsd', 'ConvertTo-LineProtocoll' -Alias *
