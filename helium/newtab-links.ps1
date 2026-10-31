<#
Lists changes to make to the new tab page's links, in links.js in ~\.config\helium-newtab, from
Helium's history: the counterpart of newtab-links.sh. Sites opened on 4 or more days of the last 30
that no link goes to, and links not opened in the last 90 days. A link goes to a site with the same
host, www. aside, and it's opened when a page at or under its address is. A day counts only with a
visit Helium would count toward its own most visited tiles. It writes nothing;
powershell\steps\83-helium.ps1 runs it in the monthly update.

Sites in ignore, next to links.js, are never suggested, nor their subdomains: one a line, such as
example.com, and # starts a comment. Helium locks its history while it runs, so this reads a copy,
with scoop's sqlite3.

scoop's Helium keeps its profile in ~\scoop\persist\helium\User Data; -UserData points the script at
a copy.
#>
param([string]$UserData = "$HOME\scoop\persist\helium\User Data")
$ErrorActionPreference = 'Stop'

$oftenDays = 4
$recentDays = 30
$staleDays = 90

$dir = "$HOME\.config\helium-newtab"
$linksFile = "$dir\links.js"
$ignoreFile = "$dir\ignore"
$historyDb = "$UserData\Default\History"
function Show($path) { $path.Replace($HOME, '~') }

if (-not (Test-Path $linksFile)) {
    "there's no $(Show $linksFile), so the page has no links: newtab.html's header has the format"
    return
}
if (-not (Test-Path $historyDb)) { throw "no Helium history at $(Show $historyDb)" }
if (-not (Get-Command sqlite3 -ErrorAction SilentlyContinue)) {
    throw "no sqlite3 to read Helium's history with: scoop install sqlite (MIGRATION.windows.md section 6)"
}

# Chromium's visit times are microseconds since 1601
function Since($days) { "(strftime('%s', 'now') - $($days * 86400) + 11644473600) * 1000000" }
function Query($sql) {
    $out = $sql | sqlite3 -batch -noheader -separator ' ' "$tmp\History"
    if ($LASTEXITCODE) { throw "sqlite3 couldn't read the copy of Helium's history" }
    $out
}
# https://www.example.com/path?query -> example.com/path
function Address([string]$url) {
    $i = $url.IndexOf('://')
    $site, $path = ($i -ge 0 ? $url.Substring($i + 3) : $url) -split '/', 2
    "$($site.ToLower() -replace '^www\.')/$($path -replace '[?#].*')"
}

$tmp = New-Item -ItemType Directory ([IO.Path]::Combine([IO.Path]::GetTempPath(), "newtab-links-$(New-Guid)"))
try {
    Get-Item $historyDb, "$historyDb-journal" -ErrorAction SilentlyContinue | Copy-Item -Destination $tmp

    # Each link's name and address, from lines such as ['GitHub', 'https://github.com']. Not a
    # property named Address: an array has a method of that name, which $links.Address would call
    $links = @([regex]::Matches((Get-Content -Raw $linksFile), '\[\s*["'']([^"'']*)["'']\s*,\s*["''](https?://[^"'']*)["'']') |
        ForEach-Object { [pscustomobject]@{ Name = $_.Groups[1].Value; Prefix = Address $_.Groups[2].Value } })
    $linkSites = $links.Prefix | ForEach-Object { ($_ -split '/', 2)[0] }

    $ignored = @(if (Test-Path $ignoreFile) {
        Get-Content $ignoreFile | ForEach-Object { ($_ -replace '#.*' -replace '\s').ToLower() } | Where-Object { $_ }
    })

    # Sites opened on enough days, most days first
    $missing = Query @"
with visit as (
  select substr(u.url, instr(u.url, '://') + 3) as rest, v.visit_time / 86400000000 as day
  from visits v join urls u on u.id = v.url
  where v.consider_for_ntp_most_visited and v.visit_time > $(Since $recentDays)
    and (u.url like 'http://%' or u.url like 'https://%'))
select lower(case instr(rest, '/') when 0 then rest else substr(rest, 1, instr(rest, '/') - 1) end) as host,
  count(distinct day) as days
from visit group by host having days >= $oftenDays order by days desc, host
"@ | ForEach-Object {
        $site, $days = $_ -split ' '
        if (($site -replace '^www\.') -in $linkSites) { return }
        foreach ($i in $ignored) { if ($site -eq $i -or $site.EndsWith(".$i")) { return } }
        "$site ($days days)"
    }
    if ($missing) {
        "no link to $($missing -join ', '), opened often in the last $recentDays days: add one to $(Show $linksFile), or the site to $(Show $ignoreFile)"
    }

    # Links with no page at or under their address opened since
    $opened = @(Query "select url from urls where last_visit_time > $(Since $staleDays)" | ForEach-Object { Address $_ })
    $stale = $links | Where-Object { $prefix = $_.Prefix; -not $opened.Where({ $_.StartsWith($prefix, 'Ordinal') }, 'First') }
    if ($stale) {
        "$($stale.Name -join ', ') not opened in the last $staleDays days: drop from $(Show $linksFile) what you no longer need"
    }
} finally {
    Remove-Item -Recurse -Force $tmp
}
