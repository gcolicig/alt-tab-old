#!/usr/bin/env bash

set -eu

certificateName="${LOCAL_CODE_SIGN_IDENTITY:-AltTab+ Local Codesign}"
if security find-identity -v -p codesigning 2>/dev/null | grep -Fq "\"$certificateName\""; then
  echo "Code signing identity already configured: $certificateName"
  exit 0
fi
certificateFile="$(mktemp "${TMPDIR:-/tmp}/alttab-plus-codesign.XXXXXX")"
certificatePassword="$(openssl rand -base64 12)"

cleanup() {
  rm -f "$certificateFile" "$certificateFile.conf" "$certificateFile.key" "$certificateFile.crt" "$certificateFile.p12"
}
trap cleanup EXIT

scripts/codesign/generate_selfsigned_certificate.sh "$certificateFile" "$certificatePassword" "$certificateName"
scripts/codesign/import_certificate_into_main_keychain.sh "$certificateFile" "$certificatePassword"
echo "Configured code signing identity: $certificateName"
