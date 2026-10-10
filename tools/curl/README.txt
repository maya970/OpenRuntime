Bundled curl for OpenRuntime
============================

This folder contains an official curl-for-win build (x64) linked with LibreSSL.

Why it is here
--------------
Many Windows 7 machines cannot download from Microsoft HTTPS because Schannel
has no TLS 1.2. curl+LibreSSL provides TLS 1.2 without relying on Windows updates.

Supported OS for this binary: Windows Vista / 7 / 8 / 10 / 11 (x64).

Files
-----
curl.exe
libcurl-x64.dll
curl-ca-bundle.crt
COPYING-curl.txt
COPYING-libressl.txt

Source: https://curl.se/windows/
