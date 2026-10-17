#!/bin/bash
# On the cloud Mac: archives the app, signs it with Jordan's App Store Connect key (automatic signing: Xcode makes
# the profiles itself, with the one development certificate the workflow puts in a keychain from the repo's secrets)
# and uploads it to TestFlight. The build number is the workflow run's. Copied from train-widget/ios/ci/testflight.sh
# (the ios-testflight skill keeps the master copy); only the project and scheme differ, and there's no app secret.
# Needs KEY_ID, ISSUER and TEAM, and the key at ~/.appstoreconnect/private_keys/AuthKey_$KEY_ID.p8.
set -euo pipefail
cd "$(dirname "$0")/../.."
KEY=~/.appstoreconnect/private_keys/AuthKey_$KEY_ID.p8
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$KEY" -authenticationKeyID "$KEY_ID" -authenticationKeyIssuerID "$ISSUER")
BUILD=${GITHUB_RUN_NUMBER:-1}
mkdir -p ios/build
xcodebuild archive -project ios/Insieme.xcodeproj -scheme Insieme -configuration Release \
  -destination 'generic/platform=iOS' -archivePath ios/build/Insieme.xcarchive \
  DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic CURRENT_PROJECT_VERSION="$BUILD" "${AUTH[@]}" \
  > ios/build/archive.log 2>&1 || { grep -E "error|Error" ios/build/archive.log | head -40; exit 1; }
echo "archived, build $BUILD"
cat > ios/build/export.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>manageAppVersionAndBuildNumber</key><false/>
  <key>testFlightInternalTestingOnly</key><true/>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath ios/build/Insieme.xcarchive -exportOptionsPlist ios/build/export.plist \
  -exportPath ios/build/export "${AUTH[@]}" > ios/build/export.log 2>&1 || { grep -iE "error|fail" ios/build/export.log | head -40; exit 1; }
grep -iE "upload|EXPORT SUCCEEDED" ios/build/export.log | tail -5
echo "sent to TestFlight: build $BUILD (Apple takes a few minutes to process it)"
