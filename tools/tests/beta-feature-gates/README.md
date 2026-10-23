# Beta feature gates

Run `python3 tools/tests/beta-feature-gates/check.py` from the repository root.

The check compiles the production News configuration function and recording-to-text availability property in four configurations: DEBUG, release, BETA, and DEBUG+BETA. Only plain DEBUG enables these features. News server configuration cannot override the release/beta gate. The check also verifies that transcription startup consults the same availability guard before requesting speech-recognition permission.

The test substitutes only the AppConfiguration data container. It does not start an actual recording session. Transcription of received voice messages is not changed.
