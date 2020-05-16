#!/bin/bash
repo_list=$(curl -H "Authorization: token $1" -s https://api.github.com/user/repos?type=owner\&per_page=1000 | jq .[].ssh_url | sed -e 's/^"//'  -e 's/"$//')
for repo in $repo_list
do
  git clone $repo
done
rm $0
