#!/bin/sh
set -e
set -x


BUILD_CONFIGURATION=$1

PWDPATH=$PWD

CPPATH="$HOME/build-${BUILD_CONFIGURATION}"
PROJECT="${CPPATH}/telegrammacos"


rsync -av --progress --delete \
    --exclude='/telegrammacos/core-xprojects/*/build/' \
    --exclude='/telegrammacos/packages/WalletEngine/wallet_engineFFI.xcframework/' \
    --exclude='/telegrammacos/submodules/telegram-ios/submodules/MTProtoRustEngine/MTProtoEngineFFI.xcframework/' \
    --exclude='/telegrammacos/submodules/*/SharedHeaders/' \
    ../telegrammacos $CPPATH  > /dev/null

cd $PROJECT
cd ..
files_to_remove=$(ls -A | grep -v telegrammacos || true)
if [ -n "$files_to_remove" ]; then
    rm -r $files_to_remove
else
    echo "No files to remove."
fi

rm -r telegrammacos.xcarchive || true

cd telegrammacos


sh "scripts/configure_frameworks.sh"
cp "configurations/${BUILD_CONFIGURATION}.xcconfig" "Telegram-Mac/Release.xcconfig"

case "${BUILD_CONFIGURATION}" in
    Alpha) CHANNEL_CONDITION="ALPHA" ;;
    Beta) CHANNEL_CONDITION="BETA" ;;
    Stable) CHANNEL_CONDITION="STABLE" ;;
    AppStore|Appstore) CHANNEL_CONDITION="APP_STORE" ;;
    *) echo "Unknown build configuration: ${BUILD_CONFIGURATION}" >&2; exit 1 ;;
esac

xcodebuild archive -workspace "Telegram-Mac.xcworkspace" \
-scheme Release \
-configuration Release \
-archivePath ./ \
"SWIFT_ACTIVE_COMPILATION_CONDITIONS=\$(inherited) ${CHANNEL_CONDITION}"


cd ..

archive="./telegrammacos.xcarchive"
appname="Telegram.app"

rm -rf ${appname} ${appname}.dSYM ${appname}.DSYM.zip
cp -R "${archive}/Products/Applications/ChargedGram.app" ${appname}
cp -R "${archive}/dSYMs/ChargedGram.app.dSYM" ${appname}.dSYM


ditto -c -k --sequesterRsrc --keepParent ${appname}.dSYM ${appname}.DSYM.zip
