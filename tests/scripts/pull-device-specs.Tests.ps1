$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$pull = Join-Path $repository 'scripts/devices/pull-device-specs.ps1'
$temporary = Join-Path ([IO.Path]::GetTempPath()) ('pull-check-' + [guid]::NewGuid())
$source = Join-Path $temporary 'research'
$rendering = Join-Path $temporary 'rendering'
[void][IO.Directory]::CreateDirectory((Join-Path $source 'schemas'))
[void][IO.Directory]::CreateDirectory((Join-Path $rendering 'schemas'))
$sourceData = Join-Path $source 'device-specs.json'
$sourceSchema = Join-Path $source 'schemas/device-specs-public.schema.json'
$targetData = Join-Path $rendering 'device-specs.json'
$targetSchema = Join-Path $rendering 'schemas/device-specs-public.schema.json'

function Assert-PullCheck($Condition, $Message) { if (-not $Condition) { throw $Message } }
function Assert-PullRejected([scriptblock]$Action) {
  $oldData = [IO.File]::ReadAllText($targetData)
  $oldSchema = [IO.File]::ReadAllText($targetSchema)
  $failed = $false
  try { & $Action } catch { $failed = $true }
  Assert-PullCheck ($failed -and [IO.File]::ReadAllText($targetData) -ceq $oldData -and [IO.File]::ReadAllText($targetSchema) -ceq $oldSchema) 'Failed pull changed the local data/schema pair'
}

try {
  Copy-Item -LiteralPath (Join-Path $repository 'schemas/device-specs-public.schema.json') -Destination $sourceSchema
  [IO.File]::WriteAllText((Join-Path $rendering 'devices.json'), '[{"id":"dual"},{"id":"none"},{"id":"unknown"},{"id":"omitted"}]')
  $valid = '{"dual":{"cpu_model":"Reviewed CPU","ethernet_ports_mbps":[2500,2500],"date":"2026-10-11","evidence":{"cpu_model":{"status":"reviewed"},"ethernet_ports_mbps":{"status":"reviewed","excerpt":"two ports"}}},"none":{"ethernet_ports_mbps":[],"evidence":{"ethernet_ports_mbps":{"status":"reviewed"}}},"unknown":{"ethernet_ports_mbps":null,"evidence":{}},"omitted":{"evidence":{}}}'
  [IO.File]::WriteAllText($sourceData, $valid)
  & $pull -SpecsRepo $source -Root $rendering
  $output = Get-Content -Raw $targetData | ConvertFrom-Json -AsHashtable
  [IO.File]::WriteAllText($sourceData, $valid.Replace('Reviewed CPU', 'AMD Ryzen AI Max+ 395'))
  & $pull -SpecsRepo $source -Root $rendering
  $readable = [IO.File]::ReadAllText($targetData)
  Assert-PullCheck (($readable | ConvertFrom-Json -AsHashtable).dual.cpu_model -ceq 'AMD Ryzen AI Max+ 395' -and $readable.Contains('"cpu_model": "AMD Ryzen AI Max+ 395"')) 'Pull changed or escaped the processor model'
  [IO.File]::WriteAllText($sourceData, $valid)
  & $pull -SpecsRepo $source -Root $rendering
  Assert-PullCheck ($output.dual.ethernet_ports_mbps.Count -eq 2 -and $output.none.ethernet_ports_mbps.Count -eq 0 -and $null -eq $output.unknown.ethernet_ports_mbps -and -not $output.omitted.Contains('ethernet_ports_mbps')) 'Pull lost port counts or unknown/omitted/empty-array semantics'
  Assert-PullCheck (-not $output.dual.Contains('evidence') -and -not $output.dual.Contains('date')) 'Pull leaked research metadata'
  Assert-PullCheck ([IO.File]::ReadAllText($sourceData) -ceq $valid) 'Pull changed the research source'
  $saved = [IO.File]::ReadAllText($targetData)
  & $pull -SpecsRepo $source -Root $rendering
  Assert-PullCheck ([IO.File]::ReadAllText($targetData) -ceq $saved) 'Repeated pull changed the output'
  foreach ($bad in @('{invalid', '[]', '{"dual":{"cpu_model":"one","cpu_model":"two"}}', $valid.Replace('"status":"reviewed"', '"status":"candidate"'), '{"dual":{"ethernet_ports_mbps":[2500]}}', $valid.Replace('[2500,2500]', '[500]'), $valid.Replace('"dual":', '"unknown-id":'))) {
    [IO.File]::WriteAllText($sourceData, $bad)
    Assert-PullRejected { & $pull -SpecsRepo $source -Root $rendering }
  }
  [IO.File]::WriteAllText($sourceData, $valid)
  $originalSchema = [IO.File]::ReadAllText($sourceSchema)
  [IO.File]::WriteAllText($sourceSchema, '{invalid')
  Assert-PullRejected { & $pull -SpecsRepo $source -Root $rendering }
  [IO.File]::Delete($sourceSchema)
  Assert-PullRejected { & $pull -SpecsRepo $source -Root $rendering }
  [IO.File]::WriteAllText($sourceSchema, $originalSchema, [Text.UTF8Encoding]::new($true))
  & $pull -SpecsRepo $source -Root $rendering
  Assert-PullCheck ((Get-FileHash $sourceSchema).Hash -eq (Get-FileHash $targetSchema).Hash) 'Pull did not preserve the schema bytes'
  $schema = $originalSchema | ConvertFrom-Json -AsHashtable
  $schema.additionalProperties.properties['memory_type'] = @{ type = 'string' }
  $schema | ConvertTo-Json -Depth 30 | Set-Content -Encoding utf8NoBOM $sourceSchema
  [IO.File]::WriteAllText($sourceData, '{"dual":{"memory_type":"DDR5","evidence":{"memory_type":{"status":"reviewed"}}}}')
  & $pull -SpecsRepo $source -Root $rendering
  $output = Get-Content -Raw $targetData | ConvertFrom-Json -AsHashtable
  Assert-PullCheck ($output.dual.memory_type -ceq 'DDR5') 'Projection ignored a field from the supplied public schema'
  $saved = [IO.File]::ReadAllText($targetData)
  $schemaBeforeFailure = [IO.File]::ReadAllBytes($targetSchema)
  [IO.File]::Delete($targetSchema)
  [void][IO.Directory]::CreateDirectory($targetSchema)
  [IO.File]::WriteAllText($sourceData, '{"dual":{"memory_type":"DDR4","evidence":{"memory_type":{"status":"reviewed"}}}}')
  $failed = $false
  try { & $pull -SpecsRepo $source -Root $rendering } catch { $failed = $true }
  Assert-PullCheck ($failed -and [IO.File]::ReadAllText($targetData) -ceq $saved -and [IO.Directory]::Exists($targetSchema)) 'Second-file installation failure did not restore the first file'
  [IO.Directory]::Delete($targetSchema)
  [IO.File]::WriteAllBytes($targetSchema, $schemaBeforeFailure)
  Write-Output 'Spec pull checks passed: review gate, schema-driven projection, metadata stripping, validation, idempotence and failure rollback.'
} finally { [IO.Directory]::Delete($temporary, $true) }
