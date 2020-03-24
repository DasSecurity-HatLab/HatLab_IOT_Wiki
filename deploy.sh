#!/bin/bash

mkdocs gh-deploy
sleep 1

git add .
git commit -m "update"

git push origin gh-pages
