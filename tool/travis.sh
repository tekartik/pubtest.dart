#!/bin/bash

# Fast fail the script on failures.
set -e

pub run test -p firefox
pub run test -p firefox