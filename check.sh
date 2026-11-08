#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
cd "$here"
scripts="bin/axb35-power install.sh check.sh test/axb35-power.test.sh"
plugin=plugin/axb35.power
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

step() { printf '== %s\n' "$1"; }

step shellcheck
# shellcheck disable=SC2086
shellcheck $scripts

step shfmt
# shellcheck disable=SC2086
shfmt -d -i 2 -ci $scripts

step actionlint
actionlint

step json
for f in "$plugin/manifest.json" "$plugin"/i18n/*.json; do jq empty "$f"; done
id=$(jq -r .id "$plugin/manifest.json")
[ "$id" = "$(basename "$plugin")" ] || {
  echo "manifest id $id differs from folder $(basename "$plugin")" >&2
  exit 1
}
grep -q "moduleName: \"$id\"" "$plugin/Panel.qml" || {
  echo "Panel.qml moduleName differs from manifest id $id" >&2
  exit 1
}

step sudoers
visudo -cqf sudoers/axb35-power

step systemd
sed "s|^ExecStart=/usr/local/bin/axb35-power|ExecStart=$here/bin/axb35-power|" systemd/axb35-power.service >"$work/axb35-power.service"
warnings=$(systemd-analyze verify "$work/axb35-power.service" 2>&1)
[ -z "$warnings" ] || {
  echo "$warnings" >&2
  exit 1
}

if command -v omarchy >/dev/null; then
  step "omarchy plugin validate"
  omarchy plugin validate "$plugin"
fi

step test
test/axb35-power.test.sh
