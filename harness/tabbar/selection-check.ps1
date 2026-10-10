$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$navbar = Get-Content (Join-Path $root 'tweak/Sources/Redesigned/Navbar/Navbar.x') -Raw
$tabBar = Get-Content (Join-Path $root 'tweak/Sources/Redesigned/Navbar/TabBar.x') -Raw

function Require-Source([string]$pattern, [string]$description) {
    if ($navbar -notmatch $pattern) { throw "Missing $description" }
}

function Require-TabBar([string]$pattern, [string]$description) {
    if ($tabBar -notmatch $pattern) { throw "Missing $description" }
}

Require-Source 'if \(opened\) \{ SGRNavbarSelectItem\(self\); SGRRefreshTabBar\(\); \}' 'custom destination selection after a successful open'
Require-Source 'BOOL SGRNavbarCustomSelected\(UIView \*item\) \{ return item == sg_selectedCustom && sg_selectedCustom\.selected; \}' 'identity-based custom selection'
Require-Source '- \(void\)tapped \{ SGRNavbarSelectItem\(self\.view\); SGRRefreshTabBar\(\); \}' 'stock-tab selection reset'
Require-Source '- \(void\)pushViewController:\(UIViewController \*\)controller animated:\(BOOL\)animated \{\s*if \(sg_selectedCustom && !sg_openingCustom\) SGRNavbarSelectItem\(nil\);' 'selection reset for external pushes'
Require-Source '- \(UIViewController \*\)popViewControllerAnimated:\(BOOL\)animated \{\s*if \(sg_selectedCustom && !sg_openingCustom\) SGRNavbarSelectItem\(nil\);' 'selection reset for external pops'
Require-Source '- \(NSArray \*\)popToRootViewControllerAnimated:\(BOOL\)animated \{\s*if \(sg_selectedCustom && !sg_openingCustom\) SGRNavbarSelectItem\(nil\);' 'selection reset for root navigation'
Require-Source '- \(void\)setSelectedViewController:\(UIViewController \*\)controller \{\s*if \(sg_selectedCustom && !sg_openingCustom\) SGRNavbarSelectItem\(nil\);' 'selection reset for tab changes'
Require-TabBar 'if \(SGRNavbarCustomSelected\(sources\[i\]\)\) selected = item;' 'glass bar selection projection'

Write-Output 'redesigned navbar selection source contracts passed'
