param([ValidateRange(1,16384)][int]$MaxSize = 1024)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$backupRoot = Join-Path $projectRoot ('builds/texture-import-backup-' + $MaxSize + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$imports = @(Get-ChildItem $projectRoot -Recurse -File -Filter '*.import' | Where-Object {
    $_.FullName -notmatch '\\(\.godot|\.git|builds)\\'
})
$manifest = foreach ($file in $imports) {
    $content = [IO.File]::ReadAllText($file.FullName)
    if ($content -notmatch '(?m)^importer="texture"') { continue }
    $limitMatch = [regex]::Match($content, '(?m)^process/size_limit=(\d+)')
    if (-not $limitMatch.Success) { throw "Missing texture size setting: $($file.FullName)" }
    $oldLimit = [int]$limitMatch.Groups[1].Value
    if ($oldLimit -gt 0 -and $oldLimit -le $MaxSize) { continue }
    $sourcePath = $file.FullName.Substring(0,$file.FullName.Length - 7)
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { continue }
    $relativePath = $file.FullName.Substring($projectRoot.Length + 1)
    $backupPath = Join-Path $backupRoot $relativePath
    New-Item -ItemType Directory -Path (Split-Path $backupPath) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $backupPath
    $sourceHash = (Get-FileHash -LiteralPath $sourcePath).Hash
    $updated = [regex]::Replace($content, '(?m)^process/size_limit=\d+', ('process/size_limit=' + $MaxSize))
    $temporaryPath = $file.FullName + '.texture-cap.tmp'
    [IO.File]::WriteAllText($temporaryPath,$updated,[Text.UTF8Encoding]::new($false))
    [IO.File]::Move($temporaryPath,$file.FullName,$true)
    [pscustomobject]@{Import=$relativePath;Source=$sourcePath;SourceHash=$sourceHash;PreviousLimit=$oldLimit;NewLimit=$MaxSize}
}
if (@($manifest).Count -gt 0) {
    $manifest | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $backupRoot 'manifest.json')
}
Write-Output "Capped $(@($manifest).Count) texture imports at $MaxSize pixels. Backup: $backupRoot"
