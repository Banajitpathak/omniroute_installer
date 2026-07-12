Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$global:logQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()

function Queue-Log {
    param([string]$Message, [bool]$IsHiddenProcess = $false)
    $time = Get-Date -Format 'HH:mm:ss'
    if ($IsHiddenProcess) {
        $global:logQueue.Enqueue("HIDDEN|$time - $Message")
    } else {
        $global:logQueue.Enqueue("MAIN|$time - $Message")
    }
}

function Test-PortActive {
    param([int]$Port)
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $connection = $tcp.BeginConnect("127.0.0.1", $Port, $null, $null)
        $success = $connection.AsyncWaitHandle.WaitOne(100) # 100ms timeout
        if ($success) {
            $tcp.EndConnect($connection)
            return $true
        }
    } catch {} finally {
        $tcp.Close()
    }
    return $false
}

function Start-HiddenProcess {
    param(
        [string]$FilePath,
        [string]$ArgumentList,
        [string]$WorkingDirectory = $null
    )
    $procInfo = New-Object System.Diagnostics.ProcessStartInfo
    $procInfo.FileName = $FilePath
    $procInfo.Arguments = $ArgumentList
    $procInfo.RedirectStandardOutput = $true
    $procInfo.RedirectStandardError = $true
    $procInfo.UseShellExecute = $false
    $procInfo.CreateNoWindow = $true
    if ($WorkingDirectory) { $procInfo.WorkingDirectory = $WorkingDirectory }

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $procInfo

    $outEvent = Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action {
        if ($Event.SourceEventArgs.Data) { Queue-Log $Event.SourceEventArgs.Data $true }
    }
    $errEvent = Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived -Action {
        if ($Event.SourceEventArgs.Data) { Queue-Log $Event.SourceEventArgs.Data $true }
    }

    $proc.Start() | Out-Null
    $proc.BeginOutputReadLine()
    $proc.BeginErrorReadLine()

    return @{ Process = $proc; OutEvent = $outEvent; ErrEvent = $errEvent }
}

function Wait-HiddenProcess {
    param($ProcObj)
    while (-not $ProcObj.Process.HasExited) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 50
    }
    Unregister-Event -SourceIdentifier $ProcObj.OutEvent.Name
    Unregister-Event -SourceIdentifier $ProcObj.ErrEvent.Name
    return $ProcObj.Process.ExitCode
}

# --- Form Setup (ELEGANT DARK MODE) ---
$form = New-Object System.Windows.Forms.Form
$form.Text = 'OmniRoute Dashboard'
$form.ClientSize = New-Object System.Drawing.Size(530, 680)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#181818")
$form.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#E0E0E0")
$font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Font = $font

# --- UI Helper ---
function Format-Button {
    param($btn)
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
}

function Set-ButtonState {
    param($btn, $isEnabled, $activeColor = "#2D2D30", $activeTextColor = "#FFFFFF")
    $btn.Tag = $isEnabled
    $btn.Enabled = $true
    if ($isEnabled) {
        $btn.BackColor = [System.Drawing.ColorTranslator]::FromHtml($activeColor)
        $btn.ForeColor = [System.Drawing.ColorTranslator]::FromHtml($activeTextColor)
        $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    } else {
        $btn.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#252525")
        $btn.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#888888")
        $btn.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

# --- UI Elements ---
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(20,20)
$lblStatus.Size = New-Object System.Drawing.Size(490,25)
$lblStatus.Text = "Status: Ready"
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)
$form.Controls.Add($lblStatus)

$lblInstallDir = New-Object System.Windows.Forms.Label
$lblInstallDir.Location = New-Object System.Drawing.Point(20,52)
$lblInstallDir.Size = New-Object System.Drawing.Size(120,25)
$lblInstallDir.Text = "Install Directory:"
$form.Controls.Add($lblInstallDir)

$txtInstallDir = New-Object System.Windows.Forms.TextBox
$txtInstallDir.Location = New-Object System.Drawing.Point(140,50)
$txtInstallDir.Size = New-Object System.Drawing.Size(280,25)
$txtInstallDir.Text = "C:\omniroute"
$txtInstallDir.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#2D2D30")
$txtInstallDir.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
$txtInstallDir.BorderStyle = 'FixedSingle'
$txtInstallDir.Add_TextChanged({ Update-UIState })
$form.Controls.Add($txtInstallDir)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Location = New-Object System.Drawing.Point(430,49)
$btnBrowse.Size = New-Object System.Drawing.Size(80,27)
$btnBrowse.Text = "Browse"
Format-Button $btnBrowse
Set-ButtonState $btnBrowse $true "#333337" "#FFFFFF"
$btnBrowse.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtInstallDir.Text = $dialog.SelectedPath
        Update-UIState
    }
})
$form.Controls.Add($btnBrowse)

$btnSmart = New-Object System.Windows.Forms.Button
$btnSmart.Location = New-Object System.Drawing.Point(20,90)
$btnSmart.Size = New-Object System.Drawing.Size(490,60)
$btnSmart.Text = "Install & Start OmniRoute"
$btnSmart.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
Format-Button $btnSmart
$form.Controls.Add($btnSmart)

$btnOpen = New-Object System.Windows.Forms.Button
$btnOpen.Location = New-Object System.Drawing.Point(20,165)
$btnOpen.Size = New-Object System.Drawing.Size(490,40)
$btnOpen.Text = "Open OmniRoute Dashboard"
Format-Button $btnOpen
$form.Controls.Add($btnOpen)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Location = New-Object System.Drawing.Point(20,220)
$btnStop.Size = New-Object System.Drawing.Size(490,40)
$btnStop.Text = "Stop OmniRoute"
Format-Button $btnStop
$form.Controls.Add($btnStop)

$btnUninstall = New-Object System.Windows.Forms.Button
$btnUninstall.Location = New-Object System.Drawing.Point(20,275)
$btnUninstall.Size = New-Object System.Drawing.Size(490,40)
$btnUninstall.Text = "Uninstall..."
Format-Button $btnUninstall
$form.Controls.Add($btnUninstall)

$btnUpdate = New-Object System.Windows.Forms.Button
$btnUpdate.Location = New-Object System.Drawing.Point(20,330)
$btnUpdate.Size = New-Object System.Drawing.Size(490,40)
$btnUpdate.Text = "Check for Updates"
Format-Button $btnUpdate
$form.Controls.Add($btnUpdate)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20,385)
$txtLog.Size = New-Object System.Drawing.Size(490,175)
$txtLog.Multiline = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.ReadOnly = $true
$txtLog.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#0C0C0C")
$txtLog.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#00D68F")
$txtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtLog.BorderStyle = 'FixedSingle'
$form.Controls.Add($txtLog)

# --- Bottom Information Block ---
$lblTip = New-Object System.Windows.Forms.Label
$lblTip.Location = New-Object System.Drawing.Point(20, 570)
$lblTip.Size = New-Object System.Drawing.Size(490, 32)
$lblTip.Text = [char]::ConvertFromUtf32(0x1F4A1) + " Tip: OmniRoute uses port 20128. Configure your API keys in the dashboard at localhost:20128/dashboard/"
$lblTip.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#AAAAAA")
$lblTip.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$lblTip.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$form.Controls.Add($lblTip)

$lblAPI = New-Object System.Windows.Forms.Label
$lblAPI.Location = New-Object System.Drawing.Point(20, 605)
$lblAPI.Size = New-Object System.Drawing.Size(490, 18)
$lblAPI.Text = "API Endpoint: http://localhost:20128/v1"
$lblAPI.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#888888")
$lblAPI.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$lblAPI.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$form.Controls.Add($lblAPI)

function Show-LicenseDialog {
    $licForm = New-Object System.Windows.Forms.Form
    $licForm.Text = "MIT License"
    $licForm.ClientSize = New-Object System.Drawing.Size(460, 360)
    $licForm.StartPosition = "CenterParent"
    $licForm.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#181818")
    $licForm.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#E0E0E0")
    $licForm.FormBorderStyle = 'FixedDialog'
    $licForm.MaximizeBox = $false
    $licForm.MinimizeBox = $false

    $txtLic = New-Object System.Windows.Forms.TextBox
    $txtLic.Location = New-Object System.Drawing.Point(15, 15)
    $txtLic.Size = New-Object System.Drawing.Size(430, 280)
    $txtLic.Multiline = $true
    $txtLic.ScrollBars = 'Vertical'
    $txtLic.ReadOnly = $true
    $txtLic.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#1F1F1F")
    $txtLic.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#E0E0E0")
    $txtLic.BorderStyle = 'FixedSingle'
    $txtLic.Font = New-Object System.Drawing.Font("Consolas", 9.5)
    
    $licenseText = @'
MIT License

Copyright (c) 2026 diegosouzapw

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
'@
    $txtLic.Text = $licenseText -replace "`n", "`r`n"
    $txtLic.SelectionLength = 0
    $licForm.Controls.Add($txtLic)

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = "OK"
    $btnOk.Location = New-Object System.Drawing.Point(180, 310)
    $btnOk.Size = New-Object System.Drawing.Size(100, 35)
    $btnOk.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#333337")
    $btnOk.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")
    $btnOk.FlatStyle = 'Flat'
    $btnOk.FlatAppearance.BorderSize = 0
    $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $licForm.Controls.Add($btnOk)
    $licForm.AcceptButton = $btnOk

    $licForm.ShowDialog($form) | Out-Null
}

$lnkFooter = New-Object System.Windows.Forms.LinkLabel
$lnkFooter.Location = New-Object System.Drawing.Point(20, 627)
$lnkFooter.Size = New-Object System.Drawing.Size(490, 18)
$lnkFooter.Text = "Powered by OmniRoute core | View MIT License"
$lnkFooter.Links.Clear()
$lnkFooter.Links.Add(11, 14, "https://github.com/diegosouzapw/OmniRoute")
$lnkFooter.Links.Add(28, 16, "license")
$lnkFooter.LinkColor = [System.Drawing.ColorTranslator]::FromHtml("#0078D4")
$lnkFooter.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lnkFooter.Add_LinkClicked({
    param($sender, $e)
    if ($e.Link.LinkData -eq "license") {
        Show-LicenseDialog
    } else {
        Start-Process $e.Link.LinkData
    }
})
$form.Controls.Add($lnkFooter)

$lblCredits = New-Object System.Windows.Forms.Label
$lblCredits.Location = New-Object System.Drawing.Point(20, 649)
$lblCredits.Size = New-Object System.Drawing.Size(490, 18)
$lblCredits.Text = "This GUI is designed by Banajit Pathak, adapted by Antigravity"
$lblCredits.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#888888")
$lblCredits.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblCredits.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$form.Controls.Add($lblCredits)

# Timer to safely pop logs into the textbox on the UI thread
$global:tickCounter = 0
$logTimer = New-Object System.Windows.Forms.Timer
$logTimer.Interval = 100
$logTimer.Add_Tick({
    $global:tickCounter++
    if ($global:tickCounter -ge 10) {
        $global:tickCounter = 0
        Update-UIState
    }
    $msg = ""
    while ($global:logQueue.TryDequeue([ref]$msg)) {
        if ($msg.StartsWith("HIDDEN|")) {
            $cleanMsg = $msg.Substring(7)
            $txtLog.AppendText("$cleanMsg`r`n")
        } else {
            $cleanMsg = $msg.Substring(5)
            $txtLog.AppendText("$cleanMsg`r`n")
            $lblStatus.Text = "Status: $( ($cleanMsg -split ' - ', 2)[1] )"
        }
        $txtLog.SelectionStart = $txtLog.Text.Length
        $txtLog.ScrollToCaret()
    }
})

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    
    $paths = @()
    if ($machinePath) { $paths += $machinePath -split ';' }
    if ($userPath) { $paths += $userPath -split ';' }
    
    $extraPaths = @(
        "C:\Program Files\nodejs",
        "C:\Program Files (x86)\nodejs",
        "$env:APPDATA\npm",
        "C:\Program Files\Git\cmd",
        "C:\Program Files (x86)\Git\cmd",
        "C:\Program Files\Git\bin"
    )
    
    foreach ($p in $extraPaths) {
        if (Test-Path $p) {
            $normP = $p.Trim().TrimEnd('\')
            $found = $false
            foreach ($existing in $paths) {
                if ($existing.Trim().TrimEnd('\') -eq $normP) {
                    $found = $true
                    break
                }
            }
            if (-not $found) { $paths += $p }
        }
    }
    $env:Path = ($paths | Where-Object { $_.Trim() }) -join ';'
}

function Test-Command {
    param([string]$Cmd)
    Refresh-Path
    $result = where.exe $Cmd 2>$null
    return [bool]$result
}

$global:serverProcess = $null
$global:browserProcess = $null
$global:isUpdating = $false
$global:isUninstalling = $false
$global:isInstalling = $false
$global:lastBrowserCheckTime = 0
$global:lastBrowserCheckResult = $false

function Create-Shortcut {
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktopPath "OmniRoute Dashboard.lnk"
    
    Queue-Log "Updating Desktop Shortcut for instant launch..."
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $psPath = "powershell.exe"
    $guiPath = Join-Path $PSScriptRoot "gui.ps1"
    
    $shortcut.TargetPath = $psPath
    $shortcut.Arguments = "-NoProfile -NoLogo -NonInteractive -Sta -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$guiPath`""
    $shortcut.WorkingDirectory = $PSScriptRoot
    $shortcut.Description = "Launch OmniRoute"
    $shortcut.Save()
}

function Get-UninstallKey {
    param([string]$AppName)
    $regPaths = @("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
    foreach ($path in $regPaths) {
        try {
            $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($path)
            if ($regKey) {
                foreach ($subKeyName in $regKey.GetSubKeyNames()) {
                    [System.Windows.Forms.Application]::DoEvents()
                    try {
                        $subKey = $regKey.OpenSubKey($subKeyName)
                        if ($subKey) {
                            $displayName = $subKey.GetValue("DisplayName")
                            if ($displayName -and $displayName -match $AppName) {
                                $quietUninstall = $subKey.GetValue("QuietUninstallString")
                                $uninstall = $subKey.GetValue("UninstallString")
                                $subKey.Close()
                                $regKey.Close()
                                return @{ DisplayName = $displayName; QuietUninstallString = $quietUninstall; UninstallString = $uninstall }
                            }
                            $subKey.Close()
                        }
                    } catch {}
                }
                $regKey.Close()
            }
        } catch {}
    }
    return $null
}

function Patch-OmniRouteFiles {
    param (
        [string]$targetDir
    )
    Queue-Log "Applying Windows-specific build fixes to cloned repository..."
    try {
        # 1. Patch pnpm.json — add "bun" to onlyBuiltDependencies to prevent ERR_PNPM_IGNORED_BUILDS
        $pnpmJsonPath = Join-Path $targetDir "pnpm.json"
        if (Test-Path $pnpmJsonPath) {
            $pnpmContent = [System.IO.File]::ReadAllText($pnpmJsonPath)
            if (-not $pnpmContent.Contains('"bun"')) {
                $pnpmContent = $pnpmContent.Replace('"onlyBuiltDependencies": [', "`"onlyBuiltDependencies`": [`r`n    `"bun`",")
                [System.IO.File]::WriteAllText($pnpmJsonPath, $pnpmContent)
                Queue-Log "  Patched pnpm.json (added bun to onlyBuiltDependencies)"
            } else {
                Queue-Log "  pnpm.json already has bun allowed, skipping."
            }
        }

        # 2. Patch pnpm-workspace.yaml — add "bun: true" to allowBuilds to prevent ERR_PNPM_IGNORED_BUILDS in pnpm 10+
        $workspaceYamlPath = Join-Path $targetDir "pnpm-workspace.yaml"
        if (Test-Path $workspaceYamlPath) {
            $yamlContent = [System.IO.File]::ReadAllText($workspaceYamlPath)
            if (-not $yamlContent.Contains("bun:")) {
                $yamlContent = $yamlContent.Replace("allowBuilds:", "allowBuilds:`r`n  bun: true")
                [System.IO.File]::WriteAllText($workspaceYamlPath, $yamlContent)
                Queue-Log "  Patched pnpm-workspace.yaml (added bun to allowBuilds)"
            } else {
                Queue-Log "  pnpm-workspace.yaml already has bun allowed, skipping."
            }
        }

        # 3. Patch scripts/build/assembleStandalone.mjs — add skipNodeModules param + circular symlink filter
        $assemblePath = Join-Path $targetDir "scripts\build\assembleStandalone.mjs"
        if (Test-Path $assemblePath) {
            $content = [System.IO.File]::ReadAllText($assemblePath)
            $patched = $false
            
            # Add skipNodeModules = false parameter if not already present
            if (-not $content.Contains("skipNodeModules")) {
                $content = $content.Replace("copyNatives = true,", "copyNatives = true,`n  skipNodeModules = false,")
                $patched = $true
            }
            
            # Replace bare cpSync with filtered version to prevent circular symlink crash
            $oldCpSync = 'fsSync.cpSync(standaloneDir, resolvedOutDir, { recursive: true });'
            if ($content.Contains($oldCpSync)) {
                $newCpSync = @'
fsSync.cpSync(standaloneDir, resolvedOutDir, {
      recursive: true,
      filter: (sourcePath) => {
        const relative = path.relative(standaloneDir, sourcePath);
        const parts = relative.split(path.sep);
        if (skipNodeModules && parts.includes("node_modules")) { return false; }
        try {
          const stat = fsSync.lstatSync(sourcePath);
          if (stat.isSymbolicLink()) {
            const target = fsSync.readlinkSync(sourcePath);
            const resolvedTarget = path.resolve(path.dirname(sourcePath), target);
            if (resolvedTarget === projectRoot || resolvedTarget.startsWith(projectRoot + path.sep)) {
              return false;
            }
          }
        } catch {}
        return true;
      }
    });
'@
                $content = $content.Replace($oldCpSync, $newCpSync)
                $patched = $true
            }
            
            if ($patched) {
                [System.IO.File]::WriteAllText($assemblePath, $content)
                Queue-Log "  Patched assembleStandalone.mjs (symlink + skipNodeModules fix)"
            } else {
                Queue-Log "  assembleStandalone.mjs already patched or structure changed, skipping."
            }
        }

        # 4. Patch scripts/build/prepublish.ts — shell:true wrapper + skipNodeModules:true
        $prepublishPath = Join-Path $targetDir "scripts\build\prepublish.ts"
        if (Test-Path $prepublishPath) {
            $content = [System.IO.File]::ReadAllText($prepublishPath)
            $patched = $false
            
            # Wrap execFileSync with shell:true on Windows to prevent EINVAL on .cmd files
            $oldImport = 'import { execFileSync } from "node:child_process";'
            if ($content.Contains($oldImport)) {
                $newImport = @'
import { execFileSync as _execFileSync } from "node:child_process";
const execFileSync: typeof _execFileSync = (file: any, args?: any, options?: any) => {
  const opts = typeof args === "object" && !Array.isArray(args) ? args : (options || {});
  const realArgs = Array.isArray(args) ? args : undefined;
  if (process.platform === "win32") { opts.shell = true; }
  return realArgs ? _execFileSync(file, realArgs, opts) : _execFileSync(file, opts);
};
'@
                $content = $content.Replace($oldImport, $newImport)
                $patched = $true
            }
            
            # Pass skipNodeModules: true to assembleStandalone call
            if ($content.Contains("copyNatives: true,") -and -not $content.Contains("skipNodeModules: true")) {
                $content = $content.Replace("copyNatives: true,", "copyNatives: true,`n  skipNodeModules: true,")
                $patched = $true
            }
            
            if ($patched) {
                [System.IO.File]::WriteAllText($prepublishPath, $content)
                Queue-Log "  Patched prepublish.ts (shell:true + skipNodeModules fix)"
            } else {
                Queue-Log "  prepublish.ts already patched or structure changed, skipping."
            }
        }

        # 5. Patch src/lib/db/adapters/driverFactory.ts — replace createRequire(import.meta.url) with createRequire(process.cwd()) to bypass Next.js Turbopack compilation bug
        $driverFactoryPath = Join-Path $targetDir "src\lib\db\adapters\driverFactory.ts"
        if (Test-Path $driverFactoryPath) {
            $content = [System.IO.File]::ReadAllText($driverFactoryPath)
            if ($content.Contains("createRequire(import.meta.url)")) {
                $content = $content.Replace("createRequire(import.meta.url)", "createRequire(process.cwd())")
                [System.IO.File]::WriteAllText($driverFactoryPath, $content)
                Queue-Log "  Patched driverFactory.ts (workaround for Next.js Turbopack import.meta.url bug)"
            } else {
                Queue-Log "  driverFactory.ts already patched or createRequire not found, skipping."
            }
        }
    } catch {
        Queue-Log "  Error applying build patches: $_"
    }
}

function Uninstall-App {
    param([string]$AppName)
    Queue-Log "Locating $AppName uninstaller..."
    $app = Get-UninstallKey $AppName
    if ($app) {
        $uninstallString = $app.QuietUninstallString
        if (-not $uninstallString) { $uninstallString = $app.UninstallString }
        if ($uninstallString) {
            if ($uninstallString -match "msiexec") {
                $uninstallString = ($uninstallString -replace "/I", "/X") + " /quiet /norestart"
            } elseif ($uninstallString -match "unins000.exe") {
                $uninstallString += " /VERYSILENT /SUPPRESSMSGBOXES /NORESTART"
            }
            Queue-Log "Uninstalling $AppName... (Please click 'Yes' on the Administrator prompt)"
            try {
                $proc = Start-Process cmd -ArgumentList "/c `"$uninstallString`"" -Verb RunAs -WindowStyle Hidden -PassThru -ErrorAction Stop
                while (-not $proc.HasExited) {
                    [System.Windows.Forms.Application]::DoEvents()
                    Start-Sleep -Milliseconds 100
                }
                Queue-Log "$AppName successfully removed!"
            } catch { Queue-Log "Uninstall of $AppName cancelled or failed." }
        }
    } else {
        Queue-Log "$AppName not found. It may already be removed."
    }
}

function Get-IsBrowserRunning {
    if ($global:browserProcess -and -not $global:browserProcess.HasExited) { return $true }
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($now - $global:lastBrowserCheckTime -lt 3) { return $global:lastBrowserCheckResult }
    $global:lastBrowserCheckTime = $now
    $procs = Get-Process msedge, chrome, firefox, opera, brave -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*OmniRoute*" }
    $global:lastBrowserCheckResult = [bool]$procs
    return $global:lastBrowserCheckResult
}

function Update-UIState {
    $targetDir = $txtInstallDir.Text
    $packageJsonPath = Join-Path $targetDir "package.json"

    $isSetup = (Test-Path $targetDir) -and (Test-Path $packageJsonPath)
    $isRestricted = $global:isUpdating -or $global:isUninstalling -or $global:isInstalling
    
    Set-ButtonState $btnUpdate ($isSetup -and -not $isRestricted)

    if ($global:isInstalling) {
        $btnSmart.Text = "Installing OmniRoute..."
        Set-ButtonState $btnSmart $false
        $btnOpen.Text = "Open OmniRoute Dashboard"
        Set-ButtonState $btnOpen $false
        Set-ButtonState $btnStop $false
        $btnUninstall.Text = "Uninstall..."
        Set-ButtonState $btnUninstall $false
        return
    }

    if ($global:isUninstalling) {
        $btnSmart.Text = "Uninstalling..."
        Set-ButtonState $btnSmart $false
        $btnOpen.Text = "Open OmniRoute Dashboard"
        Set-ButtonState $btnOpen $false
        Set-ButtonState $btnStop $false
        $btnUninstall.Text = "Uninstalling OmniRoute..."
        Set-ButtonState $btnUninstall $false
        return
    }

    $isServerActive = $false
    if ($global:serverProcess -and -not $global:serverProcess.HasExited) {
        $isServerActive = $true
    } elseif (Test-PortActive 20128) {
        $isServerActive = $true
    }

    if ($isServerActive) {
        $btnSmart.Text = "Running..."
        Set-ButtonState $btnSmart $false
        
        if (Get-IsBrowserRunning) {
            $btnOpen.Text = "OmniRoute Dashboard is opened"
            Set-ButtonState $btnOpen $false
        } else {
            $btnOpen.Text = "Open OmniRoute Dashboard"
            Set-ButtonState $btnOpen $true "#0078D4" "#FFFFFF"
        }
        Set-ButtonState $btnStop $true "#D13438" "#FFFFFF"
        Set-ButtonState $btnUninstall $false
    } else {
        if ($isSetup) {
            $btnSmart.Text = "Start OmniRoute"
            Set-ButtonState $btnSmart (-not $global:isUpdating) "#0078D4" "#FFFFFF"
        } else {
            $btnSmart.Text = "Install & Start OmniRoute"
            Set-ButtonState $btnSmart (-not $global:isUpdating) "#107C10" "#FFFFFF"
        }
        $btnOpen.Text = "Open OmniRoute Dashboard"
        Set-ButtonState $btnOpen $false
        Set-ButtonState $btnStop $false
        $btnUninstall.Text = "Uninstall..."
        Set-ButtonState $btnUninstall ((Test-Path $targetDir) -and -not $global:isUpdating)
    }
}

$btnSmart.Add_Click({
    if ($btnSmart.Tag -eq $false) { return }
    Set-ButtonState $btnSmart $false

    $targetDir = $txtInstallDir.Text
    $isSetup = (Test-Path $targetDir) -and (Test-Path (Join-Path $targetDir "package.json"))

    if (-not $isSetup) {
        $global:isInstalling = $true
        Update-UIState
        [System.Windows.Forms.Application]::DoEvents()
        try {
            Queue-Log "Starting Installation Wizard..."
            
            if (-not (Test-Command git)) {
                Queue-Log "Downloading Git (This may take a minute, please wait)..."
                $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.44.0.windows.1/Git-2.44.0-64-bit.exe"
                $proc = Start-HiddenProcess "curl.exe" "-s -L -o git_setup.exe $gitUrl"
                Wait-HiddenProcess $proc | Out-Null
                
                Queue-Log "Installing Git... (Please click 'Yes' on the Administrator prompt)"
                $gitSetupPath = Join-Path (Get-Location) "git_setup.exe"
                try {
                    $proc = Start-Process "$gitSetupPath" -ArgumentList "/VERYSILENT /NORESTART" -Verb RunAs -WindowStyle Hidden -PassThru -ErrorAction Stop
                    while (-not $proc.HasExited) {
                        [System.Windows.Forms.Application]::DoEvents()
                        Start-Sleep -Milliseconds 100
                    }
                    if ($proc.ExitCode -eq 0) { Queue-Log "Git installed." }
                } catch { Queue-Log "Git installation failed: $_" }
                if (Test-Path $gitSetupPath) { Remove-Item $gitSetupPath -Force }
            } else {
                Queue-Log "Git is found, skipping installation."
            }

            if (-not (Test-Command node)) {
                Queue-Log "Downloading Node.js (This may take a minute, please wait)..."
                $nodeUrl = "https://nodejs.org/dist/v22.13.1/node-v22.13.1-x64.msi"
                $proc = Start-HiddenProcess "curl.exe" "-s -L -o node_setup.msi $nodeUrl"
                Wait-HiddenProcess $proc | Out-Null
                
                Queue-Log "Installing Node.js... (Please click 'Yes' on the Administrator prompt)"
                $nodeSetupPath = Join-Path (Get-Location) "node_setup.msi"
                try {
                    $proc = Start-Process "msiexec.exe" -ArgumentList "/i `"$nodeSetupPath`" /quiet /norestart" -Verb RunAs -WindowStyle Hidden -PassThru -ErrorAction Stop
                    while (-not $proc.HasExited) {
                        [System.Windows.Forms.Application]::DoEvents()
                        Start-Sleep -Milliseconds 100
                    }
                    if ($proc.ExitCode -eq 0) { Queue-Log "Node.js installed." }
                } catch { Queue-Log "Node.js installation failed: $_" }
                if (Test-Path $nodeSetupPath) { Remove-Item $nodeSetupPath -Force }
            } else {
                Queue-Log "Node.js is found, skipping installation."
            }
            
            # Since npm comes with Node.js, checking node is usually enough, but let's log npm too.
            if (Test-Command npm) {
                Queue-Log "NPM is found, skipping installation."
            }
            
            Refresh-Path
            
            if (-not (Test-Path (Join-Path $targetDir "package.json"))) {
                if (Test-Path $targetDir) {
                    Queue-Log "Cleaning target directory before clone..."
                    Remove-Item -Path $targetDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                Queue-Log "Cloning OmniRoute repository..."
                $proc = Start-HiddenProcess "git" "clone https://github.com/diegosouzapw/OmniRoute.git `"$targetDir`""
                Wait-HiddenProcess $proc | Out-Null
                
                # Apply Windows build patches right after cloning
                Patch-OmniRouteFiles -targetDir $targetDir
            }

            if (Test-Path (Join-Path $targetDir "package.json")) {
                Queue-Log "Installing pnpm... (This takes a minute, please wait)"
                Start-Process "cmd" -ArgumentList "/c npm install -g pnpm" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait

                Queue-Log "Resolving dependencies via pnpm (safe phase)..."
                Start-Process "cmd" -ArgumentList "/c pnpm install --ignore-scripts --fetch-timeout 600000 --fetch-retries 5" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait

                Queue-Log "Approving build scripts (bun) for pnpm..."
                Start-Process "cmd" -ArgumentList "/c pnpm approve-builds --all" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait

                Queue-Log "Installing dependencies via pnpm... (This takes a few minutes, please wait)"
                Start-Process "cmd" -ArgumentList "/c pnpm install --fetch-timeout 600000 --fetch-retries 5" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait

                Queue-Log "Installing missing dependency (remark-gfm)..."
                Start-Process "cmd" -ArgumentList "/c pnpm add remark-gfm" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait

                Queue-Log "Building OmniRoute... (This takes a few minutes, please wait)"
                Start-Process "cmd" -ArgumentList "/c pnpm run build" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait

                Queue-Log "Building CLI and staging packages (build:cli)..."
                Start-Process "cmd" -ArgumentList "/c pnpm run build:cli" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait

                Queue-Log "Registering omniroute command globally..."
                Start-Process "cmd" -ArgumentList "/c npm link" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait
                
                Queue-Log "Setup completely finished!"
                Create-Shortcut
            }
        } finally {
            $global:isInstalling = $false
            Update-UIState
            [System.Windows.Forms.Application]::DoEvents()
        }
    }

    Queue-Log "Starting OmniRoute server... (Running Minimized to prevent crashes)"
    
    $ruleName = "Node.js JavaScript Runtime (OmniRoute)"
    $checkRule = netsh advfirewall firewall show rule name=$ruleName 2>&1
    if ($checkRule -match "No rules match") {
        Queue-Log "Silencing Windows Firewall... (Please click 'Yes' if prompted)"
        try {
            $nodeExe = (where.exe node | Select-Object -First 1)
            if ($nodeExe) {
                $args = "advfirewall firewall add rule name=`"$ruleName`" dir=in action=allow program=`"$nodeExe`" enable=yes profile=any"
                Start-Process "netsh.exe" -ArgumentList $args -Verb RunAs -WindowStyle Hidden -Wait -ErrorAction Stop
            }
        } catch { Queue-Log "Firewall bypass cancelled. You may see a firewall popup." }
    }
    
    $global:serverProcess = Start-Process cmd -ArgumentList "/k title OmniRoute Server && pnpm run start" -WorkingDirectory $targetDir -WindowStyle Minimized -PassThru

    Queue-Log "Server is starting..."
    Update-UIState
    
    $browserTimer = New-Object System.Windows.Forms.Timer
    $browserTimer.Interval = 3000
    $browserTimer.Add_Tick({
        $this.Stop()
        Queue-Log "Opening Dashboard in your web browser..."
        $uiUri = "http://localhost:20128/dashboard/"
        if (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
            $global:browserProcess = Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList "--app=`"$uiUri`"" -PassThru
        } elseif (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
            $global:browserProcess = Start-Process "C:\Program Files\Google\Chrome\Application\chrome.exe" -ArgumentList "--app=`"$uiUri`"" -PassThru
        } else {
            $global:browserProcess = Start-Process $uiUri -PassThru
        }
        Update-UIState
    })
    $browserTimer.Start()
})

$btnStop.Add_Click({
    if ($btnStop.Tag -eq $false) { return }
    $pidToKill = $null
    if ($global:serverProcess -and -not $global:serverProcess.HasExited) {
        $pidToKill = $global:serverProcess.Id
    } else {
        $netstat = netstat -ano | Select-String "127.0.0.1:20128" | Select-Object -First 1
        if ($netstat -match "\s+(\d+)$") { $pidToKill = $Matches[1] }
    }

    if ($pidToKill) {
        Queue-Log "Stopping OmniRoute server and all child processes..."
        Start-Process "taskkill.exe" -ArgumentList "/PID $pidToKill /T /F" -WindowStyle Hidden -Wait
        $global:serverProcess = $null
        Queue-Log "Server stopped."
    } else {
        Queue-Log "No running server detected on port 20128."
    }

    if ($global:browserProcess -and -not $global:browserProcess.HasExited) {
        try { Stop-Process -Id $global:browserProcess.Id -Force -ErrorAction SilentlyContinue } catch {}
        $global:browserProcess = $null
    }
    
    Get-Process msedge, chrome, firefox, opera, brave -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*OmniRoute*" } | ForEach-Object { try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {} }

    Update-UIState
    $result = [System.Windows.Forms.MessageBox]::Show(
        "OmniRoute server has been successfully stopped.`n`nDo you want to exit the Manager GUI as well?",
        "Exit Manager?",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) { $form.Close() }
})

$btnOpen.Add_Click({
    if ($btnOpen.Tag -eq $false) { return }
    $uiUri = "http://localhost:20128/dashboard/"
    if (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
        $global:browserProcess = Start-Process "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList "--app=`"$uiUri`"" -PassThru
    } elseif (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
        $global:browserProcess = Start-Process "C:\Program Files\Google\Chrome\Application\chrome.exe" -ArgumentList "--app=`"$uiUri`"" -PassThru
    } else {
        $global:browserProcess = Start-Process $uiUri -PassThru
    }
    Update-UIState
})

$btnUninstall.Add_Click({
    if ($btnUninstall.Tag -eq $false) { return }
    $targetDir = $txtInstallDir.Text

    $unForm = New-Object System.Windows.Forms.Form
    $unForm.Text = "Uninstall Options"
    $unForm.Size = New-Object System.Drawing.Size(350, 260)
    $unForm.StartPosition = "CenterParent"
    $unForm.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#181818")
    $unForm.ForeColor = [System.Drawing.ColorTranslator]::FromHtml("#E0E0E0")
    $unForm.FormBorderStyle = 'FixedDialog'
    $unForm.MaximizeBox = $false

    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = "Select what you want to uninstall:"
    $lblInfo.Location = New-Object System.Drawing.Point(20, 20)
    $lblInfo.Size = New-Object System.Drawing.Size(300, 20)
    $unForm.Controls.Add($lblInfo)

    $chkFree = New-Object System.Windows.Forms.CheckBox
    $chkFree.Text = "OmniRoute"
    $chkFree.Location = New-Object System.Drawing.Point(20, 50)
    $chkFree.Size = New-Object System.Drawing.Size(300, 20)
    $chkFree.Checked = $true
    $chkFree.Enabled = $false
    $unForm.Controls.Add($chkFree)

    $chkGit = New-Object System.Windows.Forms.CheckBox
    $chkGit.Text = "Git (Prerequisite)"
    $chkGit.Location = New-Object System.Drawing.Point(20, 80)
    $chkGit.Size = New-Object System.Drawing.Size(300, 20)
    $unForm.Controls.Add($chkGit)

    $chkNode = New-Object System.Windows.Forms.CheckBox
    $chkNode.Text = "Node.js (Prerequisite)"
    $chkNode.Location = New-Object System.Drawing.Point(20, 110)
    $chkNode.Size = New-Object System.Drawing.Size(300, 20)
    $unForm.Controls.Add($chkNode)

    $btnConfirm = New-Object System.Windows.Forms.Button
    $btnConfirm.Text = "Uninstall Selected"
    $btnConfirm.Location = New-Object System.Drawing.Point(20, 160)
    $btnConfirm.Size = New-Object System.Drawing.Size(140, 35)
    $btnConfirm.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#D13438")
    $btnConfirm.FlatStyle = 'Flat'
    $btnConfirm.FlatAppearance.BorderSize = 0
    $btnConfirm.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $unForm.Controls.Add($btnConfirm)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Location = New-Object System.Drawing.Point(170, 160)
    $btnCancel.Size = New-Object System.Drawing.Size(140, 35)
    $btnCancel.BackColor = [System.Drawing.ColorTranslator]::FromHtml("#333337")
    $btnCancel.FlatStyle = 'Flat'
    $btnCancel.FlatAppearance.BorderSize = 0
    $btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $unForm.Controls.Add($btnCancel)

    $unForm.AcceptButton = $btnConfirm
    $unForm.CancelButton = $btnCancel

    if ($unForm.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $global:isUninstalling = $true
        Update-UIState
        [System.Windows.Forms.Application]::DoEvents()

        Get-Process msedge, chrome, firefox, opera, brave -ErrorAction SilentlyContinue | Where-Object { 
            $_.MainWindowTitle -like "*OmniRoute*" 
        } | Stop-Process -Force -ErrorAction SilentlyContinue

        Queue-Log "Uninstalling OmniRoute from $targetDir..."
        
        try {
            $escapedDir = [regex]::Escape($targetDir)
            Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
                ($_.ExecutablePath -and $_.ExecutablePath -like "$targetDir*") -or 
                ($_.CommandLine -and $_.CommandLine -match $escapedDir)
            } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        } catch {}

        foreach ($port in @(20128)) {
            try {
                $netstat = netstat -ano | Select-String "127.0.0.1:$port" | Select-Object -First 1
                if ($netstat -match "\s+(\d+)$") { Stop-Process -Id $Matches[1] -Force -ErrorAction SilentlyContinue }
            } catch {}
        }

        Start-Sleep -Milliseconds 200

        if (Test-Path $targetDir) {
            $parentDir = Split-Path $targetDir -Parent
            $trashName = "omniroute_trash_$([Guid]::NewGuid().ToString().Substring(0,8))"
            $trashPath = Join-Path $parentDir $trashName
            try {
                Rename-Item -Path $targetDir -NewName $trashName -ErrorAction Stop
                Start-Process cmd.exe -ArgumentList "/c rmdir /s /q `"$trashPath`"" -WindowStyle Hidden
            } catch {
                Start-Process cmd.exe -ArgumentList "/c rmdir /s /q `"$targetDir`"" -WindowStyle Hidden
            }
        }
        Queue-Log "OmniRoute has been uninstalled."
        $shortcutPath = Join-Path ([Environment]::GetFolderPath('Desktop')) "OmniRoute Dashboard.lnk"
        if (Test-Path $shortcutPath) { Remove-Item $shortcutPath -Force }
        
        if ($chkGit.Checked) { Uninstall-App "Git" }
        if ($chkNode.Checked) { Uninstall-App "Node.js" }
        
        $global:isUninstalling = $false
        Update-UIState

        [System.Windows.Forms.MessageBox]::Show(
            "OmniRoute has been successfully uninstalled.",
            "Uninstall Complete",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    }
})

$btnUpdate.Add_Click({
    if ($btnUpdate.Tag -eq $false) { return }
    $global:isUpdating = $true
    Update-UIState

    try {
        $targetDir = $txtInstallDir.Text
        Queue-Log "Running git fetch to check for remote updates..."
        $procFetch = Start-HiddenProcess "git" "fetch" $targetDir
        $exitFetch = Wait-HiddenProcess $procFetch

        if ($exitFetch -ne 0) {
            Queue-Log "Error: Failed to fetch updates from remote repository."
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to fetch updates from remote repository. Please check your internet connection.",
                "Check for Updates Failed",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return
        }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "git"
        $psi.Arguments = "rev-list --count HEAD..origin/main"
        $psi.WorkingDirectory = $targetDir
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $proc.Start() | Out-Null
        while (-not $proc.HasExited) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 50 }

        $output = $proc.StandardOutput.ReadToEnd()
        $errOutput = $proc.StandardError.ReadToEnd()
        if ($proc.ExitCode -ne 0) {
            Queue-Log "Error: git rev-list failed: $errOutput"
            return
        }

        [int]$behindCount = 0
        if (-not [int]::TryParse($output.Trim(), [ref]$behindCount)) {
            Queue-Log "Error: Failed to parse update count: $output"
            return
        }

        if ($behindCount -gt 0) {
            $msgBoxResult = [System.Windows.Forms.MessageBox]::Show(
                "An update is available! You are $behindCount commit(s) behind the remote main branch.`n`nDo you want to update now?",
                "Update Available",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )

            if ($msgBoxResult -eq [System.Windows.Forms.DialogResult]::Yes) {
                if ($global:serverProcess -and -not $global:serverProcess.HasExited) {
                    Queue-Log "Stopping OmniRoute server..."
                    Start-Process "taskkill.exe" -ArgumentList "/PID $($global:serverProcess.Id) /T /F" -WindowStyle Hidden -Wait
                    $global:serverProcess = $null
                    Queue-Log "Server stopped."
                }

                $hasChanges = $false
                try {
                    $psiDiff = New-Object System.Diagnostics.ProcessStartInfo
                    $psiDiff.FileName = "git"
                    $psiDiff.Arguments = "status --porcelain"
                    $psiDiff.WorkingDirectory = $targetDir
                    $psiDiff.RedirectStandardOutput = $true
                    $psiDiff.RedirectStandardError = $true
                    $psiDiff.UseShellExecute = $false
                    $psiDiff.CreateNoWindow = $true
                    $procDiff = New-Object System.Diagnostics.Process
                    $procDiff.StartInfo = $psiDiff
                    $procDiff.Start() | Out-Null
                    while (-not $procDiff.HasExited) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 50 }
                    $diffOut = $procDiff.StandardOutput.ReadToEnd().Trim()
                    if ($diffOut -ne "") {
                        foreach ($line in ($diffOut -split "`r?`n")) {
                            if ($line.Trim() -and -not $line.StartsWith("??")) { $hasChanges = $true; break }
                        }
                    }
                } catch {}

                if ($hasChanges) {
                    Queue-Log "Local modifications detected. Stashing changes..."
                    $procStash = Start-HiddenProcess "git" "stash" $targetDir
                    Wait-HiddenProcess $procStash | Out-Null
                }

                Queue-Log "Pulling latest changes (git pull)..."
                $procPull = Start-HiddenProcess "git" "pull" $targetDir
                $exitPull = Wait-HiddenProcess $procPull

                if ($hasChanges) {
                    Queue-Log "Restoring local stashed changes..."
                    $procPop = Start-HiddenProcess "git" "stash pop" $targetDir
                    Wait-HiddenProcess $procPop | Out-Null
                }

                if ($exitPull -ne 0) {
                    Queue-Log "Error: git pull failed with exit code $exitPull."
                    return
                }

                # Apply Windows build patches right after pulling updates
                Patch-OmniRouteFiles -targetDir $targetDir

                Queue-Log "Resolving updated dependencies via pnpm (safe phase)..."
                Start-Process "cmd" -ArgumentList "/c pnpm install --ignore-scripts --fetch-timeout 600000 --fetch-retries 5" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait

                Queue-Log "Approving build scripts (bun) for pnpm..."
                Start-Process "cmd" -ArgumentList "/c pnpm approve-builds --all" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait

                Queue-Log "Installing updated dependencies (pnpm install)..."
                Start-Process "cmd" -ArgumentList "/c pnpm install --fetch-timeout 600000 --fetch-retries 5" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait

                Queue-Log "Installing missing dependency (remark-gfm)..."
                Start-Process "cmd" -ArgumentList "/c pnpm add remark-gfm" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait

                Queue-Log "Building updated OmniRoute..."
                Start-Process "cmd" -ArgumentList "/c pnpm run build" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait

                Queue-Log "Building updated CLI and staging packages (build:cli)..."
                Start-Process "cmd" -ArgumentList "/c pnpm run build:cli" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait

                Queue-Log "Re-linking omniroute command globally..."
                Start-Process "cmd" -ArgumentList "/c npm link" -WorkingDirectory $targetDir -WindowStyle Hidden -Wait

                Queue-Log "Update completed successfully!"
                $restartBox = [System.Windows.Forms.MessageBox]::Show(
                    "OmniRoute has been updated to the latest version.`n`nWould you like to restart the Manager GUI now to apply the updates?",
                    "Update Successful",
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Question
                )

                if ($restartBox -eq [System.Windows.Forms.DialogResult]::Yes) {
                    Queue-Log "Restarting Manager GUI..."
                    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -WindowStyle Normal
                    $form.Close()
                }
            }
        } else {
            Queue-Log "OmniRoute is already up-to-date."
            [System.Windows.Forms.MessageBox]::Show(
                "OmniRoute is already up-to-date.",
                "Up to Date",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
    } finally {
        $global:isUpdating = $false
        Update-UIState
    }
})

$form.Add_Load({
    Queue-Log "Welcome to the OmniRoute Dashboard!"
    Update-UIState
    $logTimer.Start()

    # Auto-start OmniRoute server on launch if it's already set up and not running
    $targetDir = $txtInstallDir.Text
    $isSetup = (Test-Path $targetDir) -and (Test-Path (Join-Path $targetDir "package.json"))
    $isServerActive = $false
    if ($global:serverProcess -and -not $global:serverProcess.HasExited) {
        $isServerActive = $true
    } elseif (Test-PortActive 20128) {
        $isServerActive = $true
    }

    if ($isSetup -and -not $isServerActive) {
        Queue-Log "Auto-starting OmniRoute server..."
        $btnSmart.PerformClick()
    }
})

$form.Add_FormClosing({
    param($sender, $e)
    if ($global:serverProcess -and -not $global:serverProcess.HasExited) {
        $msgBoxResult = [System.Windows.Forms.MessageBox]::Show(
            "The OmniRoute server is still running in the background.`n`nDo you want to stop the server and exit?",
            "Stop Server?",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        
        if ($msgBoxResult -eq [System.Windows.Forms.DialogResult]::Yes) {
            Queue-Log "Stopping server before exit..."
            Start-Process "taskkill.exe" -ArgumentList "/PID $($global:serverProcess.Id) /T /F" -WindowStyle Hidden
            $global:serverProcess = $null
        } else {
            $e.Cancel = $true
        }
    }
})

$form.ShowDialog() | Out-Null
