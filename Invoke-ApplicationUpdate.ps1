# Install required modules
Install-Module -Name WinTuner -Force
Import-Module WinTuner

# Apps in library
$apps = Get-Content -Path .\apps.json -Raw | ConvertFrom-Json

# Apps in Intune
$apps_intune = Get-WtWin32Apps -Superseded $false

function Write-Status ($Status) {
    switch -Exact ($status.Result) {
        "OK" {
            if ($null -ne $Status.Message) {
                Write-Verbose -Message $status.Message
            }
            
            Write-Host "$($status.Name): $($status.AppStatus)"
        }
        "ERROR" { 
            Write-Error -Message $status.Message
            Write-Host "$($status.Name): ERROR"
        }
        Default { Write-Error -Message "Unspecified Status: $($status.Result)" }
    }
}

# Loop trough apps in library
foreach ($app in $apps) {
    $in_app = $apps_intune | Where-Object PackageId -eq $app.Name
   
    # If app is not in Intune, then deploy it
    if ($null -eq $in_app) {
        $status = [PSCustomObject]@{
            Name      = $app.Name
            AppStatus = "NOT FOUND"
            Result    = $null
            Message   = $null
        }
        try {
            $deployed = New-WtWingetPackage -PackageId $app.Name -PackageFolder .\packages | Deploy-WtWin32App
            $result = Update-WtIntuneApp -AppId $deployed.Id -Categories $app.Category -AvailableFor $app.AvailableFor
            $status.Message = $result
            $status.Result = "OK"
        }
        catch {
            $status.Message = $_
            $status.Result = "ERROR"
        }
        finally {
            Write-Status -Status $status
        }
        
    }
    else {
        # If app is in Intune and has an update available, then deploy it and supersed it
        if ($in_app.IsUpdateAvailable -eq $true) {
            $status = [PSCustomObject]@{
                Name      = $in_app.PackageId
                AppStatus = "UPDATE AVAILABLE"
                Result    = $null
                Message   = $null
            }
            try {
                $in_app
                $result = New-WtWingetPackage -PackageId $app.Name -PackageFolder .\packages | Deploy-WtWin32App -GraphId $in_app.GraphId
                $status.Message = $result
                $status.Result = "OK"
            }
            catch {
                $status.Message = $_
                $status.Result = "ERROR"
            }
            finally {
                Write-Status -Status $status
            }
        }
        else {
            $status = [PSCustomObject]@{
                Name      = $in_app.PackageId
                AppStatus = "CURRENT"
                Result    = "OK"
                Message   = $null
            }
            Write-Status -Status $status
        }
    }
}

# Remove superseded apps
$old_apps = Get-WtWin32Apps -Superseded $true
foreach ($old_app in $old_apps) {
    try {
        Remove-WtWin32App -AppId $old_app.GraphId
    }
    catch {
        # Ignore
    }
}
try {
    # Remove package folder
    Remove-Item ".\packages" -Recurse
}
catch {
    # Ignore
}
