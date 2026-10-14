# Regenerate a dependency-filtered Windows demo preset without changing existing presets.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$presetPath = Join-Path $projectRoot 'export_presets.cfg'
$files = @(Get-ChildItem $projectRoot -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\(\.godot|\.git|builds|scratch|tests|art_concepts)\\'
})
$resources = @{}
foreach ($file in $files) {
    $relative = $file.FullName.Substring($projectRoot.Length + 1).Replace('\', '/')
    if ($file.Extension -notin @('.import', '.uid', '.md', '.ps1', '.py', '.blend', '.zip', '.cfg')) {
        $resources['res://' + $relative] = $file.FullName
    }
}
$selected = [System.Collections.Generic.HashSet[string]]::new()
$queue = [System.Collections.Generic.Queue[string]]::new()
function Add-Resource([string]$path) {
    if ($resources.ContainsKey($path) -and $selected.Add($path)) { $queue.Enqueue($path) }
}
@(
    'res://project.godot', 'res://gameIcon.png', 'res://default_bus_layout.tres',
    'res://scenes/mainMenu/startup.tscn', 'res://scenes/mainMenu/menu.tscn',
    'res://scenes/chapters/intro/intro.tscn', 'res://scenes/chapters/tutorial/tutorial.tscn',
    'res://scenes/chapters/main/starting_forest.tscn', 'res://scenes/chapters/main/map.tscn',
    'res://addons/dialogue_manager/dialogue_manager.gd'
) | ForEach-Object { Add-Resource $_ }
# Keep production scripts for global class registrations and string-based scene loading.
foreach ($path in $resources.Keys) {
    if ($path -match '^res://addons/dialogue_manager/l10n/.*\.po$') { Add-Resource $path }
    if ($path -match '^res://(scenes|models|addons/dialogue_manager)/.*\.gd$' -and $path -notmatch '/playground/' -and $path -notmatch '^res://addons/dialogue_manager/(components|views|assets)/') { Add-Resource $path }
}
while ($queue.Count -gt 0) {
    $path = $queue.Dequeue()
    if ([IO.Path]::GetExtension($path) -notin @('.godot', '.gd', '.tscn', '.tres', '.dialogue', '.gdshader')) { continue }
    $content = [IO.File]::ReadAllText($resources[$path])
    foreach ($match in [regex]::Matches($content, 'res://[^"''\r\n]+')) {
        $reference = $match.Value
        if ($resources.ContainsKey($reference)) { Add-Resource $reference; continue }
        # Expand directory constants, filename prefixes, and printf frame sequences.
        $prefix = ($reference -split '%')[0]
        if ($prefix -eq 'res://' -or $prefix -eq 'res://addons/') { continue }
        foreach ($candidate in $resources.Keys) {
            if ($candidate.StartsWith($prefix, [StringComparison]::Ordinal)) { Add-Resource $candidate }
        }
    }
}
$source = [IO.File]::ReadAllText($presetPath)
$demoName = 'Playable Demo - Windows'
$existing = [regex]::Match($source, '(?ms)^\[preset\.(\d+)\]\s+name="Playable Demo - Windows".*\z')
if ($existing.Success) { $source = $source.Substring(0, $existing.Index).TrimEnd() + "`r`n" }
$indices = @([regex]::Matches($source, '(?m)^\[preset\.(\d+)\]') | ForEach-Object { [int]$_.Groups[1].Value })
$index = ($indices | Measure-Object -Maximum).Maximum + 1
$template = [regex]::Match($source, '(?ms)^\[preset\.0\].*?(?=^\[preset\.1\])').Value.TrimEnd()
if (-not $template) { throw 'Windows preset 0 was not found.' }
$template = $template.Replace('[preset.0', "[preset.$index")
$template = [regex]::Replace($template, '(?m)^name=.*$', ('name="' + $demoName + '"'))
$template = [regex]::Replace($template, '(?m)^export_filter=.*$', 'export_filter="resources"')
$paths = @($selected | Where-Object { $_ -ne 'res://project.godot' } | Sort-Object)
$list = 'export_files=PackedStringArray(' + (($paths | ForEach-Object { '"' + $_ + '"' }) -join ', ') + ')'
$template = $template.Replace('export_filter="resources"', ('export_filter="resources"' + "`r`n" + $list))
$template = [regex]::Replace($template, '(?m)^export_path=.*$', 'export_path="builds/playable-demo/Anarchy Intelligence Demo.exe"')
$template = [regex]::Replace($template, '(?m)^exclude_filter=.*$', 'exclude_filter="tests/*,scratch/*,tools/*,art_concepts/*,builds/*,*.backup-*"')
[IO.File]::WriteAllText($presetPath, $source.TrimEnd() + "`r`n`r`n" + $template + "`r`n", [Text.UTF8Encoding]::new($false))
Write-Output "Prepared '$demoName' with $($paths.Count) explicit resources plus Godot dependencies."
