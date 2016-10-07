#!/bin/bash

# Fast fail the script on failures.
set -e

dartanalyzer --fatal-warnings \
  bin/pubtest.dart \
  bin/pubtestdependencies.dart \
  bin/pubtestpackage.dart \

pub run test -p vm
