$package = 'newrelic-dotnet' # arbitrary name for the package, used in messages
$ProductCode_x86 = '##PRODUCTCODEx86##'
$ProductCode_x64 = '##PRODUCTCODEx64##'

if( `
  (Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$ProductCode_x86") -or `
  (Test-Path "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$ProductCode_x86") `
){
  try {
    # http://stackoverflow.com/questions/450027/uninstalling-an-msi-file-from-the-command-line-without-using-msiexec
    $msiArgs = "/X $ProductCode_x86 /qb"
  
    Start-ChocolateyProcessAsAdmin "$msiArgs" 'msiexec'

    Write-ChocolateySuccess $package
  } catch {
    Write-ChocolateyFailure $package "$($_.Exception.Message)"
    throw
  }
}

if( `
  (Test-Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$ProductCode_x64") -or `
  (Test-Path "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$ProductCode_x64") `
){
  try {
    # http://stackoverflow.com/questions/450027/uninstalling-an-msi-file-from-the-command-line-without-using-msiexec
    $msiArgs = "/X $ProductCode_x64 /qb"

    Start-ChocolateyProcessAsAdmin "$msiArgs" 'msiexec'

    Write-ChocolateySuccess $package
  } catch {
    Write-ChocolateyFailure $package "$($_.Exception.Message)"
    throw
  }
}