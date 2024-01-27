#!/bin/bash

branch_prefix=$1

max_number="-1.0"
branches=$(git branch -r | grep -E "origin/.*$branch_prefix-[0-9]+\.[0-9]+")
latest_branch=""
for branch in $branches
do
    number=$(echo "$branch" | grep -oE "[0-9]+\.[0-9]+")
    if [ "$(awk 'BEGIN{print ('$number' > '$max_number') ? "1" : "0"}')" -eq 1 ]; then
      max_number="$number"
	    latest_branch=$branch_prefix-$max_number
    fi
done

echo $latest_branch
