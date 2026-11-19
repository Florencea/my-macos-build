complete -c mkclp -e
complete -c mkclp -f
complete -c mkclp -n __fish_is_first_arg -F
complete -c mkclp -s q -l quality -x -a '40 45 50 60 75' -d 'Set VideoToolbox quality (default: 50)'
complete -c mkclp -s c -l copy -d 'Force stream copy without re-encoding'
complete -c mkclp -s b -l browser -x -a 'edge chrome firefox safari' -d 'Browser for YouTube cookies (default: edge)'
complete -c mkclp -s o -l output -r -F -d 'Output file path'
complete -c mkclp -d 'Clip Maker (Apple Silicon HEVC)'
