Try{ 
  [xml]$Value = $(Invoke-WebRequest -Uri 'https://docs.newrelic.com/docs/release-notes/agent-release-notes/net-release-notes/feed' -ErrorAction Stop).Content 
}
Catch [System.Exception]{ 
  $WebReqErr = $error[0] | Select-Object * | Format-List -Force 
  Write-Error "An error occurred while attempting to connect to the requested site.  The error was $WebReqErr.Exception" 
}

$Version = $Value.rss.channel.Item[0].title -replace '(.*\s)(\d.+)','$2'
$ReleaseNotes = $Value.rss.channel.Item[0].link
Write-Output = "Release Notes: $ReleaseNotes"

Write-Output "Current Version: $Version"
$LocalFile_x86 = "$PSScriptRoot\binaries\NewRelicAgent_x86_$Version.msi"
$LocalFile_x64 = "$PSScriptRoot\binaries\NewRelicAgent_x64_$Version.msi"
New-Item -ItemType Directory -Path "$PSScriptRoot\binaries" -ErrorAction SilentlyContinue | Out-Null


$URL_x86 = "https://download.newrelic.com/dot_net_agent/release/NewRelicAgent_x86_$Version.msi"
Write-Output "x86 URL: $URL_x86"
Invoke-WebRequest `
 -Uri $URL_x86 `
 -OutFile $LocalFile_x86
Write-Output "Downloaded x86"

$URL_x64 = "https://download.newrelic.com/dot_net_agent/release/NewRelicAgent_x64_$Version.msi"
Write-Output "x64 URL: $URL_x64"
Invoke-WebRequest `
 -Uri  $URL_x64 `
 -OutFile $LocalFile_x64
Write-Output "Downloaded x64"


Write-Output "Creating SHA1"
$LocalSHA1_x64 = Get-FileHash `
  -Path $LocalFile_x64 `
  -Algorithm SHA1
Write-Output "x64 SHA: $($LocalSHA1_x64.Hash)"

$LocalSHA1_x86 = Get-FileHash `
  -Path $LocalFile_x86 `
  -Algorithm SHA1
Write-Output "x86 SHA: $($LocalSHA1_x86.Hash)"

Write-Output "Getting MSI ProductCode"
$LocalProductCode_x64 = $(.\Get-MSIFileInformation.ps1 -Path $LocalFile_x64 -Property ProductCode)[3]
Write-Output "x64 ProductCode: $LocalProductCode_x64"

$LocalProductCode_x86 = $(.\Get-MSIFileInformation.ps1 -Path $LocalFile_x86 -Property ProductCode)[3]
Write-Output "x86 ProductCode: $LocalProductCode_x86"

New-Item -ItemType Directory -Path "$PSScriptRoot\tools" -ErrorAction SilentlyContinue | Out-Null

#Nuspec
$(Get-Content -Path "$PSScriptRoot\templates\newrelic-dotnet.nuspec") `
  -replace '##VERSION##', $Version `
  -replace '##RELEASENOTES##', $ReleaseNotes | `
  Out-File "$PSScriptRoot\newrelic-dotnet.nuspec"

#Installer
$(Get-Content -Path "$PSScriptRoot\templates\chocolateyInstall.ps1") `
  -replace '##URLx86##', $URL_x86 `
  -replace '##URLx64##', $URL_x64 | `
  Out-File "$PSScriptRoot\tools\chocolateyInstall.ps1"

#Uninstaller
$(Get-Content -Path "$PSScriptRoot\templates\chocolateyUninstall.ps1") `
  -replace '##PRODUCTCODEx86##', $LocalProductCode_x86 `
  -replace '##PRODUCTCODEx64##', $LocalProductCode_x64 | `
  Out-File "$PSScriptRoot\tools\chocolateyUninstall.ps1"

# Cleanup
#Remove-Item -Path $LocalFile_x64
#Remove-Item -Path $LocalFile_x86