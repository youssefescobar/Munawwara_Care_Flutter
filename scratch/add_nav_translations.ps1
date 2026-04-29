
$languages = @("en", "ar", "fr", "tr", "id", "ur")
$translations = @{
    "en" = @{
        "nav_groups" = "GROUPS";
        "nav_provisioning" = "PROVISIONING";
        "nav_reminders" = "REMINDERS";
        "nav_profile" = "PROFILE"
    };
    "ar" = @{
        "nav_groups" = "المجموعات";
        "nav_provisioning" = "التجهيز";
        "nav_reminders" = "التذكيرات";
        "nav_profile" = "الملف الشخصي"
    };
    "fr" = @{
        "nav_groups" = "GROUPES";
        "nav_provisioning" = "PROVISIONNEMENT";
        "nav_reminders" = "RAPPELS";
        "nav_profile" = "PROFIL"
    };
    "tr" = @{
        "nav_groups" = "GRUPLAR";
        "nav_provisioning" = "HAZIRLIK";
        "nav_reminders" = "HATIRLATICILAR";
        "nav_profile" = "PROFİL"
    };
    "id" = @{
        "nav_groups" = "GRUP";
        "nav_provisioning" = "PROVISI";
        "nav_reminders" = "PENGINGAT";
        "nav_profile" = "PROFIL"
    };
    "ur" = @{
        "nav_groups" = "گروپس";
        "nav_provisioning" = "فراہمی";
        "nav_reminders" = "یاد دہانیاں";
        "nav_profile" = "پروفائل"
    }
}

foreach ($lang in $languages) {
    $path = "c:\Users\drago\Desktop\projects\Durrah care mob app\Flutter_Munawwara\assets\translations\$lang.json"
    if (Test-Path $path) {
        $content = Get-Content $path -Raw | ConvertFrom-Json -AsHashtable
        foreach ($key in $translations[$lang].Keys) {
            $content[$key] = $translations[$lang][$key]
        }
        $json = $content | ConvertTo-Json -Depth 100
        # Fix encoding issues if necessary, but ConvertTo-Json usually works if piped correctly
        # We need to ensure UTF-8 without BOM if possible, or just standard UTF8
        [System.IO.File]::WriteAllText($path, $json, [System.Text.Encoding]::UTF8)
        Write-Host "Updated $lang.json"
    }
}
