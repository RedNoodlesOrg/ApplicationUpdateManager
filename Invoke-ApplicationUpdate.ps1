# Install required modules
Install-Module -Name WinTuner -Force
Import-Module WinTuner

# Apps in library
$apps = Get-Content -Path .\apps.json -Raw | ConvertFrom-Json

# Apps in Intune
$apps_intune = Get-WtWin32Apps

# Loop trough apps in library
foreach ($app in $apps) {
    $in_app = $apps_intune | Where-Object PackageId -eq $app.Name
   
    # If app is not in Intune, then deploy it
    if ($null -eq $in_app) {
        [PSCustomObject]@{
            Name   = $app.Name
            Status = "NOT FOUND"
        }
        $result = New-WtWingetPackage -PackageId $app.Name -PackageFolder .\packages | Deploy-WtWin32App
        Update-WtIntuneApp -AppId $result.Id -Categories $app.Category -AvailableFor $app.AvailableFor
    }
    else {
        # If app is in Intune and has an update available, then deploy it and supersed it
        if ($in_app.IsUpdateAvailable -eq $true) {
            [PSCustomObject]@{
                Name   = $in_app.PackageId
                Status = "UPDATE AVAILABLE"
            }
            New-WtWingetPackage -PackageId $app.Name -PackageFolder .\packages | Deploy-WtWin32App -GraphId $in_app.GraphId
        }
        else {
            [PSCustomObject]@{
                Name   = $in_app.PackageId
                Status = "CURRENT"
            }
        }
    }
}

# Remove superseded apps
$old_apps = Get-WtWin32Apps -Superseded $true
foreach ($old_app in $old_apps) {
    Remove-WtWin32App -AppId $old_app.GraphId
}

# Remove package folder
Remove-Item ".\packages" -Recurse