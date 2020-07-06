#!/bin/bash

mkdocs build
sleep 1

mkdocs gh-deploy
sleep 3

git add .
git commit -m "update"
git push origin master