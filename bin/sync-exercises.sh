#!/bin/bash

if [ ! -e ~/bhusa2023  ] ; then
  cd ~
  git clone https://github.com/bustakube/bhusa2023.git ~/bhusa2023
else
  cd ~/bhusa2023
  git pull
fi

cp ~/bhusa2023/exercises/*.md /root/exercises/exercises/
