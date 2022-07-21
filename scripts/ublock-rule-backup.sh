#! /bin/bash
# nano ~/.config/fish/config.fish
# alias urb="sh ~/Codespaces/my-macos-build/scripts/ublock-rule-backup.sh"
echo ""
printf 'Minifiy ec-rules for ubo...'
python3 ~/Codespaces/my-macos-build/scripts/ublock-rule-combiner.py
echo "done."
printf 'Minifiy ec-rules for adg...'
python3 ~/Codespaces/my-macos-build/scripts/adguard-rule-combiner.py
echo "done."
echo ""
printf 'Update ec-rules...'
cd ~/Codespaces/my-macos-build/ || exit
git add configs/element-custom-rules-desktop.txt
git add configs/element-custom-rules-desktop.combined.txt
git add configs/element-custom-rules-desktop.adguard.txt
git add configs/element-custom-rules-mobile.txt
git add configs/element-custom-rules-mobile.combined.txt
git add configs/element-custom-rules-mobile.adguard.txt
git add configs/element-custom-rules-dark.txt
git add configs/element-custom-rules-dark.combined.txt
git add configs/element-custom-rules-dark.adguard.txt
git commit -q -m "feat: update ec-rules by urb"
git push -q
echo "done."
echo ""
