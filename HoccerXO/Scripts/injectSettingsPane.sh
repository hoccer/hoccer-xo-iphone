#!/bin/sh

#  injectSettingsPane.sh
#  HoccerXO
#
#  Created by David Siegel on 12.02.14.
#  Copyright (c) 2014 Hoccer GmbH. All rights reserved.

PROG=`basename $0`
PLISTBUDDY="/usr/libexec/PlistBuddy"

#set -e

if [ -z "$1" ]; then
  echo "Usage:"
  echo "   $PROG plist_file [child_pane_name]"
  echo "   child_pane_name defaults to 'Debug'"
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

CHILD_PANE_FILE_VALUE=`$PLISTBUDDY -c "Print PreferenceSpecifiers:1:File" "$TARGET" 2>/dev/null`
if [ $? -eq 0 ] && [ "$CHILD_PANE_FILE_VALUE" == "$CHILD_PANE_NAME" ]; then
  echo "$PROG: child pane '$CHILD_PANE_NAME' is already present"
  exit 0
fi

echo "$PROG: adding child pane '$CHILD_PANE_NAME' to $TARGET"

$PLISTBUDDY -c "Add PreferenceSpecifiers:0 dict" "$TARGET"
$PLISTBUDDY -c "Add PreferenceSpecifiers:0:Type string 'PSGroupSpecifier'" "$TARGET"

$PLISTBUDDY -c "Add PreferenceSpecifiers:1 dict" "$TARGET"
$PLISTBUDDY -c "Add PreferenceSpecifiers:1:Type string 'PSChildPaneSpecifier'" "$TARGET"
$PLISTBUDDY -c "Add PreferenceSpecifiers:1:Title string '$CHILD_PANE_NAME'" "$TARGET"
$PLISTBUDDY -c "Add PreferenceSpecifiers:1:File string '$CHILD_PANE_NAME'" "$TARGET"