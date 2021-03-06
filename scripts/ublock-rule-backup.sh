#! /bin/bash
# nano ~/.config/fish/config.fish
# alias urb="sh ~/GitHub/my-macos-build/scripts/ublock-rule-backup.sh"
echo ""
printf 'Minifiy ec-rules...'
python3 ~/GitHub/my-macos-build/scripts/ublock-rule-combiner.py
echo "done."
echo ""
printf 'Update ec-rules to github...'
cd ~/GitHub/my-macos-build/ || exit
git add configs/*
git commit -q -m "feat: update ec-rules by urb"
git push -q
echo "done."
echo ""
