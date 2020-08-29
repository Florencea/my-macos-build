#!/usr/bin/env zsh
# nano ~/.config/fish/config.fish
# alias urb="sh ~/GitHub/my-macos-build/ublock-rule-backup.sh"
echo ""
printf 'Minifiy ec-rules...'
python3 ~/GitHub/my-macos-build/scripts/ublock-rule-combiner.py
echo "done."
echo ""
printf 'Update ec-rules to github...'
git add ~/GitHub/my-macos-build/configs/*
git commit -q -m "feat: update ec-rules by urb"
git push -q
echo "done."
echo ""
