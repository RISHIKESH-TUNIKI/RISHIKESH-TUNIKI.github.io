# Resume PDF builder: prints resume.html to an A4 PDF with headless Microsoft Edge.
#
#   .\build-resume.ps1                      -> Tuniki-Rishikesh-Resume.pdf  (public: no phone number; linked from the site)
#   .\build-resume.ps1 -Phone "+91 ..."     -> private\Tuniki-Rishikesh-Resume.pdf  (with phone; folder is git-ignored)
#
# The phone number is only ever passed in here, never saved in resume.html or the repo.
param([string]$Phone)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
          "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw 'Microsoft Edge was not found.' }

$html = [IO.File]::ReadAllText("$here\resume.html", [Text.Encoding]::UTF8)
if ($Phone) {
    $safe = [Net.WebUtility]::HtmlEncode($Phone)
    $html = $html.Replace('<!--PHONE-->', "<span>$safe</span>")
    $outDir = Join-Path $here 'private'
} else {
    $outDir = $here
}
New-Item -ItemType Directory -Force $outDir | Out-Null
$out = Join-Path $outDir 'Tuniki-Rishikesh-Resume.pdf'

# Print from a temp copy next to resume.html, so fonts/ resolves the same way.
$tmp = Join-Path $here '.build-tmp.html'
[IO.File]::WriteAllText($tmp, $html, (New-Object Text.UTF8Encoding $false))
$profile = Join-Path $env:TEMP "resume-edge-$PID"
try {
    if (Test-Path $out) { Remove-Item $out -Force }
    # Edge reports progress on stderr, so run it as a separate process and let that output go to a log.
    $log = Join-Path $profile.TrimEnd('\') '..\resume-edge.log'
    $args = @('--headless=new', '--disable-gpu', '--no-pdf-header-footer', "--user-data-dir=`"$profile`"",
              '--virtual-time-budget=5000', "`"--print-to-pdf=$out`"", ([Uri]$tmp).AbsoluteUri)
    Start-Process -FilePath $edge -ArgumentList $args -Wait -WindowStyle Hidden -RedirectStandardError $log
    Remove-Item $log -Force -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 40 -and -not (Test-Path $out); $i++) { Start-Sleep -Milliseconds 250 }
    if (-not (Test-Path $out)) { throw 'Edge did not produce the PDF.' }
    $pages = ([regex]::Matches([IO.File]::ReadAllText($out, [Text.Encoding]::GetEncoding(28591)), '/Type\s*/Page[^s]')).Count
    "Built $out ($([math]::Round((Get-Item $out).Length / 1KB)) KB, $pages page(s))"
    if ($pages -ne 1) { Write-Warning 'The resume is meant to fit on one page; shorten something in resume.html.' }
} finally {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Remove-Item $profile -Recurse -Force -ErrorAction SilentlyContinue
}
