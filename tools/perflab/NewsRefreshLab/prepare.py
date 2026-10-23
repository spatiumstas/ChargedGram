from pathlib import Path
import hashlib
import json

lab = Path(__file__).resolve().parent
root = lab.parents[2]
provenance = {}
for name in ['NewsPullToRefresh', 'NewsRefreshPresentation', 'NewsListController', 'NewsNewPostsPillView']:
    path = root / f'packages/NewsUI/Sources/NewsUI/{name}.swift'
    source = path.read_text()
    provenance[str(path.relative_to(root))] = hashlib.sha256(source.encode()).hexdigest()
    for module in ['TelegramTheme', 'TelegramMedia', 'LocalAnimations']:
        source = source.replace(f'import {module}\n', '')
    source = source.replace('private func scrolled(', 'func scrolled(').replace('private func checkLoading(', 'func checkLoading(').replace('private var startedAt:', 'var startedAt:')
    if name == 'NewsPullToRefresh':
        source = source.replace('tableView.liveDocumentOffset.y', 'labLiveDocumentOffset(tableView).y')
    (lab / f'Sources/NewsRefreshViews/Generated{name}.swift').write_text(source)
(lab / 'provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
