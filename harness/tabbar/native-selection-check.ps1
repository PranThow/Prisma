$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$navbar = Get-Content (Join-Path $root 'tweak/Sources/Native/Navbar/Navbar.x') -Raw

function Require-Source([string]$pattern, [string]$description) {
    if ($navbar -notmatch $pattern) { throw "Missing $description" }
}

Require-Source 'if \(opened\) \{ SGNavbarSelectItem\(self\); SGRefreshTabBar\(\); \}' 'custom destination selection after a successful open'
Require-Source 'BOOL SGNavbarCustomSelected\(UIView \*item\) \{ return item == sg_selectedCustom && sg_selectedCustom\.selected; \}' 'identity-based custom selection'
Require-Source '- \(void\)tapped \{ SGNavbarSelectItem\(self\.view\); SGRefreshTabBar\(\); \}' 'stock-tab selection reset'
Require-Source '- \(void\)pushViewController:\(UIViewController \*\)controller animated:\(BOOL\)animated \{\s*if \(sg_selectedCustom && !sg_openingCustom\) SGNavbarSelectItem\(nil\);' 'selection reset for external pushes'
Require-Source '- \(UIViewController \*\)popViewControllerAnimated:\(BOOL\)animated \{\s*if \(sg_selectedCustom && !sg_openingCustom\) SGNavbarSelectItem\(nil\);' 'selection reset for external pops'
Require-Source '- \(NSArray \*\)popToRootViewControllerAnimated:\(BOOL\)animated \{\s*if \(sg_selectedCustom && !sg_openingCustom\) SGNavbarSelectItem\(nil\);' 'selection reset for root navigation'
Require-Source '- \(void\)setSelectedViewController:\(UIViewController \*\)controller \{\s*if \(sg_selectedCustom && !sg_openingCustom\) SGNavbarSelectItem\(nil\);' 'selection reset for tab changes'
Require-Source 'if \(\[keep containsObject:ident\]\) continue;\s*\[custom\[ident\] removeFromSuperview\];\s*\[custom removeObjectForKey:ident\];' 'removed custom-item cleanup'
Require-Source 'SGTabItemView \*item = custom\[ident\];\s*if \(item\) \[item applyEntry:entry\];\s*else custom\[ident\] = item = \[\[SGTabItemView alloc\] initWithEntry:entry\];' 'stable custom-item identity across reordering'

Write-Output 'native navbar selection source contracts passed'
