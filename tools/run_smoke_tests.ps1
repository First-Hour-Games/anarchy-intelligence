# Runs the headless GDScript tests under tests/ and prints a compact summary.
# Usage (from the repository root):
#   powershell -ExecutionPolicy Bypass -File tools/run_smoke_tests.ps1
#   powershell -ExecutionPolicy Bypass -File tools/run_smoke_tests.ps1 -Filter ridgeback,fog
#   powershell -ExecutionPolicy Bypass -File tools/run_smoke_tests.ps1 -Filter tutorial -ShowOutput
# A test fails when it exits non-zero, prints a "FAIL " line, reports a script
# error, or exceeds the timeout. Set GODOT_CONSOLE to override the Godot path.
param(
	[string[]]$Filter = @(),
	[int]$TimeoutSeconds = 180,
	[switch]$ShowOutput
)

$ErrorActionPreference = "Stop"
# powershell -File passes "a,b" as one string; split it into patterns.
$Filter = @($Filter | ForEach-Object { $_ -split "," } | Where-Object { $_ })
$repo = Split-Path -Parent $PSScriptRoot

$godot = $env:GODOT_CONSOLE
if (-not $godot) {
	$godot = Get-ChildItem "$env:LOCALAPPDATA\Programs\Godot" -Recurse -Filter "Godot_v4.7*_console.exe" -ErrorAction SilentlyContinue |
		Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $godot -or -not (Test-Path $godot)) {
	Write-Error "Godot 4.7 console executable not found. Set GODOT_CONSOLE to its path."
}

# Scripts in tests/ that inspect content rather than assert behavior.
$excluded = @("inspect_gameplay_assets", "inspect_house_routes", "inspect_level_alignment", "opening_story_preview", "test_positions")

$tests = Get-ChildItem (Join-Path $repo "tests") -Filter "*.gd" | Where-Object { $excluded -notcontains $_.BaseName }
if ($Filter.Count -gt 0) {
	$tests = $tests | Where-Object { $name = $_.BaseName; @($Filter | Where-Object { $name -like "*$_*" }).Count -gt 0 }
}
if (-not $tests) {
	Write-Error "No tests match: $($Filter -join ', ')"
}

$failedTests = @()
$started = Get-Date
foreach ($test in $tests) {
	$log = [System.IO.Path]::GetTempFileName()
	$errLog = [System.IO.Path]::GetTempFileName()
	$process = Start-Process -FilePath $godot -ArgumentList @("--headless", "--path", "`"$repo`"", "--script", "res://tests/$($test.Name)") `
		-RedirectStandardOutput $log -RedirectStandardError $errLog -NoNewWindow -PassThru
	# Windows PowerShell only reports ExitCode if the handle is opened before exit.
	$null = $process.Handle
	$timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
	if ($timedOut) {
		$process.Kill()
		$process.WaitForExit()
	}
	$output = @(Get-Content $log) + @(Get-Content $errLog)
	Remove-Item $log, $errLog -ErrorAction SilentlyContinue

	$problems = @($output | Where-Object { $_ -match "^FAIL |SCRIPT ERROR|Parse Error|Failed to load script" })
	$passed = -not $timedOut -and $process.ExitCode -eq 0 -and $problems.Count -eq 0
	if ($passed) {
		Write-Host "PASS  $($test.BaseName)" -ForegroundColor Green
	} else {
		$reason = if ($timedOut) { "timed out after ${TimeoutSeconds}s" } else { "exit $($process.ExitCode)" }
		Write-Host "FAIL  $($test.BaseName) ($reason)" -ForegroundColor Red
		$problems | Select-Object -First 15 | ForEach-Object { Write-Host "        $_" }
		$failedTests += $test.BaseName
	}
	if ($ShowOutput) {
		$output | ForEach-Object { Write-Host "        $_" }
	}
}

$elapsed = [int]((Get-Date) - $started).TotalSeconds
Write-Host ""
Write-Host "$($tests.Count - $failedTests.Count)/$($tests.Count) passed in ${elapsed}s"
if ($failedTests.Count -gt 0) {
	Write-Host "Failed: $($failedTests -join ', ')"
	exit 1
}
exit 0
