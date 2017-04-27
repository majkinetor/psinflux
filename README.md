# PSInflux

This Powershell module uses Influx DB [HTTP API](https://docs.influxdata.com/influxdb/v1.2/guides/querying_data) to query and send data.

## How to use

Set the following environment variables or put them in $PROFILE:

```powershell
$ENV:INFLUX_SERVER = "http://influxdb.server.com:8086"
$ENV:INFLUX_DB     = "mydb"
```

Load with `import-module psinflux`. You can use normal PowerShell commands to get help:

* List of functions: `gcm -Module psinflux`
* Help for function: `man iq`

### Query

Use `iq` (alias for `Send-Query`) to query the database:

```
iq select value,tag from measure limit 20
```

For convenience, you don't have to (generally) put a query in PowerShell string.

**NOTE**: `iq` (influx query) function parses returned data into PowerShell objects which can be slow for large number of points. Use `iqr` (raw query) to get large collections.

Use `itemplate` (alias for `Invoke-Template`) to send predefined queries. Predefined queries can be added by the user and can contain PowerShell placeholders for getting the user input, for example metric or database name. Integrated templates use [fzf](https://chocolatey.org/packages/fzf) fuzzy finder as input selector.

### Writing data

To write data points to the database use `Send-Data` function:

```powershell
$cpu_load = Get-Counter '\Processor(_Total)\% Processor Time' | % CounterSamples | % CookedValue
Send-Data "cpu,host=$Env:COMPUTERNAME,user=$Env:USERNAME value=$cpu_load"
```

You can use `[DateTime]::UtcNow.ToString('o')` to send date time instead of nanoseconds until Unix epoch. If you do that, pass parameter `$UseRoundTripTime` to make function automatically convert time points to correct format.

You can also send an array of strings:

```powershell
$time = [DateTime]::UtcNow.ToString('o')
Send-Data "test1 value=1 $time", "test2 value=2 $time" -RoundTripTime
```



