complete -c mkgif -e
complete -c mkgif -f
complete -c mkgif -n __fish_is_first_arg -F
complete -c mkgif -l fps -x -a '8 10 12 15 24' -d 'Set FPS (default: 10)'
complete -c mkgif -s w -l width -x -a '480 640 720 1280' -d 'Set width in px (default: 720)'
complete -c mkgif -s q -l quality -x -a '60 70 80 85' -d 'Set gifski quality 1-100 (default: 70)'
complete -c mkgif -s l -l lossy -d 'Enable lossy LZW compression (default: off)'
complete -c mkgif -s b -l browser -x -a 'chrome edge firefox safari' -d 'Browser for YouTube cookies (default: chrome)'
complete -c mkgif -s o -l output -r -F -d 'Output file path'
complete -c mkgif -s h -l help -d 'Show help message'
complete -c mkgif -d 'High-quality Gif Maker via gifski'
