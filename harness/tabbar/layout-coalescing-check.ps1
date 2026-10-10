$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path

function Require-Source([string]$path, [string]$pattern, [string]$description) {
    $source = Get-Content (Join-Path $root $path) -Raw
    if ($source -notmatch $pattern) { throw "Missing $description in $path" }
}

Require-Source 'tweak/Sources/Native/Navbar/TabBarHooks.x' 'static void updateTabBar\(UIView \*bar\) \{\s*SGComposeTabBar\(bar\);\s*holdHome\(bar\);\s*SGLogTabBarRow\(bar\);\s*\}' 'native complete update'
Require-Source 'tweak/Sources/Native/Navbar/TabBarHooks.x' 'if \(!bar \|\| \[objc_getAssociatedObject\(bar, &kPendingUpdateKey\) boolValue\]\) return;' 'native per-turn coalescing'
Require-Source 'tweak/Sources/Native/Navbar/TabBarHooks.x' 'requestTabBarUpdate\(\(UIView \*\)self\);' 'native bar-layout scheduling'
Require-Source 'tweak/Sources/Native/Navbar/TabBarHooks.x' 'requestTabBarUpdate\(bar\);' 'native item-layout scheduling'
Require-Source 'tweak/Sources/Redesigned/Navbar/TabBar.x' 'static void updateTabBar\(UIView \*bar\) \{\s*SGRComposeTabBar\(bar\);\s*holdHome\(bar\);\s*syncBar\(bar\);\s*SGRLogTabBarRow\(bar\);\s*\}' 'redesigned complete update'
Require-Source 'tweak/Sources/Redesigned/Navbar/TabBar.x' 'if \(!bar \|\| \[objc_getAssociatedObject\(bar, &kPendingUpdateKey\) boolValue\]\) return;' 'redesigned per-turn coalescing'
Require-Source 'tweak/Sources/Redesigned/Navbar/TabBar.x' 'requestTabBarUpdate\(\(UIView \*\)self\);' 'redesigned bar-layout scheduling'
Require-Source 'tweak/Sources/Redesigned/Navbar/TabBar.x' 'requestTabBarUpdate\(bar\);' 'redesigned item-layout scheduling'

Write-Output 'navbar layout coalescing source contracts passed'
