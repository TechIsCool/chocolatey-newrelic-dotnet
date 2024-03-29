﻿$Params = @{
  Algorithm = 'SHA256';
  URL = @{};
  LocalFile = @{};
  Hash = @{};
  ProductCode = @{};
}
$Package     = 'newrelic-dotnet'
$RSSfeed     = 'https://docs.newrelic.com/docs/release-notes/agent-release-notes/net-release-notes/feed.xml'

Try{ 
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  [xml]$RSSResults = $(Invoke-WebRequest -Uri $RSSfeed -ErrorAction Stop).Content
}
Catch [System.Exception]{ 
  $WebReqErr = $error[0] | Select-Object * | Format-List -Force 
  Write-Error "An error occurred while attempting to connect to the requested site.  The error was $WebReqErr.Exception"
}

$Sorted = $RSSResults.rss.channel.item | Sort-Object -Desc -Property @{e={$_.pubDate -as [datetime]}}
$Version = $Sorted[0].title.InnerText -replace '(.*\s)(\d.+)','$2'
$ReleaseNotes = $Sorted[0].link

switch ($Version.split('.')[0]){
  6 {
    $PackageName = 'NewRelicAgent_${OS}_${Version}.msi'
    $PackageURL  = "https://download.newrelic.com/dot_net_agent/6.x_release/$PackageName"
  }
  {$_ -ge 7} {
    $PackageName = 'newrelic-agent-win-${OS}-${Version}.msi'
    $PackageURL  = "https://download.newrelic.com/dot_net_agent/latest_release/$PackageName" 
  }
  {$_ -ge 10} {
    $PackageName = 'NewRelicDotNetAgent_${Version}_${OS}.msi'
    $PackageURL  = "https://download.newrelic.com/dot_net_agent/latest_release/$PackageName" 
  }
  default {
    Write-Error "An error occurred while attempting to determine the Major Version of '$_' from the full Version '${Version}'. Please update the case statement."
  }
}

Write-Output `
  $Package `
  "Release Version: $Version" `
  "Release Notes: $ReleaseNotes" `
  "Release Package Name: $PackageName" `
  "Release Package URL: $PackageURL"

New-Item `
  -ItemType Directory `
  -Path "$PSScriptRoot\output\binaries","$PSScriptRoot\output\tools\" `
  -ErrorAction SilentlyContinue | Out-Null

foreach ($OS in 'x86','x64') {
  $Params['URL'][$OS] = $ExecutionContext.InvokeCommand.ExpandString($PackageURL)
  $Params['LocalFile'][$OS] = "$PSScriptRoot\output\binaries\$($ExecutionContext.InvokeCommand.ExpandString($PackageName))"
  
  Invoke-WebRequest `
   -Uri $Params['URL'][$OS] `
   -OutFile $Params['LocalFile'][$OS]
  Write-Output "Downloaded $OS from $($Params['URL'][$OS])"
   
  $Params['Hash'][$OS] = Get-FileHash `
    -Path $Params['LocalFile'][$OS] `
    -Algorithm $Params['Algorithm']
  Write-Output "Created $OS $($Params['Algorithm']): $($Params['Hash'][$OS].Hash)"
  

  $Params['ProductCode'][$OS] = $(.\Get-MSIFileInformation.ps1 -Path $Params['LocalFile'][$OS] -Property ProductCode)[3]
  Write-Output "Found $OS ProductCode: $($Params['ProductCode'][$OS])"

  Start-Process "msiexec" -ArgumentList "/a $($Params['LocalFile'][$OS]) /qn TARGETDIR=$PSScriptRoot\temp\$OS" -Wait
}

$Comparison = $(Get-ChildItem -Recurse $PSScriptRoot\temp\ | Where-Object {$_.Name -like "license.txt"})
if (Compare-Object $Comparison[0].FullName $Comparison[1].FullName){
  Copy-Item $Comparison[0].FullName -Destination "$PSScriptRoot\output"
  Write-Output "Copied output\License.txt"
}
else{
  Write-Warning "License.txt do not match between MSI"
  exit 5
}

$(Get-Content -Path "$PSScriptRoot\templates\$Package.nuspec") `
  -replace '##VERSION##', $Version `
  -replace '##RELEASENOTES##', $ReleaseNotes | `
  Out-File "$PSScriptRoot\output\$Package.nuspec"
Write-Output 'Created output\$Package.nuspec'

$(Get-Content -Path "$PSScriptRoot\templates\chocolateyInstall.ps1") `
  -replace '##FILEx86##', "$(& {$OS='x86'; $($ExecutionContext.InvokeCommand.ExpandString($PackageName))})" `
  -replace '##FILEx64##', "$(& {$OS='x64'; $($ExecutionContext.InvokeCommand.ExpandString($PackageName))})" `
  -replace '##SHA256x86##', $Params['Hash']['x86'].Hash `
  -replace '##SHA256x64##', $Params['Hash']['x64'].Hash | `
  Out-File "$PSScriptRoot\output\tools\chocolateyInstall.ps1"
Write-Output 'Created output\tools\chocolateyInstall.ps1'

$(Get-Content -Path "$PSScriptRoot\templates\chocolateyUninstall.ps1") `
  -replace '##PRODUCTCODEx86##', $Params['ProductCode']['x86'] `
  -replace '##PRODUCTCODEx64##', $Params['ProductCode']['x64'] | `
  Out-File "$PSScriptRoot\output\tools\chocolateyUninstall.ps1"
Write-Output 'Created output\tools\chocolateyUninstall.ps1'

Copy-Item -Path "$PSScriptRoot\templates\VERIFICATION.txt" `
  -Destination "$PSScriptRoot\output\tools\VERIFICATION.txt"

Set-Item -Path ENV:NUPKG_VERSION -Value "$Version"  
Set-Item -Path ENV:NUPKG -Value "$Package.$Version.nupkg"