#Requires -Version 5.1
<#
.SYNOPSIS
    一键拉起记账本全栈：MySQL（Docker）→ Spring Boot 后端 → Flutter 前端。

.DESCRIPTION
    后端和前端各自开一个独立的 PowerShell 窗口跑，这样能直接用 flutter 的热重载快捷键
    （r 热重载 / R 热重启 / q 退出）。脚本本身只做三件事：起数据库、等新组件的端口就绪、
    把拉起的进程 PID 记到 .dev\pids.json，方便 -Stop 收摊。

    重复执行是安全的：端口上已经有东西在听（比如你手动跑着后端）就跳过，不会重复启动。

.PARAMETER Target
    flutter run 的设备，默认 web-server。常用值：web-server / chrome / android / windows。
    只有 web-server、chrome、edge 支持 --web-port。

.PARAMETER ApiBaseUrl
    传给前端的 --dart-define=API_BASE_URL。留空时按 Target 推：android 用
    http://10.0.2.2:<BackendPort>（模拟器访问宿主机），其余用 http://localhost:<BackendPort>。

.PARAMETER Stop
    关掉本脚本上次拉起的后端 / 前端。MySQL 容器不动，除非同时加 -WithDb。

.PARAMETER DryRun
    只检查前置条件、打印将要执行的命令，不起容器也不开窗口。用来确认端口、地址、
    命令行拼得对不对。

.EXAMPLE
    .\dev.ps1                        # 起库 + 后端 9090 + 前端 8888，并用浏览器打开
    .\dev.ps1 -Target chrome         # 让 flutter 自己开 Chrome
    .\dev.ps1 -Target android        # 连真机/模拟器，自动带上 10.0.2.2
    .\dev.ps1 -SkipDb                # 本机已有 MySQL，跳过 docker
    .\dev.ps1 -BackendPort 9091      # 9090 被占时换端口（前端地址会跟着变）
    .\dev.ps1 -DryRun                # 先看看要跑什么
    .\dev.ps1 -Stop                  # 收摊

.EXAMPLE
    # 报“禁止运行脚本”（ExecutionPolicy）时改用同目录的包装器，它带 -ExecutionPolicy Bypass：
    dev.cmd
    dev.cmd -Stop -WithDb

.NOTES
    后端端口用 9090 而不是 8080：Windows 把 TCP 8006-8105 整段保留给了 Hyper-V/WSL2，
    8080 绑不上会直接启动失败。查看保留段：netsh interface ipv4 show excludedportrange protocol=tcp
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 65535)][int]$BackendPort = 9090,
    [ValidateRange(1, 65535)][int]$FrontendPort = 8888,
    [string]$Target = 'web-server',
    [string]$ApiBaseUrl = '',
    [int]$TimeoutSec = 300,
    [switch]$SkipDb,
    [switch]$NoBrowser,
    [switch]$DryRun,
    [switch]$Stop,
    [switch]$WithDb
)

$ErrorActionPreference = 'Stop'

$Root       = $PSScriptRoot
$BackendDir = Join-Path $Root 'ledger-backend'
$FrontDir   = Join-Path $Root 'ledger-front'
$DevDir     = Join-Path $Root '.dev'
$PidFile    = Join-Path $DevDir 'pids.json'
$DbcImage   = 'ledger-mysql'   # 与 docker-compose.yml 的 container_name 对应

# 子窗口退出时写的标记文件：父脚本靠它提前结束等待，给出人话报错而不是干等超时
$BackendFail  = Join-Path $DevDir 'backend.fail'
$FrontendFail = Join-Path $DevDir 'frontend.fail'
# 子窗口的第一条语句写这个「脚印」：没出现就说明 powershell 根本没执行到命令
$BackendBoot  = Join-Path $DevDir 'backend.boot'
$FrontendBoot = Join-Path $DevDir 'frontend.boot'

$MavenFile = if ($env:OS -eq 'Windows_NT') { 'mvnw.cmd' } else { 'mvnw' }
# PowerShell 不在当前目录里找裸命令名（不像 cmd.exe），启动后端必须带路径前缀
$MavenCall = if ($env:OS -eq 'Windows_NT') { '.\mvnw.cmd' } else { './mvnw' }
$ComposeClassic = $false      # 由 Resolve-Compose 设置：老环境只有 docker-compose

function Write-Step { param([string]$Message) Write-Host "`n==> $Message" -ForegroundColor Cyan }
function Write-Done { param([string]$Message) Write-Host "    + $Message" -ForegroundColor Green }
function Write-Note { param([string]$Message) Write-Host "    - $Message" -ForegroundColor DarkGray }
function Write-Bad  { param([string]$Message) Write-Host "    x $Message" -ForegroundColor Red }

function Test-PortListening {
    param([int]$Port, [int]$TimeoutMs = 300)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne($TimeoutMs)) { return $false }
        $client.EndConnect($async)
        return $true
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

# 返回 'up' / 'fail'（子进程自己退了） / 'nostart'（窗口没执行命令） / 'timeout'
function Wait-Component {
    param([int]$Port, [string]$FailFile, [string]$BootFile, [int]$Timeout)
    $deadline = (Get-Date).AddSeconds($Timeout)
    $bootDeadline = (Get-Date).AddSeconds(20)
    $booted = Test-Path -LiteralPath $BootFile
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $FailFile) { return 'fail' }
        if (Test-PortListening -Port $Port)   { return 'up' }
        if (-not $booted) {
            if (Test-Path -LiteralPath $BootFile) { $booted = $true }
            elseif ((Get-Date) -gt $bootDeadline) { return 'nostart' }
        }
        Start-Sleep -Milliseconds 500
    }
    return 'timeout'
}

function Get-PortOwnerPids {
    param([int]$Port)
    $pids = @()
    try {
        $pids = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction Stop |
                Select-Object -ExpandProperty OwningProcess -Unique
    } catch {
        # 拿不到 Get-NetTCPConnection（老系统 / 权限受限）时退回 netstat
        $pattern = ':' + $Port + '\s'
        $pids = netstat -ano | Select-String 'LISTENING' | Select-String $pattern |
                ForEach-Object { (($_ | Out-String).Trim() -split '\s+')[-1] } |
                Where-Object { $_ -match '^\d+$' } | Select-Object -Unique
    }
    return @($pids | ForEach-Object { [int]$_ })
}

function Resolve-Compose {
    # Docker Desktop 装的是 v2 子命令；只有老环境才需要独立的 docker-compose
    docker compose version *> $null
    $script:ComposeClassic = -not ($LASTEXITCODE -eq 0)
    if ($script:ComposeClassic -and -not (Get-Command docker-compose -ErrorAction SilentlyContinue)) {
        throw 'docker compose / docker-compose 都不可用。装 Docker Desktop，或用 -SkipDb 指向本机 MySQL'
    }
}

function Invoke-Compose {
    param([string[]]$ComposeArgs)
    if ($script:ComposeClassic) { return & docker-compose @ComposeArgs }
    return & docker (@('compose') + $ComposeArgs)
}

# 在独立窗口里跑长命令。-NoExit 保证失败时日志还留在屏幕上；显式 Bypass 是为了
# 不受本机 ExecutionPolicy 影响（父脚本可能在 Restricted 环境里被调起来）；
# 命令串内部只用单引号，免得 PS 5.1 拼原生命令行时把嵌套双引号弄坏。
function Start-WorkWindow {
    param([string]$Title, [string]$WorkDir, [string]$Command, [string]$BootFile)
    $boot = "Set-Content -LiteralPath '$BootFile' -Value (Get-Date -Format 'o'); "
    $full = "`$Host.UI.RawUI.WindowTitle = '$Title'; $boot$Command"
    return Start-Process -FilePath 'powershell.exe' `
                         -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-Command', $full) `
                         -WorkingDirectory $WorkDir -PassThru
}

# DryRun 时只把命令打出来，真的什么进程都不碰
function Invoke-WorkWindow {
    param([string]$Title, [string]$WorkDir, [string]$Command, [string]$BootFile)
    if ($DryRun) {
        Write-Note "DRY-RUN：将在新窗口 '$Title'（$WorkDir）里执行"
        Write-Host "        $Command" -ForegroundColor DarkGray
        return $null
    }
    return Start-WorkWindow -Title $Title -WorkDir $WorkDir -Command $Command -BootFile $BootFile
}

function Stop-Tree {
    param([int]$ProcessId, [string]$Label)
    if ($DryRun) { Write-Note "DRY-RUN：将结束 $Label（PID $ProcessId 及其子进程）"; return }
    & taskkill.exe /PID $ProcessId /T /F *> $null
    if (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) {
        Write-Bad "结束 $Label（PID $ProcessId）失败，请手动处理：taskkill /PID $ProcessId /T /F"
    } else {
        Write-Done "已结束 $Label（PID $ProcessId 及其子进程）"
    }
}

function Require-Command {
    param([string]$Name, [string]$Hint)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "找不到命令 '$Name'。$Hint"
    }
}

# ---------------------------------------------------------------- 收摊模式
if ($Stop) {
    Write-Step '停止脚本拉起的前后端'

    # 端口默认沿用上次启动时记下来的，免得 -Stop 去探错端口（显式传参则听你的）
    $stopBackendPort  = $BackendPort
    $stopFrontendPort = $FrontendPort
    $recorded = $null

    if (Test-Path -LiteralPath $PidFile) {
        $recorded = Get-Content -LiteralPath $PidFile -Raw | ConvertFrom-Json
        if (-not $PSBoundParameters.ContainsKey('BackendPort')  -and $recorded.backendPort)  { $stopBackendPort  = [int]$recorded.backendPort }
        if (-not $PSBoundParameters.ContainsKey('FrontendPort') -and $recorded.frontendPort) { $stopFrontendPort = [int]$recorded.frontendPort }
        Write-Note "沿用上次记录：后端 :$stopBackendPort / 前端 :$stopFrontendPort"
        foreach ($entry in @($recorded.PSObject.Properties)) {
            if ($entry.Name -notin 'backend', 'frontend') { continue }
            $procId = [int]$entry.Value
            if ($procId -le 0) { Write-Note "$($entry.Name) 是复用的已有进程，不在本脚本名下，跳过"; continue }
            if (Get-Process -Id $procId -ErrorAction SilentlyContinue) {
                Stop-Tree -ProcessId $procId -Label $entry.Name
            } else {
                Write-Note "$($entry.Name)（PID $procId）的窗口已经被关掉了"
            }
        }
        if ($DryRun) { Write-Note "DRY-RUN：保留 $PidFile" }
        else { Remove-Item -LiteralPath $PidFile -Force }
    } else {
        Write-Note "没有 .dev\pids.json，只能按端口兜底（要停的端口不对就显式传参）"
    }

    # 兜底：窗口被手动关掉、或者上次是手动起的，只要端口还被这类进程占着就清掉
    foreach ($probe in @(@{ Label = '后端'; Port = $stopBackendPort }, @{ Label = '前端'; Port = $stopFrontendPort })) {
        foreach ($owner in (Get-PortOwnerPids -Port $probe.Port)) {
            $proc = Get-Process -Id $owner -ErrorAction SilentlyContinue
            if (-not $proc) { continue }
            if ('java', 'dart', 'flutter', 'cmd' -contains $proc.ProcessName) {
                Stop-Tree -ProcessId $owner -Label "$($probe.Label)（占用 $($probe.Port) 的 $($proc.ProcessName)）"
            } else {
                Write-Bad ("端口 {0} 仍被 {1}（PID {2}）占用，不像本项目拉起的进程，请自行确认后处理" -f
                    $probe.Port, $proc.ProcessName, $owner)
            }
        }
    }

    foreach ($stale in @($BackendFail, $FrontendFail, $BackendBoot, $FrontendBoot)) {
        if ($DryRun -and (Test-Path -LiteralPath $stale)) { Write-Note "DRY-RUN：保留 $stale"; continue }
        Remove-Item -LiteralPath $stale -Force -ErrorAction SilentlyContinue
    }

    if ($WithDb) {
        Write-Step '停止 MySQL 容器'
        Push-Location $BackendDir
        try {
            Resolve-Compose
            if ($DryRun) {
                Write-Note "DRY-RUN：将执行 docker compose stop $DbcImage"
            } else {
                Invoke-Compose -ComposeArgs @('stop', $DbcImage) | Out-Null
                Write-Done "$DbcImage 已停止（数据卷保留）"
            }
        } catch {
            Write-Bad $_
        } finally {
            Pop-Location
        }
    } else {
        Write-Note 'MySQL 容器保持运行；要一起停就加 -WithDb'
    }
    return
}

# ---------------------------------------------------------------- 启动模式
New-Item -ItemType Directory -Path $DevDir -Force | Out-Null
foreach ($stale in @($BackendFail, $FrontendFail, $BackendBoot, $FrontendBoot)) {
    Remove-Item -LiteralPath $stale -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path -LiteralPath (Join-Path $BackendDir 'pom.xml')))     { throw "没找到后端项目：$BackendDir" }
if (-not (Test-Path -LiteralPath (Join-Path $FrontDir 'pubspec.yaml'))) { throw "没找到前端项目：$FrontDir" }

Write-Step '前置检查'
Require-Command -Name 'flutter' -Hint '装 Flutter SDK 或把它的 bin 目录加进 PATH（Maven 用项目自带的 mvnw，不需要全局 mvn）'
Require-Command -Name 'java'    -Hint '后端需要 JDK 17+'
if (-not (Test-Path -LiteralPath (Join-Path $BackendDir $MavenFile))) { throw "没找到 $(Join-Path $BackendDir $MavenFile)" }
Write-Done "flutter / java / $MavenFile 就绪"

if (-not $SkipDb) {
    Require-Command -Name 'docker' -Hint '后端依赖 MySQL，请先装 Docker Desktop；本机已有 MySQL 可加 -SkipDb'
    docker info *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker 引擎没在跑。启动 Docker Desktop 后重试，或用 -SkipDb 指向本机 MySQL' }
    Resolve-Compose
    Write-Done 'docker 引擎就绪'
}

# 1) MySQL
if ($SkipDb) {
    Write-Step '1/4 MySQL（-SkipDb，跳过 docker compose）'
    if (-not (Test-PortListening -Port 3306 -TimeoutMs 1500)) {
        Write-Bad '本机 3306 没在监听，后端启动大概会 Connection refused'
    } else {
        Write-Done '沿用本机已有 MySQL:3306'
    }
} else {
    Write-Step '1/4 MySQL（docker compose）'
    Push-Location $BackendDir
    try {
        docker inspect -f '{{.State.Status}}' $DbcImage *> $null
        $exists = ($LASTEXITCODE -eq 0)
        $state = if ($exists) { (docker inspect -f '{{.State.Status}}' $DbcImage) 2>$null } else { '未创建' }
        if ($state -eq 'running') {
            Write-Done "$DbcImage 已在运行，跳过 compose up"
        } elseif ($DryRun) {
            Write-Note "DRY-RUN：将在 $BackendDir 执行 docker compose up -d（容器当前：$state）"
        } else {
            Invoke-Compose -ComposeArgs @('up', '-d') | ForEach-Object { Write-Note $_ }
        }

        if ($DryRun) {
            Write-Note 'DRY-RUN：不等待 healthy，也不探测 3306'
        } else {
            # compose 里已定义 healthcheck。等到 healthy 再起后端，免得后端连不上库、
            # 崩在第一行日志里还要回头查是不是数据库没好。
            $deadline = (Get-Date).AddSeconds(180)
            $ready = $false
            while ((Get-Date) -lt $deadline) {
                $health = (docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $DbcImage) 2>$null
                if ($health -eq 'healthy' -or $health -eq 'running') { $ready = $true; break }
                Start-Sleep -Seconds 2
            }
            if (-not $ready) { throw "等 $DbcImage 就绪超时，先看 docker logs $DbcImage" }
            if (-not (Test-PortListening -Port 3306)) { throw 'MySQL 3306 连不上，检查 docker-compose.yml 的端口映射' }
            Write-Done 'MySQL 就绪：localhost:3306 / ledger'
        }
    } finally {
        Pop-Location
    }
}

# 2) 后端 Spring Boot
$backendProc = $null
if (Test-PortListening -Port $BackendPort) {
    Write-Step "2/4 后端 Spring Boot :$BackendPort"
    $owner = (Get-PortOwnerPids -Port $BackendPort | Select-Object -First 1)
    Write-Done "端口已被 PID $owner 占用，复用已在跑的后端，不重复启动"
} else {
    Write-Step "2/4 后端 Spring Boot :$BackendPort"
    $backendCmd = "Set-Location -LiteralPath '$BackendDir'; " +
        "`$env:SERVER_PORT = '$BackendPort'; " +
        "& $MavenCall spring-boot:run; " +
        "if (`$LASTEXITCODE -ne 0) { Set-Content -LiteralPath '$BackendFail' -Value ('mvnw spring-boot:run exit code ' + `$LASTEXITCODE) }"
    $backendProc = Invoke-WorkWindow -Title 'ledger-backend' -WorkDir $BackendDir -Command $backendCmd -BootFile $BackendBoot
    if ($DryRun) {
        Write-Note 'DRY-RUN：不开窗口、不等端口'
    } else {
        Write-Note "窗口已打开，等 :$BackendPort 就绪（最长 $TimeoutSec 秒，日志在那个窗口里）"
        switch (Wait-Component -Port $BackendPort -FailFile $BackendFail -BootFile $BackendBoot -Timeout $TimeoutSec) {
            'up'      { Write-Done "后端就绪：http://localhost:$BackendPort" }
            'fail'    { Write-Bad "后端启动失败：$(Get-Content -LiteralPath $BackendFail -Raw)"; throw '翻 ledger-backend 窗口的日志。常见原因：MySQL 没就绪、ddl-auto=validate 撞上表结构与实体不一致' }
            'nostart' { Write-Bad "后端窗口没执行到命令（也没报错）"; throw '十有八九是 powershell 解析命令失败或被安全软件拦下。翻 ledger-backend 窗口看红字' }
            'timeout' { Write-Bad "等后端 :$BackendPort 超时"; throw '常见原因：mvnw 在下第一个包（慢网/离线），或端口落在 Windows 保留段。翻 ledger-backend 窗口的日志' }
        }
    }
}

# 3) 前端 Flutter
if (-not $ApiBaseUrl) {
    # Android 模拟器看不到宿主机的 localhost，要用 10.0.2.2
    $ApiBaseUrl = if ($Target -match 'android') { "http://10.0.2.2:$BackendPort" } else { "http://localhost:$BackendPort" }
}
$webBased = $Target -in 'web-server', 'chrome', 'edge'
$frontendProc = $null

if (Test-PortListening -Port $FrontendPort) {
    Write-Step "3/4 前端 Flutter :$FrontendPort"
    $owner = (Get-PortOwnerPids -Port $FrontendPort | Select-Object -First 1)
    Write-Done "端口已被 PID $owner 占用，复用已在跑的前端，不重复启动"
} else {
    Write-Step "3/4 前端 Flutter（-d $Target）"
    $flutterArgs = "flutter run -d $Target --dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($webBased) { $flutterArgs += " --web-port $FrontendPort" }
    $frontendCmd = "Set-Location -LiteralPath '$FrontDir'; " +
        "$flutterArgs; " +
        "if (`$LASTEXITCODE -ne 0) { Set-Content -LiteralPath '$FrontendFail' -Value ('flutter run exit code ' + `$LASTEXITCODE) }"
    $frontendProc = Invoke-WorkWindow -Title 'ledger-front (flutter run)' -WorkDir $FrontDir -Command $frontendCmd -BootFile $FrontendBoot
    if ($DryRun) {
        Write-Note 'DRY-RUN：不开窗口、不等端口'
    } elseif ($webBased) {
        Write-Note "窗口已打开。首次 build 要一两分钟，最长等 $TimeoutSec 秒"
        switch (Wait-Component -Port $FrontendPort -FailFile $FrontendFail -BootFile $FrontendBoot -Timeout $TimeoutSec) {
            'up'      { Write-Done "前端就绪：http://localhost:$FrontendPort" }
            'fail'    { Write-Bad "前端启动失败：$(Get-Content -LiteralPath $FrontendFail -Raw)"; throw '翻 ledger-front 窗口的日志，flutter doctor 能查环境问题' }
            'nostart' { Write-Bad "前端窗口没执行到命令（也没报错）"; throw '十有八九是 powershell 解析命令失败或被安全软件拦下。翻 ledger-front 窗口看红字' }
            'timeout' { Write-Bad "等前端 :$FrontendPort 超时"; throw '翻 ledger-front 窗口的日志；设备 id 用 flutter devices 查' }
        }
    } else {
        Write-Done "已在独立窗口发起 flutter run -d $Target（非 web 目标没有本地端口可探测）"
    }
}

# 4) 记 PID + 开浏览器
Write-Step '4/4 就绪'
if ($DryRun) {
    Write-Note 'DRY-RUN：不写 .dev\pids.json，不开浏览器'
} else {
    [ordered]@{
        backend      = if ($backendProc)  { $backendProc.Id }  else { 0 }
        frontend     = if ($frontendProc) { $frontendProc.Id } else { 0 }
        backendPort  = $BackendPort
        frontendPort = $FrontendPort
        startedAt    = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    } | ConvertTo-Json | Set-Content -LiteralPath $PidFile -Encoding UTF8
    Write-Note "PID 记录在 $PidFile"

    if ($Target -eq 'web-server' -and -not $NoBrowser -and (Test-PortListening -Port $FrontendPort)) {
        Start-Process "http://localhost:$FrontendPort"
        Write-Done "已用默认浏览器打开 http://localhost:$FrontendPort"
    }
}

Write-Host ''
if ($DryRun) {
    Write-Host ' DRY-RUN：以上只是"将要执行"的动作，没有起容器、没有开窗口' -ForegroundColor Yellow
} else {
    Write-Host ' 记账本全栈已拉起' -ForegroundColor Green
    if ($webBased) {
        Write-Host "   前端   http://localhost:$FrontendPort   窗口 ledger-front (flutter run)：r 热重载 / R 热重启 / q 退出"
    } else {
        Write-Host "   前端   flutter run -d $Target   窗口 ledger-front (flutter run)：r 热重载 / R 热重启 / q 退出"
    }
    Write-Host "   后端   http://localhost:$BackendPort    窗口 ledger-backend"
    Write-Host "   前端连的后端地址  $ApiBaseUrl"
    if (-not $SkipDb) { Write-Host "   数据库 localhost:3306  ledger / ledger-dev（容器 $DbcImage）" }
    Write-Host ''
    Write-Host '   收摊： .\dev.ps1 -Stop   （加 -WithDb 连 MySQL 一起停）' -ForegroundColor DarkGray
}
Write-Host ''
