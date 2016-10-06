#!/bin/bash

# Fast fail the script on failures.
set -e

dartanalyzer --fatal-warnings \
  bin/pubtest.dart \
  bin/pubtestdependencies.dart \

pub run test -p vm
pub run test -p chrome
pub run test -p firefox