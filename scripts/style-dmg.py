"""Write Finder layout directly on the mounted HFS+ image, without UI scripting."""
import sys
from pathlib import Path
from ds_store import DSStore
from mac_alias import Alias

mount = Path(sys.argv[1])
background = Alias.for_file(str(mount / '.background/background.png')).to_bytes()
with DSStore.open(str(mount / '.DS_Store'), 'w+') as store:
    store['.']['vSrn'] = ('long', 1)
    store['.']['icvl'] = ('type', b'icnv')
    store['.']['bwsp'] = {
        'ShowStatusBar': False, 'ShowToolbar': False, 'ShowPathbar': False,
        'ContainerShowSidebar': False, 'PreviewPaneVisibility': False,
        'ShowSidebar': False, 'ShowTabView': False, 'SidebarWidth': 0,
        'WindowBounds': '{{180, 140}, {760, 500}}',
    }
    store['.']['icvp'] = {
        'viewOptionsVersion': 1, 'backgroundType': 2,
        'backgroundColorRed': 1.0, 'backgroundColorGreen': 1.0, 'backgroundColorBlue': 1.0,
        'backgroundImageAlias': background,
        'iconSize': 128.0, 'textSize': 14.0, 'gridSpacing': 100.0,
        'gridOffsetX': 0.0, 'gridOffsetY': 0.0,
        'labelOnBottom': True, 'showItemInfo': False, 'showIconPreview': False,
        'arrangeBy': 'none', 'scrollPositionX': 0.0, 'scrollPositionY': 0.0,
    }
    store['.']['vstl'] = ('type', b'icnv')
    store[next(p.name for p in mount.iterdir() if p.suffix == '.app')]['Iloc'] = (210, 255)
    store['Applications']['Iloc'] = (550, 255)
with DSStore.open(str(mount / '.DS_Store'), 'r') as store:
    assert store[next(p.name for p in mount.iterdir() if p.suffix == '.app')]['Iloc'] == (210, 255)
    assert store['Applications']['Iloc'] == (550, 255)
    assert store['.']['icvp']['backgroundImageAlias'] == background
