param(
	[string]$DefinitionsPath = $env:ROBLOX_TYPES,
	[switch]$SkipTypes
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$bin = Join-Path $env:USERPROFILE ".rokit\bin"
$work = Join-Path $root "work"

if (-not $DefinitionsPath) {
	$localDefinitions = Join-Path $root "types\roblox.d.luau"
	if (Test-Path -LiteralPath $localDefinitions) {
		$DefinitionsPath = $localDefinitions
	}
}

Set-Location $root
New-Item -ItemType Directory -Force -Path $work | Out-Null

function Invoke-Checked {
	param([string]$Tool, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
	& (Join-Path $bin "$Tool.exe") @Arguments
	if ($LASTEXITCODE -ne 0) {
		throw "$Tool failed with exit code $LASTEXITCODE"
	}
}

Invoke-Checked "rojo" "sourcemap" "default.project.json" "--include-non-scripts" "--output" "work/sourcemap.json"
Invoke-Checked "stylua" "--check" "src" "tests"
Invoke-Checked "selene" "src" "tests"

if (-not $SkipTypes) {
	if (-not $DefinitionsPath -or -not (Test-Path -LiteralPath $DefinitionsPath)) {
		throw "Set ROBLOX_TYPES or pass -DefinitionsPath with a Roblox definitions file."
	}
	Invoke-Checked "luau-lsp" "analyze" "--platform=roblox" "--definitions=$DefinitionsPath" "--sourcemap=work/sourcemap.json" "src" "tests"
}

Get-ChildItem tests -Filter "*.spec.luau" | ForEach-Object {
	Invoke-Checked "lune" "run" $_.FullName
}

Invoke-Checked "rojo" "build" "default.project.json" "--output" "work/integrated.rbxl"
Write-Host "Validation complete. Audit build: work/integrated.rbxl"
