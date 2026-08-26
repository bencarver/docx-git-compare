#!/usr/bin/env bash
# install-quick-action.sh — install the "Compare Versions" Finder Quick Action.
#
# Builds ~/Library/Services/Compare Versions.workflow, which right-clicking a Word
# document in Finder exposes under Quick Actions. Re-run it any time to reinstall.
set -euo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SCRIPT="$HERE/gitcompare.sh"
[ -x "$SCRIPT" ] || { echo "gitcompare.sh missing or not executable at $SCRIPT" >&2; exit 1; }

WF="$HOME/Library/Services/Compare Versions.workflow"
rm -rf "$WF"; mkdir -p "$WF/Contents"

cat > "$WF/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>io.github.bencarver.gitcompare</string>
  <key>CFBundleName</key><string>Compare Versions</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleDevelopmentRegion</key><string>en_US</string>
  <key>NSServices</key>
  <array>
    <dict>
      <key>NSMenuItem</key><dict><key>default</key><string>Compare Versions</string></dict>
      <key>NSMessage</key><string>runWorkflowAsService</string>
      <key>NSRequiredContext</key>
      <dict><key>NSApplicationIdentifier</key><string>com.apple.finder</string></dict>
      <key>NSSendFileTypes</key>
      <array>
        <string>org.openxmlformats.wordprocessingml.document</string>
        <string>com.microsoft.word.doc</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

# The Quick Action is a one-action Automator workflow wrapping this shell command.
COMMAND=$(cat <<CMD
for f in "\$@"; do
  "$SCRIPT" "\$f" --gui
done
CMD
)

python3 - "$WF/Contents/document.wflow" "$COMMAND" <<'PY'
import plistlib, sys, uuid
out, command = sys.argv[1], sys.argv[2]
action = {
    "action": {
        "AMAccepts": {"Container": "List", "Optional": True,
                      "Types": ["com.apple.cocoa.string"]},
        "AMActionVersion": "2.0.3",
        "AMApplication": ["Automator"],
        "AMParameterProperties": {
            "COMMAND_STRING": {}, "CheckedForUserDefaultShell": {},
            "inputMethod": {}, "shell": {}, "source": {},
        },
        "AMProvides": {"Container": "List", "Types": ["com.apple.cocoa.string"]},
        "ActionBundlePath":
            "/System/Library/Automator/Run Shell Script.action",
        "ActionName": "Run Shell Script",
        "ActionParameters": {
            "COMMAND_STRING": command,
            "CheckedForUserDefaultShell": True,
            "inputMethod": 1,          # 1 = pass the selected files as arguments
            "shell": "/bin/bash",
            "source": "",
        },
        "BundleIdentifier": "com.apple.RunShellScript",
        "CFBundleVersion": "2.0.3",
        "CanShowSelectedItemsWhenRun": False,
        "CanShowWhenRun": True,
        "Category": ["AMCategoryUtilities"],
        "Class Name": "RunShellScriptAction",
        "InputUUID": str(uuid.uuid4()).upper(),
        "Keywords": ["Shell", "Script", "Command", "Run", "Unix"],
        "OutputUUID": str(uuid.uuid4()).upper(),
        "UUID": str(uuid.uuid4()).upper(),
        "UnlocalizedApplications": ["Automator"],
        "arguments": {
            "0": {"default value": 0, "name": "inputMethod",
                  "required": "0", "type": "0", "uuid": "0"},
            "1": {"default value": False, "name": "CheckedForUserDefaultShell",
                  "required": "0", "type": "0", "uuid": "1"},
            "2": {"default value": "", "name": "source",
                  "required": "0", "type": "0", "uuid": "2"},
            "3": {"default value": "", "name": "COMMAND_STRING",
                  "required": "0", "type": "0", "uuid": "3"},
            "4": {"default value": "/bin/sh", "name": "shell",
                  "required": "0", "type": "0", "uuid": "4"},
        },
        "isViewVisible": 1,
        "location": "309.000000:253.000000",
        "nibPath":
            "/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib",
    },
    "isViewVisible": 1,
}
doc = {
    "AMApplicationBuild": "521",
    "AMApplicationVersion": "2.10",
    "AMDocumentVersion": "2",
    "actions": [action],
    "connectors": {},
    "workflowMetaData": {
        "serviceApplicationBundleID": "com.apple.finder",
        "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
        "serviceInputTypeIdentifier":
            "com.apple.Automator.fileSystemObject.document",
        "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
        "serviceProcessesInput": 0,
        "systemImageName": "NSActionTemplate",
        "useAutomaticInputType": 0,
        "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
    },
}
with open(out, "wb") as fh:
    plistlib.dump(doc, fh)
PY

/System/Library/CoreServices/pbs -flush 2>/dev/null || true

echo "installed: $WF"

# Registration is asynchronous; pbs needs a moment before it will admit the service exists.
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if /System/Library/CoreServices/pbs -dump_pboard 2>/dev/null | grep -q "Compare Versions"; then
    echo "registered — right-click a .docx in Finder > Services > Compare Versions."
    exit 0
  fi
  sleep 1
done
echo "note: not visible to pbs yet. It usually appears within a minute, or after" >&2
echo "      killall Finder. Reinstalling over an existing copy needs a Finder restart" >&2
echo "      before the change takes effect." >&2
