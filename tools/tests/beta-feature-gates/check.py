from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[3]
for package in ('NewsUI', 'HTMLBubbles', 'AppAnalytics'):
    assert not (root / 'packages' / package / 'Package.swift').exists()
    assert not (root / 'packages' / package / 'Sources').exists()
    assert package not in (root / 'Telegram.xcodeproj/project.pbxproj').read_text()
for package in ('ChatUI', 'ChatListUI'):
    assert 'HTMLBubbles' not in (root / 'packages' / package / 'Package.swift').read_text()
for path in list((root / 'Telegram-Mac').rglob('*.swift')) + list((root / 'packages').rglob('*.swift')):
    source = path.read_text()
    assert 'import NewsUI' not in source and 'import HTMLBubbles' not in source and 'AppAnalytics' not in source
state = (root / 'packages/ChatUI/Sources/ChatUI/ChatPresentationInterfaceState.swift').read_text()
assert 'newsChannel' not in state
row = (root / 'packages/ChatUI/Sources/ChatUI/ChatRowItem.swift').read_text()
assert 'message.anyMedia is TelegramMediaUnsupported' in row
voice = (root / 'packages/ChatUI/Sources/ChatUI/ChatVoiceTranscription.swift').read_text()
start = voice.index('    static var isSupported: Bool {')
end = voice.index('    var isActive:', start)
availability = voice[start:end]
assert 'guard Self.isSupported, #available(macOS 10.15, *) else {' in voice
source = '''import Foundation
''' + '\nenum VoiceAvailability {\n' + availability + '''\n}
#if EXPECT_ENABLED
precondition(VoiceAvailability.isSupported)
#else
precondition(!VoiceAvailability.isSupported)
#endif
'''
with tempfile.TemporaryDirectory(prefix='beta-feature-gates-') as temporary:
    directory = Path(temporary)
    path = directory / 'main.swift'
    path.write_text(source)
    for name, flags in [('debug', ['DEBUG', 'EXPECT_ENABLED']), ('release', []), ('beta', ['BETA']), ('debug-beta', ['DEBUG', 'BETA'])]:
        binary = directory / name
        command = ['swiftc', '-module-cache-path', str(directory / 'cache'), str(path), '-o', str(binary)]
        for flag in flags:
            command.extend(['-D', flag])
        subprocess.run(command, check=True)
        subprocess.run([str(binary)], check=True)
        print(f'{name}: passed', flush=True)
