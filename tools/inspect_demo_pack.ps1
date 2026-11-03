param([string]$Pack = 'builds/playable-demo/Anarchy Intelligence Demo.pck')
$ErrorActionPreference = 'Stop'
$stream = [IO.File]::OpenRead((Resolve-Path -LiteralPath $Pack).Path)
$reader = [IO.BinaryReader]::new($stream)
try {
    if ($reader.ReadUInt32() -ne 0x43504447) { throw 'Invalid PCK magic' }
    $version = $reader.ReadUInt32()
    $stream.Position = 20
    $flags = $reader.ReadUInt32()
    if ($flags -band 1) { throw 'Encrypted directory is unsupported' }
    $fileBase = $reader.ReadUInt64()
    if ($version -in @(3,4)) { $stream.Position = $reader.ReadUInt64() }
    elseif ($version -eq 2) { $stream.Position = 96 }
    else { throw "Unsupported PCK version $version" }
    $count = $reader.ReadUInt32()
    $entries = for ($i = 0; $i -lt $count; $i++) {
        $length = $reader.ReadUInt32()
        $path = [Text.Encoding]::UTF8.GetString($reader.ReadBytes($length)).TrimEnd([char]0)
        $offset = $reader.ReadUInt64()
        $size = $reader.ReadUInt64()
        $null = $reader.ReadBytes(16)
        $entryFlags = $reader.ReadUInt32()
        [pscustomobject]@{Path=$path; Bytes=$size; MiB=[math]::Round($size/1MB,3); Offset=$offset+$fileBase}
    }
    $entries | Sort-Object Bytes -Descending | Export-Csv 'builds/playable-demo/pack-inventory.csv' -NoTypeInformation
    $entries | Sort-Object Bytes -Descending | Select-Object -First 25 Path,MiB | ConvertTo-Json
    $entries | Group-Object { if ($_.Path -match '\.ctex$') {'Textures'} elseif ($_.Path -match '\.scn$') {'Imported models'} elseif ($_.Path -match '\.(ogg|mp3|wav|sample)$') {'Audio'} else {'Other'} } | ForEach-Object { [pscustomobject]@{Category=$_.Name; MiB=[math]::Round(($_.Group | Measure-Object Bytes -Sum).Sum/1MB,2)} } | ConvertTo-Json
} finally { $reader.Dispose() }
