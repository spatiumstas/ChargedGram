from pathlib import Path
import json
import subprocess
import tempfile

root = Path(__file__).resolve().parents[3]
paths = [
    'packages/ChatUI/Sources/ChatUI/ChatRichTextDraftStore.swift',
    'packages/ChatUI/Sources/ChatUI/ChatForwardSelection.swift',
    'packages/PreviewSenderUI/Sources/PreviewSenderUI/PreviewSenderPendingActions.swift',
    'packages/PreviewSenderUI/Sources/PreviewSenderUI/PreviewSenderChildAction.swift',
    'packages/WebAppUI/Sources/WebAppUI/BrowserDecision.swift',
]
sources = '\n'.join((root / path).read_text() for path in paths)
sources = sources.replace('import Postbox\n', '').replace('import TelegramCore\n', '')
sources += (root / 'packages/ChatUI/Sources/ChatUI/ChatDeferredSendAction.swift').read_text().split('\nfunc chatHasSameDeferredSendState')[0]
fixture = Path(__file__).with_name('LifecycleTests.swift').read_text().replace('__SOURCES__', sources)
with tempfile.TemporaryDirectory(prefix='beta-interaction-lifecycle-') as temporary:
    directory = Path(temporary)
    dependency = json.dumps(str(root / 'submodules/telegram-ios/submodules/SSignalKit'))
    (directory / 'Package.swift').write_text('''// swift-tools-version:5.9
import PackageDescription
let package = Package(name: "BetaInteractionLifecycle", platforms: [.macOS(.v10_13)], dependencies: [.package(path: ''' + dependency + ''')], targets: [.testTarget(name: "LifecycleTests", dependencies: [.product(name: "SwiftSignalKit", package: "SSignalKit")], path: "Tests")])
''')
    (directory / 'Tests').mkdir()
    (directory / 'Tests/LifecycleTests.swift').write_text(fixture)
    raise SystemExit(subprocess.run(['swift', 'test', '--package-path', str(directory), '--disable-sandbox', '--jobs', '4']).returncode)
