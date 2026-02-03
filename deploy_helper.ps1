# Firebase Deployment Helper Script

Write-Host "Starting WadiniSafe Firebase Deployment..." -ForegroundColor Cyan

# 1. Check Login Status
Write-Host "1. Checking Firebase Login Status..." -ForegroundColor Yellow
$loginCheck = firebase projects:list 2>&1
if ($loginCheck -match "Error") {
    Write-Host "Not logged in. Initiating login..." -ForegroundColor Red
    firebase login
} else {
    Write-Host "Already logged in." -ForegroundColor Green
}

# 2. Select Project
$projectId = "wadinisafe-5475f"
Write-Host "2. Selecting Project: $projectId" -ForegroundColor Yellow
firebase use $projectId

# 3. Deploy Firestore Rules and Indexes
Write-Host "3. Deploying Firestore Rules and Indexes..." -ForegroundColor Yellow
firebase deploy --only firestore

Write-Host "Deployment Complete!" -ForegroundColor Cyan
Write-Host "Don't forget to update your google-services.json and GoogleService-Info.plist files!" -ForegroundColor Magenta
