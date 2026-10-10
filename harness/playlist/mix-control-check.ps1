$ErrorActionPreference = 'Stop'

$source = Get-Content -Raw "$PSScriptRoot\..\..\tweak\Sources\Redesigned\Playlist\PlaylistMenu.x"
foreach ($contract in @(
    'BOOL isMix = row == _mix;',
    'if (isMix && page) pillsIn(curationIn(page), NULL, &pill);',
    'if (!pill.window || ![pill isDescendantOfView:page]) return;'
)) {
    if (!$source.Contains($contract)) { throw "Missing live Mix control contract: $contract" }
}

Write-Host 'playlist Mix live-control regression passed'
