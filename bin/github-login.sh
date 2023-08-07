#!/bin/bash
#
# Quick fix to save you from having to keep typing in your token
#

echo -n "Username: "
read username

echo -n "Token: "
read token

git config --global url."https://${username}:${token}@github.com/bustakube/bhusa2023.git".InsteadOf https://github.com/bustakube/bhusa2023.git
git config --global url."https://${username}:${token}@github.com/bustakube/bhusa2023".InsteadOf https://github.com/bustakube/bhusa2023