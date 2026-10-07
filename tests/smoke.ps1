#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$runner = Join-Path $project 'research.ps1'
$global:researchTestMode = 'ok'
$global:researchTestCalls = 0

# This fake CLI tests the wrapper only. It never calls a model or the internet.
function codex {
    $global:researchTestCalls++
    $received = @($input) -join "`n"
    if (!$received.Contains('공식') -or !$received.Contains('allowed_domains')) { throw 'Missing research context' }
    $outputIndex = [array]::IndexOf($args, '--output-last-message')
    $destination = $args[$outputIndex + 1]
    $global:researchTestLastRun = Split-Path $destination -Parent
    if ($global:researchTestMode -eq 'ok') {
        '# MOCK response — not real research' | Set-Content -LiteralPath $destination
    }
    '{"type":"turn.completed","mock":true}'
    $global:LASTEXITCODE = $(if ($global:researchTestMode -eq 'fail') { 9 } else { 0 })
}

function Assert([bool]$Condition, [string]$Message) {
    if (!$Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}

$preview = & $runner -Question '한글 질문; $(명령이 아니다)' -DryRun
Assert ($global:researchTestCalls -eq 0 -and $preview.Contains('$(명령이 아니다)')) 'DryRun preserves question as data without invoking CLI'
$rejected = $false
try { & $runner -Question '질문' -Domains @('https://docs.python.org/') -DryRun } catch { $rejected = $true }
Assert $rejected 'URL supplied as a domain is rejected'

& $runner -Question '테스트 질문'
$firstRun = $global:researchTestLastRun
$metadata = Get-Content -LiteralPath (Join-Path $firstRun 'run.json') -Raw | ConvertFrom-Json
Assert ($metadata.status -eq 'needs_review') 'Returned answer is saved as unverified'
Assert (Test-Path -LiteralPath (Join-Path $firstRun 'events.jsonl')) 'Execution evidence is saved'

$global:researchTestMode = 'fail'
$rejected = $false
try { & $runner -Question '실패 테스트' } catch { $rejected = $true }
$metadata = Get-Content -LiteralPath (Join-Path $global:researchTestLastRun 'run.json') -Raw | ConvertFrom-Json
Assert ($rejected -and $metadata.status -eq 'failed' -and $global:researchTestLastRun -ne $firstRun) 'CLI failure is recorded in a separate run'

$global:researchTestMode = 'empty'
$rejected = $false
try { & $runner -Question '빈 응답 테스트' } catch { $rejected = $true }
$metadata = Get-Content -LiteralPath (Join-Path $global:researchTestLastRun 'run.json') -Raw | ConvertFrom-Json
Assert ($rejected -and $metadata.status -eq 'failed') 'Empty output cannot count as a completed response'
Write-Host '6 checks passed. MOCK records are in ignored runs/. Live research remains untested.'
