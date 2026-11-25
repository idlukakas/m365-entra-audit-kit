<#
.SYNOPSIS
    Generic certificate-based OAuth2 client_credentials helper for Microsoft Graph API.
.DESCRIPTION
    Clean, standalone commercial starter (zero proprietary or institutional data).
    Builds a RS256 client_assertion JWT signed with an installed or PFX X.509 certificate
    and exchanges it for a Microsoft Graph access token.
#>
function New-CertAuthGraphSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $TenantId,
        [Parameter(Mandatory)] [string] $ClientId,
        [Parameter(Mandatory)] [string] $PfxPath,
        [Parameter(Mandatory)] [SecureString] $PfxPassword,
        [string] $Scope = "https://graph.microsoft.com/.default"
    )

    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $PfxPath,
        $PfxPassword,
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
    )

    $now = [DateTimeOffset]::UtcNow
    $toBase64Url = {
        param([byte[]] $Bytes)
        [Convert]::ToBase64String($Bytes).TrimEnd('=') -replace '\+', '-' -replace '/', '_'
    }

    $headerJson = @{
        alg = "RS256"
        typ = "JWT"
        x5t = (& $toBase64Url $cert.GetCertHash())
    } | ConvertTo-Json -Compress

    $payloadJson = @{
        aud = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
        exp = $now.AddMinutes(10).ToUnixTimeSeconds()
        iss = $ClientId
        jti = [Guid]::NewGuid().ToString()
        nbf = $now.ToUnixTimeSeconds()
        sub = $ClientId
    } | ConvertTo-Json -Compress

    $enc = [System.Text.Encoding]::UTF8
    $unsigned = "$(& $toBase64Url ($enc.GetBytes($headerJson))).$(& $toBase64Url ($enc.GetBytes($payloadJson)))"
    $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
    $sig = $rsa.SignData(
        $enc.GetBytes($unsigned),
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
    )
    $assertion = "$unsigned.$(& $toBase64Url $sig)"

    $resp = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -ContentType "application/x-www-form-urlencoded" `
        -Body @{
            client_id             = $ClientId
            scope                 = $Scope
            client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
            client_assertion      = $assertion
            grant_type            = "client_credentials"
        }

    return @{
        AccessToken = $resp.access_token
        ExpiresIn   = $resp.expires_in
        Headers     = @{ Authorization = "Bearer $($resp.access_token)" }
    }
}
