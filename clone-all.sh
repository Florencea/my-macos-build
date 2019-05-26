#!/bin/bash
repo_list=$(curl -s https://api.github.com/user/repos?type=owner\&access_token=$1 | jq .[].ssh_url | sed -e 's/^"//'  -e 's/"$//')
for repo in $repo_list
do
  git clone $repo
done
rm $0
