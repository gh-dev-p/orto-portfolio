#!/usr/bin/env bash
# flavor（dev/prod）ごとにFirebase設定ファイルを生成し直す。
#
# 使い方：scripts/configure_firebase.sh dev|prod
#
# 素の`flutterfire configure`はflavorを考慮せず、lib/firebase_options.dart等の不要な
# ファイルを作ったりproject.pbxprojを書き換えたりするため、必ずこのスクリプト経由で実行する。
# Firebase側にBundle ID／パッケージ名のアプリが未登録なら、flutterfireが自動で登録する。
#
# 生成・更新されるもの：
#   - lib/firebase_options_<env>.dart
#   - android/app/src/<env>/google-services.json
# それ以外（project.pbxproj・ios/Runner/GoogleService-Info.plist）は実行前の状態に戻す。flutterfireがリポジトリ直下に
# 作るfirebase.json（アプリ側の設定の対応表）も削除する。サーバ側のfirebase.jsonはfirebase/にあり、flutterfireは触らない。
# iOSはDart側のFirebaseOptionsで初期化しているため、GoogleService-Info.plistは使わない。
set -euo pipefail

cd "$(dirname "$0")/.."

# ---- 環境ごとの設定 ----
env="${1:-}"
case "$env" in
  dev)
    project=example-orto-dev
    ios_bundle_id=com.example.orto.dev
    android_package=com.example.orto.dev
    ;;
  prod)
    project=example-orto-prod
    ios_bundle_id=com.example.orto
    android_package=com.example.orto
    ;;
  *)
    echo "使い方: $0 dev|prod" >&2
    exit 1
    ;;
esac
dart_out="lib/firebase_options_${env}.dart"
android_out="android/app/src/${env}/google-services.json"

# ---- flutterfireの副作用から守るファイルを退避 ----
backup_dir="$(mktemp -d)"
protected=(ios/Runner.xcodeproj/project.pbxproj)
for f in "${protected[@]}"; do
  cp "$f" "$backup_dir/$(basename "$f")"
done
restore() {
  for f in "${protected[@]}"; do
    cp "$backup_dir/$(basename "$f")" "$f"
  done
  rm -f ios/Runner/GoogleService-Info.plist firebase.json
  rm -rf "$backup_dir"
}
trap restore EXIT

# ---- 生成 ----
flutterfire configure \
  --yes \
  --project="$project" \
  --platforms=android,ios \
  --out="$dart_out" \
  --ios-bundle-id="$ios_bundle_id" \
  --android-package-name="$android_package" \
  --android-out="$android_out"

# ---- 検証 ----
errors=0
if ! grep -q "projectId: '$project'" "$dart_out"; then
  echo "NG: $dart_out のprojectIdが $project ではない" >&2
  errors=1
fi
if ! grep -q "iosBundleId: '$ios_bundle_id'" "$dart_out"; then
  echo "NG: $dart_out のiosBundleIdが $ios_bundle_id ではない" >&2
  errors=1
fi
if ! grep -q "\"package_name\": \"$android_package\"" "$android_out"; then
  echo "NG: $android_out に $android_package のクライアントが無い" >&2
  errors=1
fi

# 電話認証のreCAPTCHAフォールバックに使うURLスキーム（app-<iOSアプリIDの:を-に置換>）
ios_app_id="$(sed -n "/static const FirebaseOptions ios/,/);/s/.*appId: '\([^']*\)'.*/\1/p" "$dart_out")"
url_scheme="app-${ios_app_id//:/-}"
if ! grep -q "<string>$url_scheme</string>" ios/Runner/Info.plist; then
  echo "NG: ios/Runner/Info.plist のCFBundleURLSchemesに $url_scheme が無い（古い${env}用のスキームと差し替えること）" >&2
  errors=1
fi

if [ "$errors" -ne 0 ]; then
  exit 1
fi
echo "OK: ${env}（${project} / iOS ${ios_bundle_id} / Android ${android_package}）の設定を生成した"
