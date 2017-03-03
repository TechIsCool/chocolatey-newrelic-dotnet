$package = 'newrelic-dotnet'

$choco_params = @{
  PackageName = $package;
  FileType       = 'msi';
  SilentArgs     = '/qb INSTALLLEVEL=50'
  Url            = '##URLx86##';
  Url64bit       = '##URLx64##';
  checksum       = '##SHA256x86##'
  checksumType   = 'sha256'
  checksum64     = '##SHA256x64##'
  checksumType64 = 'sha256'
  ValidExitCodes = @(0)
}
$restartiis = $false

if (![string]::IsNullOrEmpty($env:chocolateyPackageParameters))
{
  if ($env:chocolateyPackageParameters.ToLower().Contains("restartiis") -or $env:chocolateyPackageParameters.ToLower().Contains("license_key"))
  {    
    # Getting Parameters
    $rawTxt =  [regex]::escape($env:chocolateyPackageParameters)
    $params = $($rawTxt -split ';' | ForEach-Object {
      $temp= $_ -split '='
      "{0}={1}" -f $temp[0].Substring(0,$temp[0].Length),$temp[1]
    } | ConvertFrom-StringData)

    if ($params.restartiis -eq 'true')
    {      
      Write-Host "Found 'restartiis' parameter enabled."
      $restartiis = $true
    }
    else
    {
      $restartiis = $false
    }
    
    if (![string]::IsNullOrEmpty($params.license_key))
    {        
      # Passing License key
      $choco_params['SilentArgs'] = $choco_params['SilentArgs'] + " NR_LICENSE_KEY=" + $params.license_key      
    }
    else
    {
      Write-Warning "No New Relic license key specified. Please use -params 'license_key=<newrelic_key>' or alternatively specify it manually after installation."
    }
  }
  else
  {
    Write-Warning "No New Relic license key specified. Please use -params 'license_key=<newrelic_key>' or alternatively specify it manually after installation."
  }
}
else
{
  Write-Warning "No New Relic license key specified. Please use -params 'license_key=<newrelic_key>' or alternatively specify it manually after installation."
}

try { #error handling is only necessary if you need to do anything in addition to/instead of the main helpers
  
  if ($restartiis)
  {
    # Stop IIS before installing
    $ServiceName = "W3SVC"
    $service = Get-Service "$ServiceName" -ErrorAction SilentlyContinue
    if ($service -ne $null)
    {
      
        Write-Host $($ServiceName + " service will be stopped")

        Stop-Service $ServiceName
         
        Write-Output "Sleeping for $sleep_timeout seconds"  
        
        $i = 0
        while (!(Get-Service $ServiceName | Where-Object {$_.status -eq "stopped"}))
        {  
          
          Write-Output "Waiting for ${ServiceName} to be stopped"    
          if ($i -gt $sleep_timeout)
          {
            throw "Can't wait for ${ServiceName} to be stopped. Took longer than ${sleep_timeout}s: Timeout"
          }
          Write-Output "[$i]"
          Start-Sleep -s 1
          $i++
        }
        Write-Output "${ServiceName} is stopped. Continue."
        
        Install-ChocolateyPackage @choco_params
        
        Write-Host "Configuring $ServiceName to autostart"
        
        Set-Service $ServiceName -startuptype "auto"
        
        Write-Host $("Starting "+$ServiceName+" service")
        Start-Service $ServiceName
    }
    else
    {  
      Write-Output "No ${ServiceName} service found. Nothing to restart. Continue."
      Install-ChocolateyPackage @choco_params
    }
  }
  else
  {  
    Write-Warning "IIS will not be restarted. Please do so manually. In order to stop & start IIS automatically use parameter: -params 'restartiis=true'. "    
    Install-ChocolateyPackage @choco_params
  }
  
} catch {
  Write-ChocolateyFailure "$packageName" "$($_.Exception.Message)"
  throw
}
