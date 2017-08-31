if ($(git rev-parse --abbrev-ref HEAD) -eq 'master'){
  $published_version = $(choco list newrelic-dotnet --limitoutput).Split('|')
  $local_nupkg = $env:NUPKG
  $published_nupkg = "$($published_version[0]).$($published_version[1]).nupkg"

  if( $env:NUPKG -ne $published_nupkg ){
    choco apiKey -k $env:TOKEN -source https://chocolatey.org/
    choco push $env:NUPKG
  }
  else {
      Write-Output "Published Version ($published_nupkg) already equals Build Version ($local_nupkg)"
  }
}
else {
  Write-Output "Only the master branch can deploy"
}