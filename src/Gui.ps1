# OpenRuntime — beginner-friendly WinForms UI (Win7+)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function Get-OpenRuntimeBannerPath {
    $bannerPath = $null
    if (Get-Command Resolve-OpenRuntimeOfflineFile -ErrorAction SilentlyContinue) {
        $bannerPath = Resolve-OpenRuntimeOfflineFile -FileName 'banner.jpg'
        if (-not $bannerPath) { $bannerPath = Resolve-OpenRuntimeOfflineFile -FileName 'index002.jpg' }
    }
    if (-not $bannerPath -and $script:OpenRuntimeRoot) {
        $tryBanner = @(
            (Join-Path $script:OpenRuntimeRoot 'assets\banner.jpg'),
            (Join-Path $script:OpenRuntimeRoot 'assets\index002.jpg'),
            (Join-Path $script:OpenRuntimeRoot 'banner.jpg'),
            (Join-Path $script:OpenRuntimeRoot 'index002.jpg')
        )
        foreach ($tb in $tryBanner) {
            if (Test-Path -LiteralPath $tb) { return $tb }
        }
    }
    return $bannerPath
}

function New-OpenRuntimeFadedBackground {
    param(
        [string]$ImagePath,
        [int]$Width,
        [int]$Height,
        [int]$WashAlpha = 210
    )
    # 整页淡化背景：先铺底色，再画原图，再盖一层半透明白雾
    if ($Width -lt 32) { $Width = 860 }
    if ($Height -lt 32) { $Height = 720 }
    $bytes = [System.IO.File]::ReadAllBytes($ImagePath)
    $ms = New-Object System.IO.MemoryStream(,$bytes)
    $src = [System.Drawing.Image]::FromStream($ms)
    $bmp = New-Object System.Drawing.Bitmap $Width, $Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.Clear([System.Drawing.Color]::FromArgb(245, 247, 250))
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        # 居中覆盖绘制（类似 Zoom）
        $scale = [Math]::Max(([double]$Width / $src.Width), ([double]$Height / $src.Height))
        $dw = [int]($src.Width * $scale)
        $dh = [int]($src.Height * $scale)
        $dx = [int](($Width - $dw) / 2)
        $dy = [int](($Height - $dh) / 2)
        $g.DrawImage($src, $dx, $dy, $dw, $dh)
        # 白雾淡化（数值越大越淡）
        $wash = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($WashAlpha, 248, 250, 252))
        $g.FillRectangle($wash, 0, 0, $Width, $Height)
        $wash.Dispose()
    }
    finally {
        $g.Dispose()
        $src.Dispose()
        $ms.Dispose()
    }
    return $bmp
}

function Show-OpenRuntimeGui {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'OpenRuntime — 一键修复运行库（小白专用）'
    $form.Size = New-Object System.Drawing.Size(860, 720)
    $form.StartPosition = 'CenterScreen'
    $form.MinimumSize = New-Object System.Drawing.Size(780, 640)
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
    try {
        $db = $form.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'Instance, NonPublic')
        if ($db) { $db.SetValue($form, $true, $null) }
    }
    catch { }

    $uiFontName = 'Microsoft YaHei'
    try {
        $tf = New-Object System.Drawing.Font($uiFontName, 9)
        $tf.Dispose()
    }
    catch { $uiFontName = 'Tahoma' }
    $form.Font = New-Object System.Drawing.Font($uiFontName, 9)

    $info = Get-OpenRuntimeSystemInfo

    # ---- 整页淡化背景（不是顶栏小图）----
    $script:OrBgSourcePath = Get-OpenRuntimeBannerPath
    $script:OrBgImage = $null
    function Set-OrFormBackground {
        if (-not $script:OrBgSourcePath) { return }
        if (-not (Test-Path -LiteralPath $script:OrBgSourcePath)) { return }
        try {
            $w = $form.ClientSize.Width
            $h = $form.ClientSize.Height
            if ($w -lt 40 -or $h -lt 40) { return }
            $newBmp = New-OpenRuntimeFadedBackground -ImagePath $script:OrBgSourcePath -Width $w -Height $h -WashAlpha 208
            $old = $form.BackgroundImage
            $form.BackgroundImage = $newBmp
            $form.BackgroundImageLayout = 'Stretch'
            $script:OrBgImage = $newBmp
            if ($old -and $old -ne $newBmp) {
                try { $old.Dispose() } catch { }
            }
        }
        catch { }
    }
    Set-OrFormBackground

    $y0 = 12

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = 'OpenRuntime'
    $lblTitle.Font = New-Object System.Drawing.Font($uiFontName, 18, [Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [Drawing.Color]::FromArgb(20, 60, 110)
    $lblTitle.Location = New-Object Drawing.Point(18, $y0)
    $lblTitle.AutoSize = $true
    $lblTitle.BackColor = [Drawing.Color]::Transparent
    $form.Controls.Add($lblTitle)

    $lblSub = New-Object System.Windows.Forms.Label
    $offlineHint = '可离线安装'
    if (-not $info.OfflineReady) { $offlineHint = '离线包缺失' }
    $lblSub.Text = "https://github.com/maya970 · $offlineHint · 点下面绿色大按钮即可，无需手动操作"
    $lblSub.Location = New-Object Drawing.Point(20, ($y0 + 36))
    $lblSub.AutoSize = $true
    $lblSub.ForeColor = [Drawing.Color]::FromArgb(70, 80, 95)
    $lblSub.BackColor = [Drawing.Color]::Transparent
    $form.Controls.Add($lblSub)

    $adminText = '请用管理员运行'
    if ($info.IsAdmin) { $adminText = '管理员已就绪' }
    $lblSys = New-Object System.Windows.Forms.Label
    $lblSys.Text = "$($info.Caption) $($info.Arch) | PS $($info.PSVersion) | $adminText"
    $lblSys.Location = New-Object Drawing.Point(20, ($y0 + 58))
    $lblSys.AutoSize = $true
    $lblSys.ForeColor = [Drawing.Color]::FromArgb(50, 70, 90)
    $lblSys.BackColor = [Drawing.Color]::Transparent
    $form.Controls.Add($lblSys)

    $listTop = $y0 + 88
    $list = New-Object System.Windows.Forms.ListView
    $list.View = 'Details'
    $list.FullRowSelect = $true
    $list.GridLines = $true
    $list.CheckBoxes = $true
    $list.Location = New-Object Drawing.Point(18, $listTop)
    $list.Size = New-Object Drawing.Size(808, 250)
    $list.Anchor = 'Top,Bottom,Left,Right'
    # 半透感：浅白底，四周露出淡化背景
    $list.BackColor = [Drawing.Color]::FromArgb(252, 253, 255)
    [void]$list.Columns.Add('状态', 80)
    [void]$list.Columns.Add('名称', 300)
    [void]$list.Columns.Add('类别', 90)
    [void]$list.Columns.Add('说明', 300)
    $form.Controls.Add($list)

    # ---- Progress / log panel ----
    $pnlProgress = New-Object System.Windows.Forms.Panel
    $pnlProgress.Location = New-Object Drawing.Point(18, 430)
    $pnlProgress.Size = New-Object Drawing.Size(808, 150)
    $pnlProgress.Anchor = 'Bottom,Left,Right'
    $pnlProgress.BackColor = [Drawing.Color]::FromArgb(245, 248, 252)
    $pnlProgress.BorderStyle = 'FixedSingle'
    $form.Controls.Add($pnlProgress)

    $lblPhase = New-Object System.Windows.Forms.Label
    $lblPhase.Text = '就绪'
    $lblPhase.Font = New-Object Drawing.Font($uiFontName, 10, [Drawing.FontStyle]::Bold)
    $lblPhase.Location = New-Object Drawing.Point(10, 8)
    $lblPhase.Size = New-Object Drawing.Size(780, 22)
    $lblPhase.BackColor = [Drawing.Color]::Transparent
    $pnlProgress.Controls.Add($lblPhase)

    $progress = New-Object System.Windows.Forms.ProgressBar
    $progress.Location = New-Object Drawing.Point(10, 34)
    $progress.Size = New-Object Drawing.Size(780, 22)
    $progress.Anchor = 'Top,Left,Right'
    $progress.Style = 'Continuous'
    $pnlProgress.Controls.Add($progress)

    $progressMarquee = New-Object System.Windows.Forms.ProgressBar
    $progressMarquee.Location = New-Object Drawing.Point(10, 60)
    $progressMarquee.Size = New-Object Drawing.Size(780, 12)
    $progressMarquee.Anchor = 'Top,Left,Right'
    $progressMarquee.Style = 'Marquee'
    $progressMarquee.MarqueeAnimationSpeed = 30
    $progressMarquee.Visible = $false
    $pnlProgress.Controls.Add($progressMarquee)

    $txtLog = New-Object System.Windows.Forms.TextBox
    $txtLog.Multiline = $true
    $txtLog.ScrollBars = 'Vertical'
    $txtLog.ReadOnly = $true
    $txtLog.Location = New-Object Drawing.Point(10, 78)
    $txtLog.Size = New-Object Drawing.Size(780, 62)
    $txtLog.Anchor = 'Top,Bottom,Left,Right'
    $txtLog.BackColor = [Drawing.Color]::White
    $txtLog.Text = '检测完成后，点「一键全部安装」即可。安装时下方会显示正在做什么。'
    $pnlProgress.Controls.Add($txtLog)

    function Add-UiLog {
        param([string]$Message)
        $line = ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message)
        if ($txtLog.Text.Length -gt 4000) {
            $txtLog.Text = $txtLog.Text.Substring($txtLog.Text.Length - 3000)
        }
        if ([string]::IsNullOrEmpty($txtLog.Text)) {
            $txtLog.Text = $line
        }
        else {
            $txtLog.AppendText("`r`n" + $line)
        }
        $txtLog.SelectionStart = $txtLog.Text.Length
        $txtLog.ScrollToCaret()
        $lblPhase.Text = $Message
        try { [System.Windows.Forms.Application]::DoEvents() } catch { }
    }

    function Set-UiBusy {
        param([bool]$Busy)
        $btnOneClick.Enabled = (-not $Busy)
        $btnInstallSelected.Enabled = (-not $Busy)
        $btnRefresh.Enabled = (-not $Busy)
        $btnFixApp.Enabled = (-not $Busy)
        $progressMarquee.Visible = $Busy
        if ($Busy) {
            $form.UseWaitCursor = $true
            $lblPhase.ForeColor = [Drawing.Color]::FromArgb(20, 90, 160)
        }
        else {
            $form.UseWaitCursor = $false
            $lblPhase.ForeColor = [Drawing.Color]::FromArgb(30, 40, 50)
        }
    }

    function Refresh-List {
        $list.Items.Clear()
        $rows = Get-OpenRuntimeStatusList
        foreach ($r in $rows) {
            $item = New-Object System.Windows.Forms.ListViewItem($r.Status)
            [void]$item.SubItems.Add($r.Name)
            [void]$item.SubItems.Add($r.Category)
            [void]$item.SubItems.Add($r.Note)
            $item.Tag = $r
            if (-not $r.Installed) {
                $item.Checked = $true
                $item.ForeColor = [Drawing.Color]::FromArgb(160, 60, 20)
            }
            else {
                $item.Checked = $false
                $item.ForeColor = [Drawing.Color]::FromArgb(30, 120, 60)
            }
            [void]$list.Items.Add($item)
        }
        $missing = 0
        foreach ($r in $rows) { if (-not $r.Installed) { $missing++ } }
        Add-UiLog ("检测完成：共 {0} 项，还缺 {1} 项。" -f $rows.Count, $missing)
        return $missing
    }

    $btnOneClick = New-Object System.Windows.Forms.Button
    $btnOneClick.Text = '一键全部安装（推荐）'
    $btnOneClick.Font = New-Object Drawing.Font($uiFontName, 11, [Drawing.FontStyle]::Bold)
    $btnOneClick.Location = New-Object Drawing.Point(18, 592)
    $btnOneClick.Size = New-Object Drawing.Size(260, 44)
    $btnOneClick.Anchor = 'Bottom,Left'
    $btnOneClick.BackColor = [Drawing.Color]::FromArgb(30, 140, 70)
    $btnOneClick.ForeColor = [Drawing.Color]::White
    $btnOneClick.FlatStyle = 'Flat'
    $form.Controls.Add($btnOneClick)

    $btnInstallSelected = New-Object System.Windows.Forms.Button
    $btnInstallSelected.Text = '只装勾选的'
    $btnInstallSelected.Location = New-Object Drawing.Point(290, 598)
    $btnInstallSelected.Size = New-Object Drawing.Size(120, 36)
    $btnInstallSelected.Anchor = 'Bottom,Left'
    $form.Controls.Add($btnInstallSelected)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Text = '重新检测'
    $btnRefresh.Location = New-Object Drawing.Point(420, 598)
    $btnRefresh.Size = New-Object Drawing.Size(100, 36)
    $btnRefresh.Anchor = 'Bottom,Left'
    $btnRefresh.Add_Click({ [void](Refresh-List) })
    $form.Controls.Add($btnRefresh)

    $btnFixApp = New-Object System.Windows.Forms.Button
    $btnFixApp.Text = '修复 Win7 打不开的程序…'
    $btnFixApp.Location = New-Object Drawing.Point(530, 598)
    $btnFixApp.Size = New-Object Drawing.Size(186, 36)
    $btnFixApp.Anchor = 'Bottom,Left'
    $btnFixApp.Visible = (Test-OrIsWin7)
    $btnFixApp.Add_Click({
        if (-not (Test-IsAdministrator)) {
            [void][System.Windows.Forms.MessageBox]::Show("需要管理员权限。`n请右键 Install.bat → 以管理员身份运行。", '需要管理员权限', 'OK', 'Warning')
            return
        }
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title = '选择在 Win7 上打不开的程序（exe）'
        $dlg.Filter = '程序 (*.exe)|*.exe'
        if ($dlg.ShowDialog() -ne 'OK') { return }
        Set-UiBusy $true
        $prog = { param($msg) Add-UiLog $msg }
        $r = $null
        try { $r = Repair-OrWin7App -Path $dlg.FileName -Progress $prog }
        catch { Add-UiLog ('异常：' + $_.Exception.Message) }
        Set-UiBusy $false
        if ($r) {
            Add-UiLog $r.Message
            $icon = 'Information'
            if (-not $r.Ok -or $r.Uncovered.Count -gt 0) { $icon = 'Warning' }
            [void][System.Windows.Forms.MessageBox]::Show($r.Message + "`n`n现在可以直接双击运行该程序。", '修复结果', 'OK', $icon)
        }
    })
    $form.Controls.Add($btnFixApp)

    $btnAbout = New-Object System.Windows.Forms.Button
    $btnAbout.Text = '使用说明'
    $btnAbout.Location = New-Object Drawing.Point(726, 598)
    $btnAbout.Size = New-Object Drawing.Size(100, 36)
    $btnAbout.Anchor = 'Bottom,Right'
    $btnAbout.Add_Click({
        [void][System.Windows.Forms.MessageBox]::Show(
            "给完全小白的用法：`n`n" +
            "1. 右键 Install.bat → 以管理员身份运行`n" +
            "2. 点绿色「一键全部安装」`n" +
            "3. 看着下方进度条，不要强制关闭`n" +
            "4. 装完后如提示重启，请重启电脑`n`n" +
            "额外组件：`n" +
            "• Locale Emulator：右键程序 → Locale Emulator → 用日语运行`n" +
            "• Win7 打不开新软件（提示「无法定位程序输入点」等）：点「修复 Win7 打不开的程序」选择该程序，或把 exe 拖到 Fix-Win7App.bat 上`n`n" +
            "https://github.com/maya970",
            '使用说明',
            'OK',
            'Information'
        )
    })
    $form.Controls.Add($btnAbout)

    function Invoke-InstallRows {
        param([object[]]$Rows)

        if (-not (Test-IsAdministrator)) {
            [void][System.Windows.Forms.MessageBox]::Show(
                "需要管理员权限。`n请关闭窗口，右键 Install.bat → 以管理员身份运行。",
                '需要管理员权限', 'OK', 'Warning'
            )
            return
        }
        if (-not $Rows -or @($Rows).Count -eq 0) {
            Add-UiLog '没有需要安装的项目，已经齐了。'
            return
        }

        Set-UiBusy $true
        $progress.Value = 0
        $progress.Maximum = @($Rows).Count
        $ok = 0; $fail = 0; $skip = 0
        $idx = 0
        $total = @($Rows).Count

        foreach ($row in $Rows) {
            $idx++
            Add-UiLog ("[{0}/{1}] 开始：{2}" -f $idx, $total, $row.Name)
            $prog = {
                param($msg)
                Add-UiLog $msg
            }
            try {
                $r = Install-OpenRuntimeItem -Item $row.Item -Progress $prog
                if ($r.Skipped) {
                    $skip++
                    Add-UiLog ("跳过（已安装）：{0}" -f $row.Name)
                }
                elseif ($r.Success) {
                    $ok++
                    Add-UiLog ("完成：{0} → {1}" -f $row.Name, $r.Message)
                }
                else {
                    $fail++
                    Add-UiLog ("失败：{0} → {1}" -f $row.Name, $r.Message)
                }
            }
            catch {
                $fail++
                Add-UiLog ("异常：{0} → {1}" -f $row.Name, $_.Exception.Message)
            }
            $progress.Value = $idx
            try { [System.Windows.Forms.Application]::DoEvents() } catch { }
        }

        [void](Refresh-List)
        Set-UiBusy $false
        Add-UiLog ("全部结束：成功 {0}，跳过 {1}，失败 {2}" -f $ok, $skip, $fail)

        $tip = "安装流程结束。`n成功 $ok，跳过 $skip，失败 $fail。`n`n"
        $tip += "【以后怎么用】`n"
        $tip += "日文游戏乱码：右键程序 → Locale Emulator → 用日语运行`n"
        $tip += "Win7 打不开新软件：点「修复 Win7 打不开的程序」选择它`n"
        $tip += "`n若提示需要重启，请重启后再试软件。"
        $icon = 'Information'
        if ($fail -gt 0) { $icon = 'Warning' }
        [void][System.Windows.Forms.MessageBox]::Show($tip, '安装结果', 'OK', $icon)
    }

    $btnOneClick.Add_Click({
        $rows = @()
        foreach ($it in $list.Items) {
            if (-not $it.Tag.Installed) { $rows += $it.Tag }
        }
        if (@($rows).Count -eq 0) {
            [void][System.Windows.Forms.MessageBox]::Show('已经全部安装好了，无需再装。', '提示', 'OK', 'Information')
            return
        }
        $ans = [System.Windows.Forms.MessageBox]::Show(
            ("将自动安装 {0} 个缺失组件。`n过程可能要几分钟，请耐心等待，不要强制关闭窗口。" -f @($rows).Count),
            '确认一键安装',
            'YesNo',
            'Question'
        )
        if ($ans -eq 'Yes') {
            Invoke-InstallRows -Rows $rows
        }
    })

    $btnInstallSelected.Add_Click({
        $rows = @()
        foreach ($it in $list.Items) {
            if ($it.Checked) { $rows += $it.Tag }
        }
        Invoke-InstallRows -Rows $rows
    })

    $script:OrBgResizeTick = 0
    $form.Add_Shown({
        Set-OrFormBackground
        $missing = Refresh-List
        if ($missing -gt 0 -and $info.IsAdmin) {
            $ans = [System.Windows.Forms.MessageBox]::Show(
                ("检测到还缺 {0} 个组件。`n`n要现在一键自动安装吗？`n（推荐：直接点「是」）" -f $missing),
                'OpenRuntime 自动检测',
                'YesNo',
                'Question'
            )
            if ($ans -eq 'Yes') {
                $rows = @()
                foreach ($it in $list.Items) {
                    if (-not $it.Tag.Installed) { $rows += $it.Tag }
                }
                Invoke-InstallRows -Rows $rows
            }
        }
        elseif (-not $info.IsAdmin) {
            [void][System.Windows.Forms.MessageBox]::Show(
                "当前不是管理员。`n请关闭后，右键 Install.bat → 以管理员身份运行。",
                '需要管理员',
                'OK',
                'Warning'
            )
        }
    })

    # Keep progress panel above list bottom padding + refresh faded bg
    $form.Add_Resize({
        $pnlProgress.Top = $form.ClientSize.Height - 230
        $btnOneClick.Top = $form.ClientSize.Height - 70
        $btnInstallSelected.Top = $form.ClientSize.Height - 64
        $btnRefresh.Top = $form.ClientSize.Height - 64
        $btnFixApp.Top = $form.ClientSize.Height - 64
        $btnAbout.Top = $form.ClientSize.Height - 64
        $list.Height = $pnlProgress.Top - $list.Top - 10
        $script:OrBgResizeTick++
        $tick = $script:OrBgResizeTick
        # 简单防抖：尺寸稳定后再重绘背景
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 180
        $timer.Add_Tick({
            $timer.Stop()
            $timer.Dispose()
            if ($tick -eq $script:OrBgResizeTick) {
                Set-OrFormBackground
            }
        })
        $timer.Start()
    })

    [void]$form.ShowDialog()
}
