#!/bin/sh

tjc_command_exists() {
  command -v "$1" >/dev/null 2>&1
}

tjc_is_termux() {
  [ -d "/data/data/com.termux/files/usr" ]
}
