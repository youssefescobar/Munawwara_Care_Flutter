$keysToAdd = @{
    "area_schedule_title" = "Schedule Meetpoint"
    "area_select_date"    = "Select Date"
    "area_select_time"    = "Select Time"
    "area_reminder_label" = "Reminder"
    "area_reminder_none"  = "None"
    "area_reminder_mins"  = "{} minutes before"
    "msg_meetpoint_at"    = "Meet at {} on {}"
}

$files = Get-ChildItem "assets/translations/*.json"

foreach ($file in $files) {
    Write-Host "Processing $($file.Name)..."
    try {
        $raw = Get-Content $file.FullName -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) { continue }
        $content = $raw | ConvertFrom-Json
        
        $modified = $false
        foreach ($key in $keysToAdd.Keys) {
            if (-not (Get-Member -InputObject $content -Name $key)) {
                $content | Add-Member -MemberType NoteProperty -Name $key -Value $keysToAdd[$key]
                $modified = $true
            }
        }
        
        if ($modified) {
            $json = $content | ConvertTo-Json -Depth 100
            [System.IO.File]::WriteAllText($file.FullName, $json, [System.Text.Encoding]::UTF8)
            Write-Host "Updated $($file.Name)"
        } else {
            Write-Host "No changes needed for $($file.Name)"
        }
    } catch {
        Write-Error "Failed to process $($file.Name): $_"
    }
}
