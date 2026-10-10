$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$editor = Get-Content (Join-Path $root 'tweak/Sources/Redesigned/Navbar/TabEditor.inc') -Raw
$settings = Get-Content (Join-Path $root 'tweak/Sources/Redesigned/Navbar/NavbarSettings.m') -Raw

function Require-Source([string]$source, [string]$pattern, [string]$description) {
    if ($source -notmatch $pattern) { throw "Missing $description" }
}

Require-Source $editor '@interface SGRTabEditor : SGPage <UISearchResultsUpdating>' 'searchable redesigned editor'
Require-Source $editor 'updateSearchResultsForSearchController:' 'icon search update'
Require-Source $editor 'rangeOfString:query options:NSCaseInsensitiveSearch' 'case-insensitive icon filtering'
Require-Source $editor 'UIImage systemImageNamed:name' 'available SF Symbol filtering'
Require-Source $editor 'SGSpotifyURIFromText\(_link\.text\)' 'Spotify link normalization'
Require-Source $editor 'SGSpotifyURIRoute\(url, &via\) == SGLinkRouteNone' 'unopenable-link rejection'
Require-Source $editor 'SGRNavbarTitle:title\.length \? title : url\.absoluteString, SGRNavbarURI:url\.absoluteString, SGRNavbarIcon:_icon' 'persisted title, URI, and icon'
Require-Source $settings 'entry\[SGRNavbarID\] = NSUUID\.UUID\.UUIDString' 'unique redesigned tab identity'
Require-Source $settings 'SGRSetNavbarLayout\(\[navbarEntries\(\) arrayByAddingObject:entry\]\)' 'redesigned-only tab persistence'

Write-Output 'redesigned tab editor source contracts passed'
