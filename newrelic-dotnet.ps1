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

Write-Output "Release Version: $Version"
$LocalFile_x86 = "$PSScriptRoot\binaries\NewRelicAgent_x86_$Version.msi"
$LocalFile_x64 = "$PSScriptRoot\binaries\NewRelicAgent_x64_$Version.msi"
New-Item -ItemType Directory -Path "$PSScriptRoot\binaries" -ErrorAction SilentlyContinue | Out-Null


$URL_x86 = "https://download.newrelic.com/dot_net_agent/release/NewRelicAgent_x86_$Version.msi"
Invoke-WebRequest `
 -Uri $URL_x86 `
 -OutFile $LocalFile_x86
Write-Output "Downloaded x86"
Write-Output "  x86 URL: $URL_x86"

$URL_x64 = "https://download.newrelic.com/dot_net_agent/release/NewRelicAgent_x64_$Version.msi"
Invoke-WebRequest `
 -Uri  $URL_x64 `
 -OutFile $LocalFile_x64
Write-Output "Downloaded x64"
Write-Output "  x64 URL: $URL_x64"


Write-Output "Creating SHA256"
$LocalSHA256_x64 = Get-FileHash `
  -Path $LocalFile_x64 `
  -Algorithm SHA256
Write-Output "  x64 SHA256: $($LocalSHA256_x64.Hash)"

$LocalSHA256_x86 = Get-FileHash `
  -Path $LocalFile_x86 `
  -Algorithm SHA256
Write-Output "  x86 SHA256: $($LocalSHA256_x86.Hash)"

Write-Output "Getting MSI ProductCode"
$LocalProductCode_x64 = $(.\Get-MSIFileInformation.ps1 -Path $LocalFile_x64 -Property ProductCode)[3]
Write-Output "  x64 ProductCode: $LocalProductCode_x64"

$LocalProductCode_x86 = $(.\Get-MSIFileInformation.ps1 -Path $LocalFile_x86 -Property ProductCode)[3]
Write-Output "  x86 ProductCode: $LocalProductCode_x86"

New-Item -ItemType Directory -Path "$PSScriptRoot\output\tools\" -ErrorAction SilentlyContinue | Out-Null

$(Get-Content -Path "$PSScriptRoot\templates\newrelic-dotnet.nuspec") `
  -replace '##VERSION##', $Version `
  -replace '##RELEASENOTES##', $ReleaseNotes | `
  Out-File "$PSScriptRoot\output\newrelic-dotnet.nuspec"
Write-Output 'Created output\newrelic-dotnet.nuspec'

$(Get-Content -Path "$PSScriptRoot\templates\chocolateyInstall.ps1") `
  -replace '##URLx86##', $URL_x86 `
  -replace '##URLx64##', $URL_x64 `
  -replace '##SHA256x86##', $LocalSHA256_x86.Hash `
  -replace '##SHA256x64##', $LocalSHA256_x64.Hash | `
  Out-File "$PSScriptRoot\output\tools\chocolateyInstall.ps1"
Write-Output 'Created output\tools\chocolateyInstall.ps1'

$(Get-Content -Path "$PSScriptRoot\templates\chocolateyUninstall.ps1") `
  -replace '##PRODUCTCODEx86##', $LocalProductCode_x86 `
  -replace '##PRODUCTCODEx64##', $LocalProductCode_x64 | `
  Out-File "$PSScriptRoot\output\tools\chocolateyUninstall.ps1"
Write-Output 'Created output\tools\chocolateyUninstall.ps1'

Set-Item -Path ENV:NUPKG -Value "newrelic-dotnet.$Version.nupkg"