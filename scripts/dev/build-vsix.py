#!/usr/bin/env python3
"""Собирает themes/vscode/dist/northling-midnight-<версия>.vsix без vsce/npm (vsix — это zip).
Запуск: python3 scripts/dev/build-vsix.py"""
import json, os, zipfile, sys
from xml.sax.saxutils import escape

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "themes", "vscode")
src = os.path.join(root, "northling-midnight")
pkg = json.load(open(os.path.join(src, "package.json"), encoding="utf-8"))
out = os.path.join(root, "dist", f"{pkg['name']}-{pkg['version']}.vsix")
os.makedirs(os.path.dirname(out), exist_ok=True)

content_types = ('<?xml version="1.0" encoding="utf-8"?>'
  '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
  '<Default Extension=".json" ContentType="application/json"/>'
  '<Default Extension=".vsixmanifest" ContentType="text/xml"/>'
  '<Default Extension=".md" ContentType="text/markdown"/></Types>')
manifest = ('<?xml version="1.0" encoding="utf-8"?>'
  '<PackageManifest Version="2.0.0" xmlns="http://schemas.microsoft.com/developer/vsx-schema/2011" '
  'xmlns:d="http://schemas.microsoft.com/developer/vsx-schema-design/2011"><Metadata>'
  f'<Identity Language="en-US" Id="{pkg["name"]}" Version="{pkg["version"]}" Publisher="{pkg["publisher"]}"/>'
  f'<DisplayName>{escape(pkg["displayName"])}</DisplayName>'
  f'<Description xml:space="preserve">{escape(pkg["description"])}</Description>'
  '<Tags>theme,color-theme,dark</Tags><Categories>Themes</Categories>'
  '<Properties><Property Id="Microsoft.VisualStudio.Code.Engine" Value="%s"/></Properties>'
  '</Metadata><Installation><InstallationTarget Id="Microsoft.VisualStudio.Code"/></Installation>'
  '<Dependencies/><Assets><Asset Type="Microsoft.VisualStudio.Code.Manifest" Path="extension/package.json" Addressable="true"/>'
  '</Assets></PackageManifest>') % pkg["engines"]["vscode"]

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("[Content_Types].xml", content_types)
    z.writestr("extension.vsixmanifest", manifest)
    for d, _, files in os.walk(src):
        for f in sorted(files):
            full = os.path.join(d, f)
            z.write(full, "extension/" + os.path.relpath(full, src).replace(os.sep, "/"))
print("собрано:", os.path.relpath(out))
