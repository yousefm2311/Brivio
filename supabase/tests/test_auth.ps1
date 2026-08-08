$ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'

# Test 1: Auth at 15431
try {
    $body = '{"email":"student@academy.com","password":"Password123!"}'
    $headers = @{ apikey = $ANON_KEY; 'Content-Type' = 'application/json' }
    $r = Invoke-WebRequest -Uri 'http://127.0.0.1:15431/auth/v1/token?grant_type=password' `
        -Method POST -Headers $headers -Body $body -UseBasicParsing -ErrorAction Stop
    Write-Host "Auth 15431: OK $($r.StatusCode)"
    $j = $r.Content | ConvertFrom-Json
    Write-Host "Token prefix: $($j.access_token.Substring(0,30))..."
} catch {
    Write-Host "Auth 15431 FAILED: $($_.Exception.Message)"
    try {
        Write-Host "Status: $([int]$_.Exception.Response.StatusCode)"
        $stream = $_.Exception.Response.GetResponseStream()
        $body2 = (New-Object IO.StreamReader($stream)).ReadToEnd()
        Write-Host "Body: $body2"
    } catch {}
}

# Test 2: Try direct REST query
try {
    $headers2 = @{ apikey = $ANON_KEY; Authorization = "Bearer $ANON_KEY" }
    $r2 = Invoke-WebRequest -Uri 'http://127.0.0.1:15431/rest/v1/profiles?limit=1' `
        -Method GET -Headers $headers2 -UseBasicParsing -ErrorAction Stop
    Write-Host "REST 15431: OK $($r2.StatusCode)"
} catch {
    Write-Host "REST 15431 FAILED: $($_.Exception.Message)"
}
