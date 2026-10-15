# Run from repo root: .\secure-gitignore.ps1   (optional: -Push)
param([switch]$Push)
$ErrorActionPreference = "Stop"
if (-not (Test-Path ".git")) { throw "Repo root se run karo (.git nahi mila)." }

$entries = @(
  "# --- security: secrets / temp ---",
  ".diag-tmp/",
  "*.bak",
  ".env",
  ".env.*",
  "!.env.example",
  "apps/backend/supabase/.temp/",
  "supabase/.temp/",
  "edits.json",
  "code-export.json"
)

if (-not (Test-Path ".gitignore")) { New-Item ".gitignore" -ItemType File | Out-Null }
$existing = Get-Content ".gitignore" -ErrorAction SilentlyContinue
foreach ($e in $entries) {
  if ($existing -notcontains $e) { Add-Content ".gitignore" $e }
}
Write-Host ".gitignore updated." -ForegroundColor Green

# Hardcoded DB password hata do deploy script ke comment se
$deploy = "deploy-supabase-function.ps1"
if (Test-Path $deploy) {
  $txt = Get-Content $deploy -Raw
  $txt = $txt -replace 'S0ep2CxuMkk0FgEH', '<YOUR_DB_PASSWORD>'
  [System.IO.File]::WriteAllText((Join-Path $PWD $deploy), $txt, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "Password deploy script se hata diya." -ForegroundColor Green
}

# Jo files already git mein tracked hain unko index se nikalo (disk par rahengi)
foreach ($p in @(".diag-tmp", "apps/backend/supabase/.temp", "supabase/.temp", "edits.json", "code-export.json")) {
  git rm -r --cached --ignore-unmatch -q $p
}
Get-ChildItem -Recurse -Filter *.bak -File | ForEach-Object { git rm --cached --ignore-unmatch -q $_.FullName }

git add .gitignore $deploy
git status --short

if ($Push) {
  git commit -m "chore: gitignore secrets/temp files, remove hardcoded password"
  git push
}
Write-Host "`nIMPORTANT: password purani git history mein reh sakta hai -> Supabase Dashboard > Database > Reset database password zaroor karo." -ForegroundColor Yellow