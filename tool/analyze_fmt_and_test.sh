#!/bin/bash

# Fast fail the script on failures.
set -xe

dartfmt -w bin example lib test
dartanalyzer --fatal-warnings bin example lib test

# pub run test -p vm
pub run build_runner test