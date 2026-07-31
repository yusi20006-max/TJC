#!/bin/sh

# shellcheck disable=SC2034
if [ -t 1 ]; then
  TJC_COLOR_RED=$(printf '\033[31m')
  TJC_COLOR_GREEN=$(printf '\033[32m')
  TJC_COLOR_YELLOW=$(printf '\033[33m')
  TJC_COLOR_BLUE=$(printf '\033[34m')
  TJC_COLOR_RESET=$(printf '\033[0m')
else
  TJC_COLOR_RED=''
  TJC_COLOR_GREEN=''
  TJC_COLOR_YELLOW=''
  TJC_COLOR_BLUE=''
  TJC_COLOR_RESET=''
fi
