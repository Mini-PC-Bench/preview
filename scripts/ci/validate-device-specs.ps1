[CmdletBinding()]
param(
  [string]$SpecsPath = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'device-specs.json'),
  [string]$DevicesPath = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'devices.json'),
  [string]$SchemaPath = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'schemas/device-specs-public.schema.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# The public schema is pulled with the data from the research repository.
$json = Get-Content -LiteralPath $SpecsPath -Raw
if (-not (Test-Json -Json $json -SchemaFile $SchemaPath)) { throw 'Invalid data-only specifications' }
$document = [System.Text.Json.JsonDocument]::Parse([string]$json)
try {
  $ids = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($device in (Get-Content -LiteralPath $DevicesPath -Raw | ConvertFrom-Json)) {
    if (-not $ids.Add($device.id)) { throw "Duplicate catalog device ID: $($device.id)" }
  }
  $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($record in $document.RootElement.EnumerateObject()) {
    if (-not $seen.Add($record.Name)) { throw "Duplicate specification device ID: $($record.Name)" }
    if (-not $ids.Contains($record.Name)) { throw "Unknown specification device ID: $($record.Name)" }
    $fields = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($field in $record.Value.EnumerateObject()) {
      if (-not $fields.Add($field.Name)) { throw "Duplicate specification field: $($record.Name).$($field.Name)" }
      if ($field.Name -eq 'cpu_model' -and $field.Value.ValueKind -eq 'String' -and -not $field.Value.GetString().Trim()) { throw "Empty processor model: $($record.Name)" }
    }
  }
  Write-Output "Data-only specifications validated: $($seen.Count)/$($ids.Count) devices."
} finally { $document.Dispose() }
