# Script to check and create KeyCenter.h from template
# This should be added to Visual Studio Pre-Build Event

$ErrorActionPreference = "Stop"

# Determine project root (where the script is located)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$KeyCenterFile = Join-Path $ProjectRoot "VoiceAgent\src\KeyCenter.h"
$TemplateFile = Join-Path $ProjectRoot "KeyCenter.h.example"

Write-Host "🔍 Checking KeyCenter.h configuration..." -ForegroundColor Cyan

# Check if KeyCenter.h exists
if (-not (Test-Path $KeyCenterFile)) {
    Write-Host ""
    Write-Host "❌ ERROR: KeyCenter.h not found!" -ForegroundColor Red
    Write-Host ""
    
    # Check if template exists
    if (Test-Path $TemplateFile) {
        Write-Host "📝 Creating KeyCenter.h from template..." -ForegroundColor Yellow
        Copy-Item $TemplateFile $KeyCenterFile
        Write-Host ""
        Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║  ⚠️  BUILD FAILED: KeyCenter needs configuration     ║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Host "KeyCenter.h has been created from template at:" -ForegroundColor Yellow
        Write-Host "  $KeyCenterFile" -ForegroundColor White
        Write-Host ""
        Write-Host "Please update it with your actual Agora credentials:" -ForegroundColor Yellow
        Write-Host "  • AGORA_APP_ID" -ForegroundColor White
        Write-Host "  • REST_KEY" -ForegroundColor White
        Write-Host "  • REST_SECRET" -ForegroundColor White
        Write-Host "  • PIPELINE_ID" -ForegroundColor White
        Write-Host ""
        Write-Host "Get your credentials from: https://console.agora.io/" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Then rebuild the project." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    } else {
        Write-Host "❌ FATAL ERROR: Template file not found!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Expected template at: $TemplateFile" -ForegroundColor White
        Write-Host ""
        Write-Host "Please restore KeyCenter.h.example to project root" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }
}

# Validate that KeyCenter.h has been properly configured
$KeyCenterContent = Get-Content $KeyCenterFile -Raw

if ($KeyCenterContent -match "YOUR_APP_ID_HERE") {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║  ❌ BUILD FAILED: KeyCenter not configured           ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "KeyCenter.h still contains placeholder values!" -ForegroundColor Red
    Write-Host ""
    Write-Host "File location:" -ForegroundColor Yellow
    Write-Host "  $KeyCenterFile" -ForegroundColor White
    Write-Host ""
    Write-Host "Required actions:" -ForegroundColor Yellow
    Write-Host "  1. Open KeyCenter.h" -ForegroundColor White
    Write-Host "  2. Replace 'YOUR_APP_ID_HERE' with your actual Agora App ID" -ForegroundColor White
    Write-Host "  3. Replace 'YOUR_REST_KEY_HERE' with your REST Key" -ForegroundColor White
    Write-Host "  4. Replace 'YOUR_REST_SECRET_HERE' with your REST Secret" -ForegroundColor White
    Write-Host "  5. Replace 'YOUR_PIPELINE_ID_HERE' with your Pipeline ID" -ForegroundColor White
    Write-Host ""
    Write-Host "Get credentials from: https://console.agora.io/" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# Additional validation: check if essential fields are not empty (basic check)
if ($KeyCenterContent -match 'AGORA_APP_ID = ""') {
    Write-Host ""
    Write-Host "❌ BUILD FAILED: AGORA_APP_ID is empty in KeyCenter.h" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please configure your Agora App ID and rebuild." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "✅ KeyCenter.h validation passed" -ForegroundColor Green
Write-Host ""
exit 0

