# Script to check and create KeyCenter.h from template
# This generates compiler errors that appear in Visual Studio Error List

$ErrorActionPreference = "Stop"

# Determine project root (where the script is located)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

$KeyCenterFile = Join-Path $ProjectRoot "VoiceAgent\src\KeyCenter.h"
$TemplateFile = Join-Path $ProjectRoot "KeyCenter.h.example"

Write-Host "🔍 Checking KeyCenter.h configuration..." -ForegroundColor Cyan

# Function to create error header file
function Create-ErrorHeader {
    param([string]$ErrorMessage, [string]$Instructions)
    
    $ErrorHeader = @"
#pragma once

// ============================================================================
// ⚠️  BUILD ERROR: KeyCenter Configuration Required
// ============================================================================
//
// $ErrorMessage
//
// Required Steps:
$Instructions
//
// Get your credentials from: https://console.agora.io/
//
// ============================================================================

#error "⚠️  BUILD FAILED: $ErrorMessage - Please configure KeyCenter.h with your Agora credentials. See instructions above."

"@
    
    Set-Content -Path $KeyCenterFile -Value $ErrorHeader -Encoding UTF8
}

# Check if KeyCenter.h exists
if (-not (Test-Path $KeyCenterFile)) {
    Write-Host ""
    Write-Host "❌ KeyCenter.h not found! Creating error header..." -ForegroundColor Yellow
    Write-Host ""
    
    # Check if template exists
    if (Test-Path $TemplateFile) {
        $Instructions = @"
//   1. Copy '$TemplateFile' to:
//      '$KeyCenterFile'
//   2. Open the copied file and replace the following placeholders:
//      - YOUR_APP_ID_HERE → Your Agora App ID
//      - YOUR_REST_KEY_HERE → Your REST API Key
//      - YOUR_REST_SECRET_HERE → Your REST API Secret
//      - YOUR_PIPELINE_ID_HERE → Your Pipeline ID
//   3. Save the file and rebuild the project
"@
        
        Create-ErrorHeader -ErrorMessage "KeyCenter.h is missing" -Instructions $Instructions
        
        Write-Host "A placeholder KeyCenter.h has been created." -ForegroundColor Yellow
        Write-Host "The next build will show detailed instructions in the error list." -ForegroundColor Yellow
        Write-Host ""
    } else {
        $Instructions = @"
//   1. Restore 'KeyCenter.h.example' file to project root
//   2. Copy it to: '$KeyCenterFile'
//   3. Configure your Agora credentials
//   4. Rebuild the project
"@
        
        Create-ErrorHeader -ErrorMessage "KeyCenter.h.example template not found" -Instructions $Instructions
    }
    
    # Exit with success so the error shows up during compilation
    exit 0
}

# Validate that KeyCenter.h has been properly configured
$KeyCenterContent = Get-Content $KeyCenterFile -Raw

if ($KeyCenterContent -match "#error") {
    # Error header exists from previous run, let compilation show the error
    Write-Host "⚠️  KeyCenter.h contains configuration errors" -ForegroundColor Yellow
    Write-Host "Please check the Error List window after build" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

if ($KeyCenterContent -match "YOUR_APP_ID_HERE") {
    Write-Host ""
    Write-Host "❌ KeyCenter.h contains placeholder values! Creating error header..." -ForegroundColor Yellow
    Write-Host ""
    
    $Instructions = @"
//   1. Open: '$KeyCenterFile'
//   2. Replace all placeholder values:
//      - YOUR_APP_ID_HERE → Your Agora App ID (from console.agora.io)
//      - YOUR_REST_KEY_HERE → Your REST API Key
//      - YOUR_REST_SECRET_HERE → Your REST API Secret  
//      - YOUR_PIPELINE_ID_HERE → Your Pipeline ID
//   3. Save the file and rebuild
"@
    
    Create-ErrorHeader -ErrorMessage "KeyCenter.h is not configured (still contains placeholders)" -Instructions $Instructions
    
    Write-Host "A build error will appear with detailed instructions." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# Additional validation: check if essential fields are not empty
if ($KeyCenterContent -match 'AGORA_APP_ID = ""') {
    Write-Host ""
    Write-Host "❌ AGORA_APP_ID is empty! Creating error header..." -ForegroundColor Yellow
    Write-Host ""
    
    $Instructions = @"
//   1. Open: '$KeyCenterFile'
//   2. Set AGORA_APP_ID to your actual App ID (not an empty string)
//   3. Get your App ID from: https://console.agora.io/
//   4. Save and rebuild
"@
    
    Create-ErrorHeader -ErrorMessage "AGORA_APP_ID is empty in KeyCenter.h" -Instructions $Instructions
    exit 0
}

Write-Host "✅ KeyCenter.h validation passed" -ForegroundColor Green
Write-Host ""
exit 0

