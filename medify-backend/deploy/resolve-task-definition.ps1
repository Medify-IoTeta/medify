# Fills the task-definition template with local secrets, without ever writing
# them into a committed file or this script itself. Run from anywhere; paths
# below are relative to this script's own location.
#
# Output: task-definition.resolved.json (git-ignored) next to this script,
# ready for: aws ecs register-task-definition --cli-input-json file://task-definition.resolved.json --region us-east-1

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$templatePath  = Join-Path $scriptDir "task-definition.template.json"
$firebasePath  = Join-Path $scriptDir "..\secrets\firebase-service-account.json"
$resolvedPath  = Join-Path $scriptDir "task-definition.resolved.json"

if (-not (Test-Path $firebasePath)) {
    throw "Firebase service account file not found at $firebasePath"
}

# [System.IO.File]::ReadAllText (not Get-Content -Raw) on purpose: Get-Content's
# return value carries hidden PSPath/PSDrive/PSProvider metadata properties, and
# ConvertTo-Json serializes ALL of an object's properties -- so piping a
# Get-Content result into ConvertTo-Json produces a JSON object polluted with
# filesystem metadata instead of a clean JSON string. ReadAllText returns a
# plain .NET string with no such properties attached.
$template = [System.IO.File]::ReadAllText($templatePath)
$firebaseRaw = [System.IO.File]::ReadAllText($firebasePath)
$firebaseEscaped = $firebaseRaw | ConvertTo-Json  # produces a properly-quoted, escaped JSON string literal

$securePassword = Read-Host "Enter the current RDS DB password" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$dbPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)

$resolved = $template.Replace('"__FIREBASE_CREDENTIALS_JSON__"', $firebaseEscaped).Replace('__DB_PASSWORD__', $dbPassword)

# Write without a BOM -- Set-Content/Out-File -Encoding utf8 in Windows PowerShell
# 5.1 prepends a UTF-8 BOM, which the AWS CLI's JSON parser rejects outright
# ("Invalid JSON received") with no further detail.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($resolvedPath, $resolved, $utf8NoBom)

# Validate before declaring success, so a bad substitution fails here with a
# clear message instead of surfacing as an opaque AWS CLI parse error.
try {
    Get-Content -Raw -Path $resolvedPath | ConvertFrom-Json | Out-Null
} catch {
    throw "Resolved file is not valid JSON: $_"
}

Write-Host "Wrote $resolvedPath (git-ignored) - validated as JSON"
