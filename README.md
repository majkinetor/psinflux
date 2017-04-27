# PSInflux

This Powershell module uses Influx DB [HTTP API](https://docs.influxdata.com/influxdb/v1.2/guides/querying_data) to query and send data.

## How to use

Set the following environment variables or put them in $PROFILE:

```powershell
$ENV:INFLUX_SERVER = "http://influxdb.server.com:8086"
$ENV:INFLUX_DB     = "mydb"
```

Load with `import-module psinflux`.


### Query

Use `iq` (alias for `Send-Query`) to query the database:

```
iq select value,tag from measure limit 20
```

For convenience, you don't have to (generally) put a query in PowerShell string.

**NOTE**: `iq` (influx query) function parses returned data into PowerShell objects which can be slow for large number of points. Use `iqr` (raw query) ton large collections instead.

Use `itemplate` (alias for `Invoke-Template`) to send predefined queries. Predefined queries can be added by the user and can contain PowerShell placeholders for getting the user input, for example metric or database name. Integrated templates use [fzf](https://chocolatey.org/packages/fzf) fuzzy finder as input selector.

### Writing data

To write data points to the database use `Send-Data` function:

```powershell
Send-Data "cpu,host=$Env:COMPUTERNAME,user=$Env:USERNAME value=$(Get-Counter '\Processor(_Total)\% Processor Time' | % CounterSamples | % CookedValue)"
```

You can use `[DateTime]::UtcNow.ToString('o')` to send date time instead of nanoseconds until Unix epoch. To do that specify parameter `$UseRoundTripTime`.

For many points, send array of strings.



## Usage

* Functions: `gcm -Module psinflux`
* Use man for help: `man iq`

