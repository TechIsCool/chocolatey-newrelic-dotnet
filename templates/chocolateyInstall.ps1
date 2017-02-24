#NOTE: Please remove any commented lines to tidy up prior to releasing the package, including this one

$packageName = 'newrelic-dotnet' # arbitrary name for the package, used in messages
$installerType = 'msi' #only one of these: exe, msi, msu
$url = '##URLx86##' # download url
$url64 = '##URLx64##' # 64bit URL here or remove - if installer decides, then use $url
$silentArgs = '/qb INSTALLLEVEL=50' # "/s /S /q /Q /quiet /silent /SILENT /VERYSILENT" # try any of these to get the silent installer #msi is always /quiet
$validExitCodes = @(0) #please insert other valid exit codes here, exit codes for ms http://msdn.microsoft.com/en-us/library/aa368542(VS.85).aspx

# Defaults
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
      $silentArgs = $silentArgs + " NR_LICENSE_KEY=" + $params.license_key      
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
      
        Write-Host $($ServiceName+" service will be stopped")

        Stop-Service $ServiceName
         
        echo "Sleeping for $sleep_timeout seconds"  
        
        $i = 0
        while (!(Get-Service $ServiceName | Where-Object {$_.status -eq "stopped"}))
        {  
          
          echo "Waiting for ${ServiceName} to be stopped"    
          if ($i -gt $sleep_timeout)
          {
            throw "Can't wait for ${ServiceName} to be stopped. Took longer than ${sleep_timeout}s: Timeout"
          }
          Echo "[$i]"
          Start-Sleep -s 1
          $i++
        }
        echo "${ServiceName} is stopped. Continue."
        
        Install-ChocolateyPackage "$packageName" "$installerType" "$silentArgs" "$url" "$url64"  -validExitCodes $validExitCodes
        
        Write-Host "Configuring $ServiceName to autostart"
        
        Set-Service $ServiceName -startuptype "auto"
        
        Write-Host $("Starting "+$ServiceName+" service")
        Start-Service $ServiceName
    }
    else
    {  
      echo "No ${ServiceName} service found. Nothing to restart. Continue."
      Install-ChocolateyPackage "$packageName" "$installerType" "$silentArgs" "$url" "$url64"  -validExitCodes $validExitCodes
    }
  }
  else
  {  
    Write-Warning "IIS will not be restarted. Please do so manually. In order to stop & start IIS automatically use parameter: -params 'restartiis=true'. "    
    Install-ChocolateyPackage "$packageName" "$installerType" "$silentArgs" "$url" "$url64"  -validExitCodes $validExitCodes
  }
  
} catch {
  Write-ChocolateyFailure "$packageName" "$($_.Exception.Message)"
  throw
}
