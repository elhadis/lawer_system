# Build Gradle truststore: default JDK certs + Windows roots + live Maven/Google chain.
$ErrorActionPreference = "Continue"
$projectRoot = Split-Path $PSScriptRoot -Parent
$javaHome = "C:\Program Files\Android\Android Studio1\jbr"
$keytool = Join-Path $javaHome "bin\keytool.exe"
$sourceCerts = Join-Path $javaHome "lib\security\cacerts"
$targetCerts = Join-Path $projectRoot "android\gradle-truststore.jks"
$storepass = "changeit"

if (-not (Test-Path $keytool)) {
    Write-Error "keytool not found at $keytool"
    exit 1
}

Copy-Item -Path $sourceCerts -Destination $targetCerts -Force
Write-Host "Base cacerts -> $targetCerts"

function Import-CertToStore($cert, [string]$aliasPrefix) {
    if ($null -eq $cert) { return $false }
    $cerPath = Join-Path $env:TEMP "$aliasPrefix-$([guid]::NewGuid()).cer"
    try {
        Export-Certificate -Cert $cert -FilePath $cerPath -Force | Out-Null
        $alias = "$aliasPrefix-$($cert.Thumbprint)"
        & $keytool -importcert -noprompt -alias $alias -file $cerPath `
            -keystore $targetCerts -storepass $storepass *>$null
        return ($LASTEXITCODE -eq 0)
    } finally {
        Remove-Item $cerPath -ErrorAction SilentlyContinue
    }
}

$imported = 0
foreach ($store in @("Cert:\LocalMachine\Root", "Cert:\CurrentUser\Root")) {
    Get-ChildItem -Path $store -ErrorAction SilentlyContinue | ForEach-Object {
        if (Import-CertToStore $_ "roots") { $imported++ }
    }
}

function Import-RemoteCert([string]$hostName) {
    $req = [System.Net.HttpWebRequest]::Create("https://$hostName/")
    $req.AllowAutoRedirect = $true
    $req.Timeout = 20000
    try {
        $resp = $req.GetResponse()
        $resp.Close()
    } catch {
        # Still captures ServicePoint certificate on TLS failure.
    }
    $cert = $req.ServicePoint.Certificate
  if ($cert -is [System.Security.Cryptography.X509Certificates.X509Certificate2]) {
        return $cert
    }
    if ($null -ne $cert) {
        return New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($cert)
    }
    return $null
}

foreach ($hostName in @("dl.google.com", "repo.maven.apache.org")) {
    $remote = Import-RemoteCert $hostName
    if (Import-CertToStore $remote "remote-$hostName") {
        $imported++
        Write-Host "Imported TLS cert from $hostName"
    }
}

Write-Host "Trust store ready ($imported new entries). Path:"
Write-Host $targetCerts
