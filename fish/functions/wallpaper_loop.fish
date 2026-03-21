function wallpaper_loop --description 'Quick access for wp-daemon. Use index (1, 2, ...) or path. "list" shows indexed dirs.'
    set wp_daemon $HOME/wp-daemon/target/release/wp-daemon
    set dirs_file $HOME/.config/wp-daemon/dirs

    if test (count $argv) -eq 0
        $wp_daemon start $HOME/Wallpapers
    else if contains -- "$argv[1]" -h --help
        echo "Usage: wallpaper_loop [index|path|list|add|stop]"
        echo "  (no args)  - Start with default dir (~/Wallpapers)"
        echo "  <index>    - Use indexed dir (1, 2, ...) from ~/.config/wp-daemon/dirs"
        echo "  <index> f  - Same, but show instantly (don't wait for next cycle)"
        echo "  <path>     - Use directory path directly"
        echo "  list       - Show indexed dirs"
        echo "  add [i] <path>  - Add dir to index (optional: index i, else auto-assign)"
        echo "  stop       - Stop daemon"
    else if test "$argv[1]" = "list"
        if test -f $dirs_file
            printf "Index  Path\n"
            printf "-----  ----\n"
            while read -l line
                set -l trimmed (string trim $line)
                if test -n "$trimmed" ; and not string match -q "#*" $trimmed
                    set -l parts (string split "=" $trimmed)
                    if test (count $parts) -ge 2
                        printf "%5s  %s\n" $parts[1] $parts[2]
                    end
                end
            end < $dirs_file
        else
            echo "No dirs config at $dirs_file"
        end
    else if test "$argv[1]" = "add"
        if test (count $argv) -lt 2
            echo "Usage: wallpaper_loop add [index] <path>"
            return 1
        end
        set -l new_index ""
        set -l new_path ""
        if test (count $argv) -eq 2
            set new_path $argv[2]
        else
            if string match -qr '^[0-9]+$' $argv[2]
                set new_index $argv[2]
                set new_path $argv[3]
            else
                set new_path $argv[2]
            end
        end
        if test -z "$new_path"
            echo "Usage: wallpaper_loop add [index] <path>"
            return 1
        end
        set -l resolved (realpath $new_path 2>/dev/null; or echo $new_path)
        if not test -d "$resolved"
            echo "Not a directory: $new_path"
            return 1
        end
        mkdir -p (dirname $dirs_file)
        if test -z "$new_index"
            set -l max 0
            if test -f $dirs_file
                while read -l line
                    set -l trimmed (string trim $line)
                    if test -n "$trimmed" ; and not string match -q "#*" $trimmed
                        set -l parts (string split "=" $trimmed)
                        if test (count $parts) -ge 2 ; and string match -qr '^[0-9]+$' $parts[1]
                            if test $parts[1] -gt $max
                                set max $parts[1]
                            end
                        end
                    end
                end < $dirs_file
            end
            set new_index (math $max + 1)
        end
        echo "$new_index=$resolved" >> $dirs_file
        echo "Added $new_index -> $resolved"
    else if test "$argv[1]" = "stop"
        $wp_daemon stop
    else
        set arg $argv[1]
        set instant "false"
        if test (count $argv) -ge 2 ; and test "$argv[2]" = "f"
            set instant "true"
        end
        set images_dir ""

        if string match -qr '^[0-9]+$' $arg
            if test -f $dirs_file
                while read -l line
                    set -l trimmed (string trim $line)
                    if test -n "$trimmed" ; and not string match -q "#*" $trimmed
                        set -l parts (string split "=" $trimmed)
                        if test (count $parts) -ge 2 ; and test "$parts[1]" = "$arg"
                            set images_dir $parts[2]
                            break
                        end
                    end
                end < $dirs_file
            end
        else if not test "$arg" = "f"
            set images_dir $arg
        end

        if test -n "$images_dir"
            $wp_daemon set $images_dir
            $wp_daemon start $images_dir
            if test "$instant" = "true"
                $wp_daemon show $images_dir
            end
        else
            echo "Unknown index or path: $arg"
            echo "Use 'wallpaper_loop list' to see indexed dirs"
        end
    end
end
