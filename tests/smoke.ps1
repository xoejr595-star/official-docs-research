#requires -Version 7.0
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$runner = Join-Path $project 'research.ps1'
$global:researchTestMode = 'ok'
$global:researchTestCalls = 0
$runsRoot = Join-Path $project 'runs'
function Get-RunNames {
    if (Test-Path -LiteralPath $runsRoot) {
        Get-ChildItem -LiteralPath $runsRoot -Directory | Select-Object -ExpandProperty Name
    }
}

# Simulate command discovery failure without changing the user's PATH or installation.
function Get-Command {
    [CmdletBinding()]
    param([string]$Name)
    if ($Name -eq 'codex' -and $global:researchTestMode -eq 'missing') {
        throw [System.Management.Automation.CommandNotFoundException]::new('MOCK: codex not installed')
    }
    Microsoft.PowerShell.Core\Get-Command @PSBoundParameters
}

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

$beforeDryRun = @(Get-RunNames)
$runsExisted = Test-Path -LiteralPath $runsRoot
$preview = & $runner -Question '한글 질문; $(명령이 아니다)' -DryRun
Assert ($global:researchTestCalls -eq 0 -and $preview.Contains('$(명령이 아니다)')) 'DryRun preserves question as data without invoking CLI'
Assert (($beforeDryRun -join ',') -eq (@(Get-RunNames) -join ',') -and $runsExisted -eq (Test-Path -LiteralPath $runsRoot)) 'DryRun creates no run directory'
$rejected = $false
try { & $runner -Question '질문' -Domains @('https://docs.python.org/') -DryRun } catch { $rejected = $true }
Assert $rejected 'URL supplied as a domain is rejected'

& $runner -Question '테스트 질문: / 경로? $(명령이 아니다)'
$firstRun = $global:researchTestLastRun
$metadata = Get-Content -LiteralPath (Join-Path $firstRun 'run.json') -Raw | ConvertFrom-Json
Assert ($metadata.status -eq 'needs_review') 'Returned answer is saved as unverified'
Assert ((Split-Path $firstRun -Leaf) -match '^\d{8}-\d{6}_테스트-질문-경로-명령이-아니다_[a-f0-9]{8}$') 'Run folder identifies the question and removes unsafe filename characters'
$savedEvents = @(Get-Content -LiteralPath (Join-Path $firstRun 'events.jsonl') | ForEach-Object { $_ | ConvertFrom-Json })
Assert ($savedEvents.Count -eq 1 -and $savedEvents[0].type -eq 'turn.completed' -and $savedEvents[0].mock -eq $true) 'CLI event content is preserved as valid JSONL'
$savedResponse = Get-Content -LiteralPath (Join-Path $firstRun 'response.md') -Raw
Assert ($savedResponse.Trim() -eq '# MOCK response — not real research') 'Final response content is preserved'

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

$global:researchTestMode = 'missing'
$beforeMissing = @(Get-RunNames)
$callsBeforeMissing = $global:researchTestCalls
$rejected = $false
try { & $runner -Question 'CLI 미설치 테스트' } catch { $rejected = $true }
$newRuns = @(Get-RunNames | Where-Object { $_ -notin $beforeMissing })
Assert ($rejected -and $newRuns.Count -eq 1 -and $global:researchTestCalls -eq $callsBeforeMissing) 'Missing CLI creates one failed run without invoking CLI'
$missingDir = Join-Path $runsRoot $newRuns[0]
$metadata = Get-Content -LiteralPath (Join-Path $missingDir 'run.json') -Raw | ConvertFrom-Json
Assert ($metadata.status -eq 'failed' -and $metadata.error -eq 'MOCK: codex not installed' -and $metadata.finished_at) 'Missing CLI error and completion time are recorded'
$global:researchTestMode = 'ok'
& $runner -Question (('긴 질문 ' * 30) + '끝')
$longFolder = Split-Path $global:researchTestLastRun -Leaf
Assert (($longFolder -split '_')[1].Length -le 48) 'Long question titles fit within the folder name limit'
& $runner -Question '???'
Assert ((Split-Path $global:researchTestLastRun -Leaf) -match '^\d{8}-\d{6}_질문_[a-f0-9]{8}$') 'Question without filename letters receives a readable fallback title'
Write-Host '13 checks passed. Tests use a fake CLI; no model or search service is called.'
