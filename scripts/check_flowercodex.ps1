param(
  [string]$FilePath = "flowercodex.html"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-Issue {
  param(
    [System.Collections.Generic.List[string]]$Issues,
    [string]$Message
  )
  $Issues.Add($Message) | Out-Null
}

function Get-TagCount {
  param(
    [string]$Text,
    [string]$TagName,
    [switch]$Open
  )

  if ($Open) {
    return ([regex]::Matches($Text, "<$TagName(\s|>)", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
  }

  return ([regex]::Matches($Text, "</$TagName>", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
}

function Test-LineQuoteBalance {
  param([string]$Line)

  $trim = $Line.Trim()
  if ($trim -eq "") { return $true }
  if ($trim -match '^\s*//') { return $true }
  if ($trim -match '^\s*/\*') { return $true }
  if ($trim -match '^\s*\*') { return $true }
  if ($trim -match '\*/\s*$') { return $true }
  if ($trim -match '\.replace\(/"/g') { return $true }

  $doubleQuotes = ([regex]::Matches($Line, '(?<!\\)"')).Count
  $singleQuotes = ([regex]::Matches($Line, "(?<!\\)'")).Count

  return (($doubleQuotes % 2) -eq 0) -and (($singleQuotes % 2) -eq 0)
}

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if (-not [System.IO.Path]::IsPathRooted($FilePath)) {
  $FilePath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $FilePath))
}

if (-not (Test-Path -LiteralPath $FilePath)) {
  throw "File not found: $FilePath"
}

$issues = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

$text = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
$lines = [System.IO.File]::ReadAllLines($FilePath, [System.Text.Encoding]::UTF8)

# 1) Broken character detection
$badCharMatches = [regex]::Matches($text, '�')
if ($badCharMatches.Count -gt 0) {
  Add-Issue -Issues $issues -Message ("Found replacement-char '�': {0} occurrence(s)." -f $badCharMatches.Count)
}

# 2) Basic HTML tag balance checks (quick and practical)
$tagsToCheck = @("h1", "h2", "p", "button", "span", "option")
foreach ($tag in $tagsToCheck) {
  $openCount = Get-TagCount -Text $text -TagName $tag -Open
  $closeCount = Get-TagCount -Text $text -TagName $tag
  if ($openCount -ne $closeCount) {
    Add-Issue -Issues $issues -Message ("Tag mismatch <{0}>: open={1}, close={2}" -f $tag, $openCount, $closeCount)
  }
}

# 3) Extract main inline script and validate simple JS structural balance
$scriptMatches = [regex]::Matches($text, '<script>([\s\S]*?)</script>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
if ($scriptMatches.Count -eq 0) {
  Add-Issue -Issues $issues -Message "Inline <script>...</script> block not found."
} else {
  $scriptMatch = $scriptMatches |
    Sort-Object { $_.Groups[1].Value.Length } -Descending |
    Select-Object -First 1
  $scriptBody = $scriptMatch.Groups[1].Value

  $openCurly = ($scriptBody.ToCharArray() | Where-Object { $_ -eq '{' } | Measure-Object).Count
  $closeCurly = ($scriptBody.ToCharArray() | Where-Object { $_ -eq '}' } | Measure-Object).Count
  if ($openCurly -ne $closeCurly) {
    Add-Issue -Issues $issues -Message ("Script brace mismatch: '{'={0}, '}'={1}" -f $openCurly, $closeCurly)
  }

  $openParen = ($scriptBody.ToCharArray() | Where-Object { $_ -eq '(' } | Measure-Object).Count
  $closeParen = ($scriptBody.ToCharArray() | Where-Object { $_ -eq ')' } | Measure-Object).Count
  if ($openParen -ne $closeParen) {
    Add-Issue -Issues $issues -Message ("Script paren mismatch: '('={0}, ')'={1}" -f $openParen, $closeParen)
  }

  $scriptStartLine = 0
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i].Trim() -eq "<script>") {
      $scriptStartLine = $i + 1
      break
    }
  }
  if ($scriptStartLine -gt 0) {
    $scriptEndLine = 0
    for ($i = $scriptStartLine; $i -lt $lines.Length; $i++) {
      if ($lines[$i].Trim() -eq "</script>") {
        $scriptEndLine = $i + 1
        break
      }
    }

    if ($scriptEndLine -gt $scriptStartLine) {
      for ($lineNo = $scriptStartLine + 1; $lineNo -lt $scriptEndLine; $lineNo++) {
        $line = $lines[$lineNo - 1]
        if (-not (Test-LineQuoteBalance -Line $line)) {
          Add-Issue -Issues $issues -Message ("Possible broken quote at line {0}: {1}" -f $lineNo, $line.Trim())
        }
      }
    }
  }
}

# 4) Practical warning: very large file can be hard to maintain
$sizeKb = [Math]::Round((Get-Item -LiteralPath $FilePath).Length / 1KB, 1)
if ($sizeKb -gt 120) {
  $warnings.Add(("File size is {0}KB. Consider splitting HTML/CSS/JS later for safety." -f $sizeKb)) | Out-Null
}

# 5) External image policy check (Pexels-only for external URLs)
function Test-ExternalImagePolicy {
  param(
    [string]$TargetPath,
    [string]$TargetText
  )

  $matches = [regex]::Matches(
    $TargetText,
    '"image"\s*:\s*"(?<url>https?://[^"]+)"',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
  )

  foreach ($m in $matches) {
    $url = $m.Groups["url"].Value
    $allowed = $url -match '^https://images\.pexels\.com/' -or $url -match '^https://www\.pexels\.com/'
    if (-not $allowed) {
      Add-Issue -Issues $issues -Message ("Disallowed external image URL in {0}: {1}" -f $TargetPath, $url)
    }
  }
}

Test-ExternalImagePolicy -TargetPath $FilePath -TargetText $text
$flowersJsPath = Join-Path $projectRoot "data/flowers.js"
if (Test-Path -LiteralPath $flowersJsPath) {
  $flowersJsText = [System.IO.File]::ReadAllText($flowersJsPath, [System.Text.Encoding]::UTF8)
  Test-ExternalImagePolicy -TargetPath $flowersJsPath -TargetText $flowersJsText
}

if ($issues.Count -gt 0) {
  Write-Host "flowercodex check: FAILED" -ForegroundColor Red
  Write-Host ("Target: {0}" -f $FilePath)
  foreach ($issue in $issues) {
    Write-Host (" - {0}" -f $issue) -ForegroundColor Red
  }
  if ($warnings.Count -gt 0) {
    foreach ($w in $warnings) {
      Write-Host (" - WARN: {0}" -f $w) -ForegroundColor Yellow
    }
  }
  exit 1
}

Write-Host "flowercodex check: OK" -ForegroundColor Green
Write-Host ("Target: {0}" -f $FilePath)
if ($warnings.Count -gt 0) {
  foreach ($w in $warnings) {
    Write-Host (" - WARN: {0}" -f $w) -ForegroundColor Yellow
  }
}
