# Fix all encoding issues in the payment test harness
$file = 'f:\flutter_application_1\supabase\tests\payment_edge_runtime_test.ps1'
$bytes = [System.IO.File]::ReadAllBytes($file)
$content = [System.Text.Encoding]::UTF8.GetString($bytes)

# Unicode smart quotes -> ASCII
$content = $content -replace [char]0x201C, '"'
$content = $content -replace [char]0x201D, '"'
$content = $content -replace [char]0x2018, "'"
$content = $content -replace [char]0x2019, "'"
# Em-dash -> hyphen
$content = $content -replace [char]0x2014, '-'
# Non-breaking space -> space
$content = $content -replace [char]0x00A0, ' '
# Ellipsis -> ...
$content = $content -replace [char]0x2026, '...'
# Arrow characters -> text
$content = $content -replace [char]0x2192, '->'
# Left/right double angle quotes
$content = $content -replace [char]0x00AB, '<<'
$content = $content -replace [char]0x00BB, '>>'
# Backtick in multi-byte might be odd but leave actual backticks alone

# Write back as pure ASCII-safe UTF-8 without BOM
$enc = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($file, $content, $enc)

# Verify parse
$err = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$err)
if ($err.Count -eq 0) {
    Write-Host "File parsed successfully with 0 errors." -ForegroundColor Green
} else {
    Write-Host "Parse errors remaining: $($err.Count)" -ForegroundColor Red
    foreach ($e in $err) { Write-Host ("  Line $($e.Extent.StartLineNumber): " + $e.Message) }
}
Write-Host "Done. File length: $($content.Length)"
