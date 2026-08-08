# supabase/tests/communication_edge_runtime_test.ps1
# Phase 9 Communication Edge Runtime Integration Test Suite

$SUPABASE_URL  = "http://127.0.0.1:15431"
$ANON_KEY      = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"
$SERVICE_KEY   = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"

$passed = 0
$failed = 0
$total  = 0

function Assert-Test($condition, $name) {
    $script:total++
    if ($condition) {
        $script:passed++
        Write-Host "  PASS [$script:total] $name" -ForegroundColor Green
    } else {
        $script:failed++
        Write-Host "  FAIL [$script:total] $name" -ForegroundColor Red
    }
}

function Get-UserToken($email, $password = "Password123!") {
    $body = @{ email = $email; password = $password } | ConvertTo-Json
    try {
        $res = Invoke-RestMethod -Uri "$SUPABASE_URL/auth/v1/token?grant_type=password" `
            -Method Post -Headers @{ "apikey" = $ANON_KEY } -ContentType "application/json" -Body $body
        return "Bearer $($res.access_token)"
    } catch {
        return $null
    }
}

function Invoke-Api($url, $method = "GET", $headers = @{}, $body = $null) {
    $h = @{ "Content-Type" = "application/json"; "apikey" = $ANON_KEY }
    if ($headers) { foreach ($k in $headers.Keys) { $h[$k] = $headers[$k] } }
    $b = if ($body -is [string]) { $body } elseif ($body) { $body | ConvertTo-Json -Depth 10 } else { $null }

    try {
        $r = Invoke-WebRequest -Uri $url -Method $method -Headers $h -Body $b -UseBasicParsing
        $json = $null
        if ($r.Content) { try { $json = $r.Content | ConvertFrom-Json } catch {} }
        return @{ status = $r.StatusCode; content = $r.Content; json = $json }
    } catch [System.Net.WebException] {
        $resp = $_.Exception.Response
        if ($resp) {
            $statusCode = [int]$resp.StatusCode
            $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
            $str = $reader.ReadToEnd()
            $json = $null
            if ($str) { try { $json = $str | ConvertFrom-Json } catch {} }
            return @{ status = $statusCode; content = $str; json = $json }
        }
        return @{ status = 500; content = $_.Exception.Message; json = $null }
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Phase 9 - Communication Edge Runtime Integration Tests"   -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$teacherJwt = Get-UserToken "teacher@academy.com"
$studentJwt = Get-UserToken "student@academy.com"
$adminJwt   = Get-UserToken "admin@academy.com"
$parentJwt  = Get-UserToken "parent@academy.com"

Assert-Test ($teacherJwt -ne $null) "Teacher auth token obtained"
Assert-Test ($studentJwt -ne $null) "Student auth token obtained"
Assert-Test ($adminJwt -ne $null)   "Admin auth token obtained"

$studentUserId = "00000000-0000-0000-0000-000000000106"
$teacherUserId = "00000000-0000-0000-0000-000000000104"

# --- GROUP A: Direct Message Uniqueness & Concurrency ---
Write-Host "`n--- GROUP A: Direct Message Uniqueness & Concurrency ---" -ForegroundColor Yellow
$rA1 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/get_or_create_direct_conversation" "POST" @{} (@{ p_other_user_id = $studentUserId })
Assert-Test ($rA1.status -eq 401) "A1 - Unauthenticated get_or_create_direct_conversation -> 401"

$rA2 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/get_or_create_direct_conversation" "POST" @{ Authorization = $teacherJwt } (@{ p_other_user_id = $studentUserId })
Assert-Test ($rA2.status -eq 200 -and $rA2.json.success -eq $true) "A2 - Teacher get_or_create_direct_conversation(Student) -> 200"
$convId = $rA2.json.conversation_id

$rA3 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/get_or_create_direct_conversation" "POST" @{ Authorization = $studentJwt } (@{ p_other_user_id = $teacherUserId })
Assert-Test ($rA3.status -eq 200 -and $rA3.json.conversation_id -eq $convId) "A3 - Student get_or_create_direct_conversation(Teacher) returns SAME canonical conversation_id"

$rA4 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/get_or_create_direct_conversation" "POST" @{ Authorization = $studentJwt } (@{ p_other_user_id = $studentUserId })
Assert-Test ($rA4.status -eq 400 -or $rA4.status -eq 500) "A4 - Self DM creation rejected"

# --- GROUP B: Message Creation & Sender Security ---
Write-Host "`n--- GROUP B: Message Creation & Sender Security ---" -ForegroundColor Yellow
$rB1 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/send_message" "POST" @{} (@{ p_conversation_id = $convId; p_text = "Test" })
Assert-Test ($rB1.status -eq 401) "B1 - Unauthenticated send_message -> 401"

$rB2 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/send_message" "POST" @{ Authorization = $parentJwt } (@{ p_conversation_id = $convId; p_text = "Intruder message" })
Assert-Test ($rB2.status -eq 403 -or $rB2.status -eq 400 -or $rB2.status -eq 500) "B2 - Unrelated parent send_message to conversation -> rejected"

$rB3 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/send_message" "POST" @{ Authorization = $teacherJwt } (@{ p_conversation_id = $convId; p_text = "Hello Student! Integration Test Message." })
Assert-Test ($rB3.status -eq 200 -and $rB3.json.success -eq $true) "B3 - Active member send_message -> 200"
$msgId = $rB3.json.message_id
Assert-Test ($rB3.json.sender_id -eq $teacherUserId) "B3 - Sender ID derived strictly from auth.uid()"

$rB4 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/send_message" "POST" @{ Authorization = $teacherJwt } (@{ p_conversation_id = $convId; p_text = "   " })
Assert-Test ($rB4.status -eq 400 -or $rB4.status -eq 500) "B4 - Empty text content rejected"

# --- GROUP C: Read Receipts & Unread Count ---
Write-Host "`n--- GROUP C: Read Receipts & Unread Count ---" -ForegroundColor Yellow
$rC0 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/mark_conversation_read" "POST" @{ Authorization = $teacherJwt } (@{ p_conversation_id = $convId; p_message_id = $msgId })

$rC1 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/get_conversation_unread_count" "POST" @{ Authorization = $teacherJwt } (@{ p_conversation_id = $convId })
Assert-Test ($rC1.status -eq 200 -and ($rC1.content -eq "0" -or $rC1.json -eq 0)) "C1 - Sender unread count after reading = 0"

$rC2 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/get_conversation_unread_count" "POST" @{ Authorization = $studentJwt } (@{ p_conversation_id = $convId })
Assert-Test ($rC2.status -eq 200 -and ([int]$rC2.content -gt 0 -or $rC2.json -gt 0)) "C2 - Recipient unread count > 0"

$rC3 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/mark_conversation_read" "POST" @{ Authorization = $studentJwt } (@{ p_conversation_id = $convId; p_message_id = $msgId })
Assert-Test ($rC3.status -eq 200 -and $rC3.json.success -eq $true) "C3 - Recipient mark_conversation_read -> 200"

$rC4 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/get_conversation_unread_count" "POST" @{ Authorization = $studentJwt } (@{ p_conversation_id = $convId })
Assert-Test ($rC4.status -eq 200 -and ($rC4.content -eq "0" -or $rC4.json -eq 0)) "C4 - Recipient unread count after reading = 0"

# --- GROUP D: Announcement Targeting & Acknowledgement ---
Write-Host "`n--- GROUP D: Announcement Targeting & Acknowledgement ---" -ForegroundColor Yellow
$rD1 = Invoke-Api "$SUPABASE_URL/rest/v1/announcements?select=*,announcement_targets(*)" "GET" @{ Authorization = $studentJwt }
Assert-Test ($rD1.status -eq 200) "D1 - Student fetch targeted announcements -> 200"

$urgentAnnId = "e6000000-0000-0000-0000-000000000002"
$rD2 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/acknowledge_announcement" "POST" @{ Authorization = $studentJwt } (@{ p_announcement_id = $urgentAnnId })
Assert-Test ($rD2.status -eq 200 -and $rD2.json.success -eq $true) "D2 - Student acknowledge urgent announcement -> 200"

$rD3 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/publish_announcement" "POST" @{ Authorization = $studentJwt } (@{ p_announcement_id = "e6000000-0000-0000-0000-000000000003" })
Assert-Test ($rD3.status -eq 403 -or $rD3.status -eq 400 -or $rD3.status -eq 500) "D3 - Non-admin publish_announcement -> rejected"

$rD4 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/publish_announcement" "POST" @{ Authorization = $adminJwt } (@{ p_announcement_id = "e6000000-0000-0000-0000-000000000003" })
Assert-Test ($rD4.status -eq 200 -and $rD4.json.success -eq $true) "D4 - Admin publish_announcement -> 200"

# --- GROUP E: In-App Notifications & RLS ---
Write-Host "`n--- GROUP E: In-App Notifications & RLS ---" -ForegroundColor Yellow
$rE1 = Invoke-Api "$SUPABASE_URL/rest/v1/notifications" "GET" @{ Authorization = $studentJwt }
Assert-Test ($rE1.status -eq 200) "E1 - Student fetch own notifications -> 200"

$rE2 = Invoke-Api "$SUPABASE_URL/rest/v1/rpc/mark_all_notifications_read" "POST" @{ Authorization = $studentJwt } @{}
Assert-Test ($rE2.status -eq 200 -and $rE2.json.success -eq $true) "E2 - Student mark_all_notifications_read -> 200"

# --- SUMMARY ---
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "  Phase 9 Integration Test Results"                 -ForegroundColor Cyan
Write-Host "  Total:  $script:total"                            -ForegroundColor Cyan
Write-Host "  Passed: $script:passed"                           -ForegroundColor Green
Write-Host "  Failed: $script:failed"                           -ForegroundColor Red
Write-Host "==================================================" -ForegroundColor Cyan

if ($script:failed -gt 0) {
    exit 1
}
