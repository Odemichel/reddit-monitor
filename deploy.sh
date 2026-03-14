#!/bin/bash
set -e

echo "==> Building Flutter web..."
flutter build web --release

echo "==> Copying build to public/..."
rm -rf public
cp -r build/web public

echo "==> Done. Ready to deploy."
echo ""
echo "Run: vercel --prod"
