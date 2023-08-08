#!/bin/bash
set -euo pipefail

cd ~
if [ ! -e ~/bhusa2023  ] ; then
  git clone https://github.com/bustakube/bhusa2023.git ~/bhusa2023
else
  cd ~/bhusa2023
  git pull
fi

if [ ! -f ~/exercises/style.original ] ; then
  cp -v ~/exercises/assets/css/style.css ~/exercises/style.original
  cp -v ~/bhusa2023/files/style.css ~/exercises/assets/css/style.css
  chown lockthisdown:lockthisdown ~/exercises/assets/css/style.css
fi

cp ~/bhusa2023/exercises/*.md ~/exercises/exercises/
