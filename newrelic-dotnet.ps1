$Params = @{
  Algorithm = 'SHA256';
  URL = @{};
  LocalFile = @{};
  Hash = @{};
}
$Package    = 'newrelic-dotnet'
$RSSfeed    = 'https://docs.newrelic.com/docs/release-notes/agent-release-notes/net-release-notes/feed'
$PackageURL = 'https://download.newrelic.com/dot_net_agent/release/NewRelicAgent_$OS_$Version.msi'  

Try{ 
  [xml]$Value = $(Invoke-WebRequest -Uri $RSSfeed -ErrorAction Stop).Content 
}
Catch [System.Exception]{ 
  $WebReqErr = $error[0] | Select-Object * | Format-List -Force 
  Write-Error "An error occurred while attempting to connect to the requested site.  The error was $WebReqErr.Exception" 
}

$Version = $Value.rss.channel.Item[0].title -replace '(.*\s)(\d.+)','$2'
$ReleaseNotes = $Value.rss.channel.Item[0].link

Write-Output "Release Notes: $ReleaseNotes"
Write-Output "Release Version: $Version"

New-Item `
  -ItemType Directory `
  -Path "$PSScriptRoot\binaries" `
  -ErrorAction SilentlyContinue | Out-Null
  
foreach ($OS in 'x86','x64') {
  $Params['URL'][$OS] = "https://download.newrelic.com/dot_net_agent/release/NewRelicAgent_$os_$Version.msi"
  $Params['LocalFile'][$OS] = "$PSScriptRoot\binaries\$OS_$Version.msi"
  Write-Output $Params['URL'][$OS]
  Invoke-WebRequest `
   -Uri $Params['URL'][$OS] `
   -OutFile $Params['LocalFile'][$OS]
  Write-Output "Downloaded $OS"
  Write-Output "  $OS URL: $($URL[$OS])"
   
  Write-Output "Creating $($Params['Algorithm'])"
  $Params['Hash'][$OS] = Get-FileHash `
    -Path $Params['LocalFile'][$OS] `
    -Algorithm $Params['Algorithm']
  Write-Output "  $OS $($Params['Algorithm']): $($Params[$Algorithm][$OS].Hash)"

  Write-Output "Getting MSI ProductCode"
  $Params['ProductCode'][$OS] = $(.\Get-MSIFileInformation.ps1 -Path $LocalFile[$OS] -Property ProductCode)[3]
  Write-Output "  $OS ProductCode: $($Params['ProductCode'][$OS])"
}

New-Item `
  -ItemType Directory `
  -Path "$PSScriptRoot\output\tools\" `
  -ErrorAction SilentlyContinue | Out-Null

$(Get-Content -Path "$PSScriptRoot\templates\$Package.nuspec") `
  -replace '##VERSION##', $Version `
  -replace '##RELEASENOTES##', $ReleaseNotes | `
  Out-File "$PSScriptRoot\output\$Package.nuspec"
Write-Output 'Created output\$Package.nuspec'

$(Get-Content -Path "$PSScriptRoot\templates\chocolateyInstall.ps1") `
  -replace '##URLx86##', $URL['x86'] `
  -replace '##URLx64##', $URL['x64'] `
  -replace '##SHA256x86##', $Params['Hash']['x86'].Hash `
  -replace '##SHA256x64##', $Params['Hash']['x64'].Hash | `
  Out-File "$PSScriptRoot\output\tools\chocolateyInstall.ps1"
Write-Output 'Created output\tools\chocolateyInstall.ps1'

$(Get-Content -Path "$PSScriptRoot\templates\chocolateyUninstall.ps1") `
  -replace '##PRODUCTCODEx86##', $Params['ProductCode']['x86'] `
  -replace '##PRODUCTCODEx64##', $Params['ProductCode']['x64'] | `
  Out-File "$PSScriptRoot\output\tools\chocolateyUninstall.ps1"
Write-Output 'Created output\tools\chocolateyUninstall.ps1'

Set-Item -Path ENV:NUPKG -Value "$Package.$Version.nupkg"