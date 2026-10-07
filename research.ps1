#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Question,
    [string[]]$Domains = @('docs.python.org'),
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
if ([string]::IsNullOrWhiteSpace($Question)) { throw '질문을 입력하세요.' }
if ($Domains.Count -eq 0) { throw '공식 문서 도메인이 필요합니다.' }
$Domains = @($Domains | ForEach-Object {
    $domain = $_.Trim().ToLowerInvariant()
    if ($domain -notmatch '^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$') {
        throw "도메인은 URL이나 경로 없이 입력하세요: $domain"
    }
    $domain
} | Select-Object -Unique)

$role = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'agents/research.md') -Raw
$skill = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'skills/official-docs-search/SKILL.md') -Raw
$request = @{ question = $Question; allowed_domains = $Domains } | ConvertTo-Json -Depth 3
$prompt = @"
$role

이번 실행에 사용할 스킬의 전체 내용:
$skill

조사 요청 (JSON 데이터):
$request
"@
if ($DryRun) { $prompt; return }

$codex = Get-Command codex -ErrorAction Stop
$runId = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
$runDir = Join-Path $PSScriptRoot "runs/$runId"
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$prompt | Set-Content -LiteralPath (Join-Path $runDir 'prompt.md') -Encoding utf8
$request | Set-Content -LiteralPath (Join-Path $runDir 'request.json') -Encoding utf8
$candidate = Join-Path $runDir 'response.md'
$events = Join-Path $runDir 'events.jsonl'
$stderr = Join-Path $runDir 'stderr.log'
$metadata = [ordered]@{ status = 'running'; started_at = [DateTime]::UtcNow.ToString('o'); run_id = $runId }
$metadataPath = Join-Path $runDir 'run.json'
$metadata | ConvertTo-Json | Set-Content -LiteralPath $metadataPath -Encoding utf8

# The skill is loaded above, rather than relying on machine-specific skill installation.
# Codex supplies the model/tool loop; this wrapper only supplies context and saves evidence.
$codexArgs = @('exec', '--cd', $PSScriptRoot, '--sandbox', 'read-only',
    '--ephemeral', '--json', '--color', 'never',
    '-c', 'web_search="live"', '-c', 'features.shell_tool=false',
    '-c', 'features.multi_agent=false', '--output-last-message', $candidate, '-')
try {
    Write-Host "조사 실행 중. 기록: $runDir"
    $prompt | & $codex @codexArgs 2> $stderr | Set-Content -LiteralPath $events -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw "Codex 실행 실패 (exit $LASTEXITCODE). stderr.log를 확인하세요." }
    if (!(Test-Path -LiteralPath $candidate) -or [string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $candidate -Raw))) {
        throw 'Codex가 최종 응답을 남기지 않았습니다.'
    }
    # A returned answer is not proof of correct research. Keep this explicit in the status.
    $metadata.status = 'needs_review'
    Write-Host "응답 저장 완료: $candidate (검색·본문 열람·근거 일치는 사람이 확인해야 합니다.)"
} catch {
    $metadata.status = 'failed'
    $metadata.error = $_.Exception.Message
    throw
} finally {
    $metadata.finished_at = [DateTime]::UtcNow.ToString('o')
    $metadata | ConvertTo-Json | Set-Content -LiteralPath $metadataPath -Encoding utf8
}
