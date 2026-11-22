# Atualizador do Vanilla++ - baixa so o que mudou, apaga mod velho e respeita o que o jogador mudou.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Base = 'https://raw.githubusercontent.com/islan-max/vanillapp/main/'
if ($env:VPP_BASE) { $Base = $env:VPP_BASE }
$Root = (Get-Location).Path
$Game = $null
foreach ($c in @('.minecraft', 'minecraft', '.')) {
    $p = Join-Path $Root $c
    if ((Test-Path (Join-Path $p 'mods')) -or (Test-Path (Join-Path $p 'options.txt'))) { $Game = (Resolve-Path $p).Path; break }
}
if (-not $Game) {
    Write-Host 'Nao achei a pasta do jogo aqui.' -ForegroundColor Red
    Write-Host 'Coloca o ATUALIZAR.bat dentro da pasta da instancia do Vanilla++ (onde fica a pasta mods ou .minecraft).'
    exit 1
}
Write-Host "Pasta do jogo: $Game"
# atualizacao baixada pelo jogo que nao foi aplicada (ex.: launcher fechou o ajudante): aplica agora
$Stage = Join-Path $Game '.vanillapp-novo'
if (Test-Path $Stage) {
    $rmf = Join-Path $Stage '.remover.txt'
    if (Test-Path $rmf) { Get-Content $rmf | Where-Object { $_.Trim() } | ForEach-Object { Remove-Item -LiteralPath (Join-Path $Game ($_ -replace '/', '\')) -Force -ErrorAction SilentlyContinue }; Remove-Item $rmf -Force }
    Get-ChildItem -LiteralPath $Stage -Recurse -File -Force | ForEach-Object {
        $dst = Join-Path $Game $_.FullName.Substring($Stage.Length + 1)
        New-Item -ItemType Directory -Path (Split-Path $dst -Parent) -Force | Out-Null
        Move-Item -LiteralPath $_.FullName -Destination $dst -Force
    }
    Remove-Item -LiteralPath $Stage -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host 'Apliquei a atualizacao que o jogo tinha baixado.'
}
$Wc = New-Object System.Net.WebClient
$Wc.Headers['User-Agent'] = 'vanillapp-updater'
$Man = ($Wc.DownloadString($Base + 'manifest.json?t=' + [DateTime]::UtcNow.Ticks)) | ConvertFrom-Json
Write-Host "Versao no ar: $($Man.name) $($Man.version)" -ForegroundColor Cyan

$StateFile = Join-Path $Game '.vanillapp-estado.json'
$State = @{}
if (Test-Path $StateFile) {
    (Get-Content $StateFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $State[$_.Name] = $_.Value }
}
function Sha1($f) { (Get-FileHash -Algorithm SHA1 -LiteralPath $f).Hash.ToLower() }
function Full($rel) { Join-Path $Game ($rel -replace '/', [IO.Path]::DirectorySeparatorChar) }

$baixados = 0; $mantidos = @(); $apagados = 0
$noPack = @{}
foreach ($f in $Man.files) { $noPack[$f.path] = $true }

# 1) apaga mod que saiu do pack (so os que ja foram do Vanilla++; mod que voce colocou fica)
$lixo = @($Man.remove)
foreach ($g in $Man.removeGlobs) {
    $dir = Split-Path (Full $g) -Parent; $pat = Split-Path $g -Leaf
    if (Test-Path $dir) { Get-ChildItem -LiteralPath $dir -Filter $pat | ForEach-Object { $lixo += ($g.Substring(0, $g.LastIndexOf('/') + 1) + $_.Name) } }
}
foreach ($rel in $lixo) {
    if ($noPack.ContainsKey($rel)) { continue }
    $p = Full $rel
    if (Test-Path -LiteralPath $p) {
        try { Remove-Item -LiteralPath $p -Force; $apagados++; Write-Host "  - apagado $rel" }
        catch { Write-Host "Nao consegui apagar $rel. Fecha o Minecraft e roda de novo." -ForegroundColor Red; exit 1 }
    }
    $State.Remove($rel)
}

# 2) baixa o que falta ou mudou
$i = 0; $n = @($Man.files).Count
foreach ($f in $Man.files) {
    $i++
    $p = Full $f.path
    if (Test-Path -LiteralPath ($p + '.disabled')) { continue }          # mod que voce desativou: fica desativado
    $existe = Test-Path -LiteralPath $p
    if ($existe -and (Sha1 $p) -eq $f.sha1) { $State[$f.path] = $f.sha1; continue }
    if ($f.config -and $existe -and -not $f.force) {
        # config: so troca se voce nao mexeu nela desde a ultima atualizacao
        if (-not $State.ContainsKey($f.path) -or ((Sha1 $p) -ne $State[$f.path])) { $mantidos += $f.path; continue }
    }
    Write-Host ("  [{0}/{1}] baixando {2}" -f $i, $n, $f.path)
    $dir = Split-Path $p -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $tmp = $p + '.baixando'
    $ok = $false
    for ($t = 0; $t -lt 3 -and -not $ok; $t++) {
        try { $Wc.DownloadFile($f.url, $tmp); $ok = ((Sha1 $tmp) -eq $f.sha1) } catch { $ok = $false }
    }
    if (-not $ok) {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        Write-Host "Falhou o download de $($f.path). Confere a internet e roda de novo." -ForegroundColor Red; exit 1
    }
    try { Move-Item -LiteralPath $tmp -Destination $p -Force }
    catch { Write-Host "Nao consegui trocar $($f.path). Fecha o Minecraft e roda de novo." -ForegroundColor Red; exit 1 }
    $State[$f.path] = $f.sha1; $baixados++
}
$State | ConvertTo-Json | Set-Content -LiteralPath $StateFile -Encoding UTF8
Write-Host ''
Write-Host "Pronto! $($Man.name) $($Man.version): $baixados baixado(s), $apagados apagado(s)." -ForegroundColor Green
if ($mantidos.Count) { Write-Host "Mantive $($mantidos.Count) config(s) que voce alterou." -ForegroundColor DarkGray }
