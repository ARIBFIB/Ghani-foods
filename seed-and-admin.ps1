# ============================================================================
# GhaniFoods - Seed Data + Admin User Script
# Run from: D:\Rozmarrah-CUST\Saim Ashraf\Nimko\Working\Code\GhaniFoods>
#   PS D:\...\GhaniFoods> .\seed-and-admin.ps1
# Requires apps\backend already created by setup-ghanifoods-backend.ps1
# ============================================================================

$ErrorActionPreference = "Stop"
$Root       = Get-Location
$Backend    = Join-Path $Root "apps\backend"
$Migrations = Join-Path $Backend "supabase\migrations"
$EnvFile    = Join-Path $Backend ".env"

if (-not (Test-Path $EnvFile)) {
    Write-Host "apps\backend\.env not found. Run setup-ghanifoods-backend.ps1 first." -ForegroundColor Red
    exit 1
}

$SupaUrl = $null; $SecretKey = $null; $DbPassword = $null; $ProjectRef = $null
Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^SUPABASE_URL=(.*)$')          { $SupaUrl    = $Matches[1] }
    if ($_ -match '^SUPABASE_SECRET_KEY=(.*)$')   { $SecretKey  = $Matches[1] }
    if ($_ -match '^SUPABASE_DB_PASSWORD=(.*)$')  { $DbPassword = $Matches[1] }
    if ($_ -match '^SUPABASE_PROJECT_REF=(.*)$')  { $ProjectRef = $Matches[1] }
}

# ============================================================================
# 0003_seed_data.sql - demo master data (safe/idempotent via NOT EXISTS checks)
# ============================================================================
$Seed = @'
-- app_settings
update app_settings set business_name = 'GhaniFoods', address = 'Islamabad, Pakistan',
  invoice_footer_text = 'Thank you for your business!', default_profit_margin_percent = 20,
  low_stock_threshold_default = 50 where id = 1;

-- suppliers
insert into suppliers (name, phone, address)
select 'Al-Madina Traders', '0300-1234567', 'Rawalpindi'
where not exists (select 1 from suppliers where name = 'Al-Madina Traders');

insert into suppliers (name, phone, address)
select 'Ghani Oil Suppliers', '0333-7654321', 'Islamabad'
where not exists (select 1 from suppliers where name = 'Ghani Oil Suppliers');

-- raw materials
insert into raw_materials (name, unit, low_stock_threshold)
select 'Besan (Gram Flour)', 'kg', 50
where not exists (select 1 from raw_materials where name = 'Besan (Gram Flour)');

insert into raw_materials (name, unit, low_stock_threshold)
select 'Cooking Oil', 'kg', 30
where not exists (select 1 from raw_materials where name = 'Cooking Oil');

insert into raw_materials (name, unit, low_stock_threshold)
select 'Wrapper Film Roll', 'kg', 10
where not exists (select 1 from raw_materials where name = 'Wrapper Film Roll');

insert into raw_materials (name, unit, low_stock_threshold)
select 'Carton Board', 'kg', 10
where not exists (select 1 from raw_materials where name = 'Carton Board');

-- seed a small purchase so stock/avg cost is non-zero (idempotent via receipt count check)
do $$
declare v_supplier uuid; v_besan uuid; v_oil uuid;
begin
  if (select count(*) from purchase_receipts) = 0 then
    select id into v_supplier from suppliers where name = 'Al-Madina Traders';
    select id into v_besan from raw_materials where name = 'Besan (Gram Flour)';
    select id into v_oil from raw_materials where name = 'Cooking Oil';

    perform fn_create_purchase_receipt(
      v_supplier, current_date,
      jsonb_build_array(
        jsonb_build_object('rawMaterialId', v_besan, 'qty', 100, 'cost', 180),
        jsonb_build_object('rawMaterialId', v_oil,   'qty', 50,  'cost', 550)
      )
    );
  end if;
end $$;

-- wrappers / boxes definitions (linked to packaging raw materials)
do $$
declare v_wrap_rm uuid; v_box_rm uuid;
begin
  select id into v_wrap_rm from raw_materials where name = 'Wrapper Film Roll';
  select id into v_box_rm from raw_materials where name = 'Carton Board';

  insert into wrappers (name, raw_material_id, grams_per_unit, low_stock_threshold)
  select 'Standard Packet Wrapper', v_wrap_rm, 2, 200
  where not exists (select 1 from wrappers where name = 'Standard Packet Wrapper');

  insert into boxes (name, raw_material_id, grams_per_unit, low_stock_threshold)
  select 'Standard Box', v_box_rm, 50, 20
  where not exists (select 1 from boxes where name = 'Standard Box');
end $$;

-- a demo customer
insert into customers (name, phone)
select 'Walk-in Customer', '0300-0000000'
where not exists (select 1 from customers where name = 'Walk-in Customer');
'@
New-Item -ItemType Directory -Force -Path $Migrations | Out-Null
Set-Content -Path (Join-Path $Migrations "0003_seed_data.sql") -Value $Seed -Encoding UTF8
Write-Host "==> Seed migration written." -ForegroundColor Green

Set-Location $Backend
Write-Host "==> supabase db push (applying seed migration)..." -ForegroundColor Cyan
if ([string]::IsNullOrWhiteSpace($DbPassword)) {
    npx --yes supabase db push
} else {
    npx --yes supabase db push --password "$DbPassword"
}
Set-Location $Root

# ----------------------------------------------------------------------------
# Admin user creation via Supabase Auth Admin API (needs service_role key)
# ----------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($SecretKey)) {
    Write-Host ""
    Write-Host "==> No SUPABASE_SECRET_KEY in .env, skipping admin user creation." -ForegroundColor Yellow
    Write-Host "==> Add SUPABASE_SECRET_KEY to apps\backend\.env and re-run this script to create the admin user." -ForegroundColor Yellow
} else {
    Write-Host ""
    $AdminEmail = Read-Host "Enter admin email"
    $AdminPassSecure = Read-Host "Enter admin password (min 6 chars)" -AsSecureString
    $AdminPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassSecure))

    $Body = @{ email = $AdminEmail; password = $AdminPass; email_confirm = $true } | ConvertTo-Json
    $Headers = @{ "apikey" = $SecretKey; "Authorization" = "Bearer $SecretKey"; "Content-Type" = "application/json" }

    Write-Host "==> Creating admin user via Supabase Auth Admin API..." -ForegroundColor Cyan
    try {
        $Response = Invoke-RestMethod -Method Post -Uri "$SupaUrl/auth/v1/admin/users" -Headers $Headers -Body $Body -UserAgent "GhaniFoods-Setup-Script/1.0"
        Write-Host "==> Admin user created: $($Response.email) (id: $($Response.id))" -ForegroundColor Green
    } catch {
        Write-Host "==> Admin user creation failed:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message -ForegroundColor Red }
        Write-Host "==> (If user already exists, this error is expected/safe to ignore.)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "==> DONE. Seed data applied + admin user step complete." -ForegroundColor Green