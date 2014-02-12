#!/bin/sh

#  injectDebugSettingsPane.sh
#  HoccerXO
#
#  Created by David Siegel on 12.02.14.
#  Copyright (c) 2014 Hoccer GmbH. All rights reserved.

PROG="`basename $0`"
PLISTBUDDY="/usr/libexec/PlistBuddy -x"

set -e

if [ -z "$1" ]; then
  echo "Usage:"
  echo "   $PROG plist_file [child_pane_name]"
  echo "   - If unspecified, child_pane_name is 'Debug'"
  exit 1
fi

if [ ! -e "$1" ]; then
  echo "[$PROG] file not found: '$1'"
  exit 2
fi

if [ ! -z "$2" ]; then
  CHILD_PANE_NAME="$2"
else
  CHILD_PANE_NAME="Debug"
fi

TARGET="$1"
echo "[$PROG] adding '$CHILD_PANE_NAME' child to: $TARGET"

$PLISTBUDDY -c "Add PreferenceSpecifiers:0 dict" "$TARGET"
$PLISTBUDDY -c "Add PreferenceSpecifiers:0:Type string 'PSGroupSpecifier'" "$TARGET"

$PLISTBUDDY -c "Add PreferenceSpecifiers:1 dict" "$TARGET"
$PLISTBUDDY -c "Add PreferenceSpecifiers:1:Type string 'PSChildPaneSpecifier'" "$TARGET"
$PLISTBUDDY -c "Add PreferenceSpecifiers:1:Title string '$CHILD_PANE_NAME Settings'" "$TARGET"
$PLISTBUDDY -c "Add PreferenceSpecifiers:1:File string '$CHILD_PANE_NAME'" "$TARGET"