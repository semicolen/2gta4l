param(
    [Parameter(Mandatory=$true)][string]$CommandFile,
    [Parameter(Mandatory=$true)][string]$OutputFile,
    [ValidateRange(1,15)][int]$Seconds=3,
    [switch]$Quiet
)
$ErrorActionPreference='Stop'
$taskPortDevice=Get-PnpDevice -PresentOnly | Where-Object {
    $_.InstanceId -match '^USB\\VID_18D1&PID_D001&MI_0[23]\\' -and
    $_.Class -eq 'Ports' -and $_.FriendlyName -match '\(COM[0-9]+\)'
}
if (@($taskPortDevice).Count -ne 1) {throw 'Expected postmarketOS serial interface absent'}
$taskPortName=[regex]::Match($taskPortDevice.FriendlyName,'\((COM[0-9]+)\)').Groups[1].Value
$taskSerial=[System.IO.Ports.SerialPort]::new($taskPortName,115200,[System.IO.Ports.Parity]::None,8,[System.IO.Ports.StopBits]::One)
$taskSerial.ReadTimeout=1000
$taskSerial.WriteTimeout=1000
$taskText=[System.Text.StringBuilder]::new()
try {
    $taskSerial.Open()
    $taskSerial.Write("`r`n")
    Start-Sleep -Milliseconds 700
    [void]$taskText.Append($taskSerial.ReadExisting())
    $taskSerial.Write((Get-Content -LiteralPath $CommandFile -Raw).Replace("`r",'') + "`n")
    $taskTimer=[System.Diagnostics.Stopwatch]::StartNew()
    while ($taskTimer.Elapsed.TotalSeconds -lt $Seconds) {
        try {[void]$taskText.Append($taskSerial.ReadExisting())}
        catch {
            [void]$taskText.Append("`nDiagnostic serial interface disconnected: " + $_.Exception.Message + "`n")
            break
        }
        Start-Sleep -Milliseconds 100
    }
    $taskText.ToString() | Set-Content -LiteralPath $OutputFile
    if ($Quiet) {"Saved $($taskText.Length) console characters to $OutputFile"}
    else {$taskText.ToString()}
} finally {
    if ($taskSerial.IsOpen) {$taskSerial.Close()}
    $taskSerial.Dispose()
}
