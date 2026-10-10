$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$editor = Get-Content (Join-Path $root 'tweak/Sources/Native/Navbar/TabEditor.inc') -Raw
$settings = Get-Content (Join-Path $root 'tweak/Sources/Native/Navbar/NavbarSettings.m') -Raw
$navbar = Get-Content (Join-Path $root 'tweak/Sources/Native/Navbar/Navbar.x') -Raw

function Require-Source([string]$source, [string]$pattern, [string]$description) {
    if ($source -notmatch $pattern) { throw "Missing $description" }
}

Require-Source $editor '@interface SGTabEditor : SGPage <UISearchResultsUpdating>' 'searchable Native editor'
Require-Source $editor 'updateSearchResultsForSearchController:' 'icon search update'
Require-Source $editor 'rangeOfString:query options:NSCaseInsensitiveSearch' 'case-insensitive icon filtering'
Require-Source $editor 'UIImage systemImageNamed:name' 'available SF Symbol filtering'
Require-Source $editor 'SGSpotifyURIFromText\(_link\.text\)' 'Spotify link normalization'
Require-Source $editor 'SGSpotifyURIRoute\(url, &via\) == SGLinkRouteNone' 'unopenable-link rejection'
Require-Source $editor 'SGNavbarTitle:title\.length \? title : url\.absoluteString, SGNavbarURI:url\.absoluteString, SGNavbarIcon:_icon' 'persisted title, URI, and icon'
Require-Source $settings 'editor\.initialEntry = path\.section == 0 \? tabPresets\(\)\[\(NSUInteger\)path\.row\] : nil;' 'selected Native preset passed to the editor'
Require-Source $settings 'entry\[SGNavbarID\] = NSUUID\.UUID\.UUIDString' 'unique Native tab identity'
Require-Source $settings 'SGSetNavbarLayout\(\[navbarEntries\(\) arrayByAddingObject:entry\]\)' 'Native-only tab persistence'
Require-Source $navbar 'NSString \*symbol = \[name hasPrefix:@"sf:"\] \? \[name substringFromIndex:3\] : name;' 'SF Symbol rendering'

Write-Output 'native tab editor source contracts passed'
