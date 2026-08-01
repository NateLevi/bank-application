#!/usr/bin/env bash
set -euo pipefail

DINERO_PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DINERO_BUILD_ROOT="${DINERO_PROJECT_ROOT}/build"
DINERO_PACKAGE_ROOT="${DINERO_BUILD_ROOT}/lambda-package"
DINERO_ARCHIVE="${DINERO_BUILD_ROOT}/dinero-lambda.zip"

rm -rf "$DINERO_PACKAGE_ROOT"
mkdir -p "$DINERO_PACKAGE_ROOT"
rm -f "$DINERO_ARCHIVE"

docker run --rm \
  --platform linux/amd64 \
  --entrypoint /bin/bash \
  --volume "${DINERO_PROJECT_ROOT}:/var/task" \
  public.ecr.aws/lambda/python:3.12 \
  -c "pip install --no-cache-dir -r /var/task/requirements.txt -t /var/task/build/lambda-package"

rm -rf \
  "$DINERO_PACKAGE_ROOT/models" \
  "$DINERO_PACKAGE_ROOT/repositories" \
  "$DINERO_PACKAGE_ROOT/services"
cp "$DINERO_PROJECT_ROOT/BankAPI.py" "$DINERO_PACKAGE_ROOT/BankAPI.py"
cp -R "$DINERO_PROJECT_ROOT/models" "$DINERO_PACKAGE_ROOT/models"
cp -R "$DINERO_PROJECT_ROOT/repositories" "$DINERO_PACKAGE_ROOT/repositories"
cp -R "$DINERO_PROJECT_ROOT/services" "$DINERO_PACKAGE_ROOT/services"

find "$DINERO_PACKAGE_ROOT" -type d -name __pycache__ -prune -exec rm -rf {} +
find "$DINERO_PACKAGE_ROOT" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

(
  cd "$DINERO_PACKAGE_ROOT"
  /usr/bin/zip -q -r "$DINERO_ARCHIVE" .
)

echo "Lambda ZIP created: $DINERO_ARCHIVE"
du -h "$DINERO_ARCHIVE"
