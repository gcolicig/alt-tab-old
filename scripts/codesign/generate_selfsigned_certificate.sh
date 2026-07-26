#!/usr/bin/env bash

set -eu

certificateFile="$1"
certificatePassword="$2"
certificateName="${3:-Local Self-Signed}"

# certificate request (see https://apple.stackexchange.com/q/359997)
cat >"$certificateFile.conf" <<EOL
  [ req ]
  distinguished_name = req_name
  prompt = no
  [ req_name ]
  CN = $certificateName
  [ extensions ]
  basicConstraints=critical,CA:false
  keyUsage=critical,digitalSignature
  extendedKeyUsage=critical,1.3.6.1.5.5.7.3.3
  1.2.840.113635.100.6.1.14=critical,DER:0500
EOL

# generate key
openssl genrsa -out "$certificateFile.key" 2048
# generate self-signed certificate
openssl req -x509 -new -config "$certificateFile.conf" -nodes -key "$certificateFile.key" -extensions extensions -sha256 -days 3650 -out "$certificateFile.crt"

openssl_version=$(openssl version)
# openssl v3.x requires to pass -legacy
# see https://www.misterpki.com/openssl-pkcs12-legacy/
pkcs12Flags=()
if [[ $openssl_version == OpenSSL\ 3* ]]; then pkcs12Flags=(-legacy); fi
# wrap key and certificate into PKCS12
CERTIFICATE_PASSWORD="$certificatePassword" openssl pkcs12 "${pkcs12Flags[@]}" -export -inkey "$certificateFile.key" -in "$certificateFile.crt" -out "$certificateFile.p12" -passout env:CERTIFICATE_PASSWORD
