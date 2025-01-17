﻿[CmdletBinding()]
param($IncludeStream, [switch] $Force)

import-module au

if ($MyInvocation.InvocationName -ne '.') {
  # run the update only if the script is not sourced
  function global:au_BeforeUpdate { Get-RemoteFiles -NoSuffix -Purge }
}

function global:au_SearchReplace {
  $version = [version]$Latest.Version
  $silentArgs = if ($version -lt [version]'11.0') {
    ' REMOVE=NodeEtwSupport,NodePerfCtrSupport'
  }
  $silentArgs = "/quiet ADDLOCAL=ALL${silentArgs}"


  @{
    ".\tools\chocolateyInstall.ps1" = @{
      "(^[$]filePath32\s*=\s*`"[$]toolsPath\\)(.*)`"" = "`$1$($Latest.FileName32)`""
      "(^[$]filePath64\s*=\s*`"[$]toolsPath\\)(.*)`"" = "`$1$($Latest.FileName64)`""
      "(?i)(^\s*SilentArgs\s*=\s*)'.*'"               = "`${1}'$silentArgs'"
    }
    ".\legal\verification.txt"      = @{
      "(?i)(32-Bit.+)\<.*\>"      = "`${1}<$($Latest.URL32)>"
      "(?i)(64-Bit.+)\<.*\>"      = "`${1}<$($Latest.URL64)>"
      "(?i)(checksum type:\s+).*" = "`${1}$($Latest.ChecksumType32)"
      "(?i)(checksum32:\s+).*"    = "`${1}$($Latest.Checksum32)"
      "(?i)(checksum64:\s+).*"    = "`${1}$($Latest.Checksum64)"
    }
  }
}

function global:au_GetLatest {
  $urlsToGrabMsis = @(
    "https://nodejs.org/en/download"
    "https://nodejs.org/en/download/current"
  )

  $lts_page = Invoke-WebRequest -Uri "https://github.com/nodejs/Release/blob/master/README.md" -UseBasicParsing

  $urlsToGrabMsis += $lts_page.links | Where-Object href -match "\/latest\-v.*\/$" | Select-Object -expand href

  $streams = @{ }

  $urlsToGrabMsis | ForEach-Object {
    $uri = $_
    $download_page = Invoke-WebRequest -Uri $uri -UseBasicParsing

    $msis = $download_page.links | Where-Object href -match '\.msi$' | Select-Object -expand href | ForEach-Object {
      if (!$_.StartsWith('http')) { return $uri + $_ } else { $_ }
    }

    $url32 = $msis | Where-Object { $_ -match 'x86' } | Select-Object -first 1
    $version = $url32 -split '\-v?' | Select-Object -last 1 -skip 1
    $versionMajor = $version -replace '(^\d+)\..*', "`$1"
    if ($streams.ContainsKey($versionMajor)) { return ; }

    $url64 = $msis | Where-Object { $_ -match "\-x64" } | Select-Object -first 1

    if ($url32 -eq $url64) { throw "The 64bit executable is the same as the 32bit" }

    $streams.Add($versionMajor, @{ Version = $version ; URL32 = $url32; URL64 = $url64 } )
  }

  return @{ Streams = $streams }
}

if ($MyInvocation.InvocationName -ne '.') {
  # run the update only if script is not sourced
  update -ChecksumFor none -IncludeStream $IncludeStream -Force:$Force
}
