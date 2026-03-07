# Git Setup Guide

Use this guide to create a stable source-control snapshot before future AI work.

## 1. Initialize Repository

```bash
git init
```

## 2. Stage Current Files

```bash
git add .
```

## 3. Create Stable Baseline Commit

```bash
git commit -m "Stable production-ready version without AI integration"
```

## 4. Tag the Stable Release

```bash
git tag v1.0-non-ai
```

## Why Tagging Matters

Tagging creates an immutable checkpoint of the non-AI production baseline.

Benefits:
- Safe rollback point if future AI work introduces regressions
- Clean release reference for QA/UAT signoff
- Clear audit marker for municipal production deployment
- Easier branching strategy (`v1.0-non-ai` -> `ai-integration` branch)

## Optional: Push to Remote

```bash
git remote add origin <your-repository-url>
git push -u origin main
git push origin v1.0-non-ai
```
