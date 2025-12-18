# GitHub Actions - CI/CD Setup Guide

## ✅ What's Been Set Up

Your project now has automated CI/CD pipelines that run on every push and pull request.

### **1. CI Workflow** (`.github/workflows/ci.yml`)
Runs automatically on every push and PR to `main` and `develop` branches.

**What it does:**
- ✅ **Tests**: Runs all unit and widget tests
- ✅ **Analysis**: Runs `flutter analyze` for code quality
- ✅ **Lint Check**: Verifies code formatting
- ✅ **Coverage**: Collects code coverage metrics
- ✅ **Debug Build**: Builds debug APK to ensure no compilation errors
- ✅ **iOS Build**: Attempts iOS build (dry run)

**Triggers:**
- Every push to `main` or `develop`
- Every pull request to `main` or `develop`

---

### **2. Release Workflow** (`.github/workflows/release.yml`)
Automatically builds release artifacts.

**What it does:**
- ✅ **Release APK**: Builds optimized release APK
- ✅ **Release AAB**: Builds App Bundle for Google Play Store
- ✅ **Windows Build**: Builds Windows desktop app
- ✅ **Artifacts**: Uploads builds as GitHub artifacts
- ✅ **Release Assets**: Attaches APK/AAB to GitHub releases

**Triggers:**
- Manual trigger via GitHub UI
- When `pubspec.yaml` is changed (commit trigger)
- On GitHub release creation

---

## 🚀 How to Use

### **Automatic Triggering**
1. **Make a commit and push:**
   ```bash
   git add .
   git commit -m "Your changes"
   git push origin main
   ```
   ✅ CI workflow runs automatically

2. **Create a Pull Request:**
   - CI checks will run automatically
   - PR shows ✅ pass/❌ fail status
   - Requires passing checks before merge

3. **Create a Release:**
   - Go to GitHub Repo → Releases → Draft New Release
   - Tag version: `v1.0.0`
   - Release workflow runs automatically
   - Download APK/AAB from release page

### **Manual Build Trigger**
1. Go to **Actions** tab on GitHub
2. Select **"CD - Build & Release"**
3. Click **"Run workflow"**
4. Artifacts available in 10-15 minutes

---

## 📊 Monitoring Workflows

### **View Workflow Status**
1. Go to your GitHub repo
2. Click **Actions** tab
3. See all workflow runs with status:
   - ✅ **Success** - All checks passed
   - ❌ **Failed** - See error details
   - ⏳ **In Progress** - Waiting to complete

### **View Build Logs**
Click on any workflow run to see:
- Step-by-step execution
- Error messages
- Build artifacts

---

## 📥 Download Build Artifacts

### **From CI Workflow**
After a successful CI run:
1. Open the workflow run
2. Scroll down to **Artifacts** section
3. Download `fuel-expense-tracker-release.apk`

### **From Release**
1. Go to **Releases** page
2. Find your release tag
3. Download APK from assets

---

## 🛠️ Customizing Workflows

### **Add Environment Variables**
Edit `.github/workflows/ci.yml`:
```yaml
env:
  FLUTTER_VERSION: '3.16.x'
  BUILD_NUMBER: ${{ github.run_number }}
```

### **Skip CI for Certain Commits**
Add to commit message:
```bash
git commit -m "Update docs [skip ci]"
```

### **Only Run on Tags**
Add trigger to release.yml:
```yaml
on:
  push:
    tags:
      - 'v*'
```

---

## 📋 Issue & PR Templates

Three templates have been created for better collaboration:

### **1. Bug Report** (`.github/ISSUE_TEMPLATE/bug_report.md`)
Use when reporting bugs:
- Steps to reproduce
- Expected vs actual behavior
- Screenshots/logs
- Environment info

### **2. Feature Request** (`.github/ISSUE_TEMPLATE/feature_request.md`)
Use for new features:
- Problem statement
- Proposed solution
- Alternatives considered

### **3. Pull Request Template** (`.github/pull_request_template.md`)
Auto-fills when creating PRs:
- Description of changes
- Type of change
- Testing done
- Checklist verification

---

## 🔐 Setting Up Secrets (Optional)

For advanced features, add secrets to GitHub:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**

### **Useful Secrets**

**For Google Play Store:**
```
GOOGLE_PLAY_KEY_JSON    # Service account JSON
KEYSTORE_PASSWORD       # Keystore password
KEY_PASSWORD            # Key password
```

**For Firebase:**
```
FIREBASE_PROJECT_ID
FIREBASE_KEY_JSON
```

**For Notifications:**
```
SLACK_WEBHOOK           # For Slack notifications
```

---

## ✨ What Happens in Each Workflow

### **CI Workflow Timeline (3-5 minutes)**
1. Setup Flutter SDK (30s)
2. Get dependencies (40s)
3. Analyze code (20s)
4. Run tests (40s)
5. Check formatting (10s)
6. Build debug APK (90s)
7. Upload coverage (20s)

### **Release Workflow Timeline (10-15 minutes)**
1. Setup Flutter SDK (30s)
2. Get dependencies (40s)
3. Build Release APK (120s)
4. Build App Bundle (60s)
5. Build Windows app (180s)
6. Upload artifacts (30s)

---

## 🎯 Best Practices

✅ **Do:**
- Keep commits atomic and focused
- Write descriptive commit messages
- Use meaningful PR titles
- Review CI logs if builds fail
- Tag releases with semantic versioning (v1.0.0)

❌ **Don't:**
- Skip CI checks
- Push broken code to main
- Ignore test failures
- Use release APKs without proper signing (for production)

---

## 🆘 Troubleshooting

### **CI Fails on Tests**
1. Run locally: `flutter test`
2. Fix issues
3. Commit and push again

### **Build Takes Too Long**
- Normal for first run (20+ minutes)
- Cached dependencies = faster (5-10 minutes)
- Check if network is slow

### **APK Build Fails**
Check logs for:
- Missing dependencies
- Gradle errors
- Java/Kotlin compilation issues

### **Artifacts Not Downloaded**
1. Workflow must be ✅ successful
2. Scroll down in workflow run page
3. Look for "Artifacts" section

---

## 📚 Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter CI/CD Guide](https://flutter.dev/docs/deployment/cd)
- [semantic versioning](https://semver.org/)
- [Flutter Build Documentation](https://flutter.dev/docs/deployment)

---

## 🎉 You're All Set!

Your project now has:
- ✅ Automated testing on every push
- ✅ Automated builds on releases
- ✅ Professional issue templates
- ✅ Code quality automation
- ✅ Artifact management

Start using it by making your next commit!

```bash
git add .
git commit -m "Great feature"
git push origin main
# Watch your CI run on GitHub Actions! 🚀
```
