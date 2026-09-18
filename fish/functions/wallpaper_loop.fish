# LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Fish wallpaper_loop CLI with unique named indexes, delete, and empty-index warnings. 2026-09-04.
function __wallpaper_loop_parse --argument-names line
    set -l trimmed (string trim $line)
    if test -z "$trimmed" ; or string match -q "#*" $trimmed
        return 1
    end
    set -l rest $trimmed
    set -l name ""
    if string match -q "* # *" $trimmed
        set -l split_name (string split -m 1 " # " $trimmed)
        set rest $split_name[1]
        set name (string trim $split_name[2])
    end
    set -l parts (string split -m 1 "=" $rest)
    if test (count $parts) -lt 2
        return 1
    end
    if not string match -qr '^[0-9]+$' $parts[1]
        return 1
    end
    printf '%s\t%s\t%s\n' $parts[1] $name $parts[2]
end

function __wallpaper_loop_load
    set -l dirs_file $argv[1]
    set -l names
    set -l paths
    if not test -f $dirs_file
        return 0
    end
    while read -l line
        set -l parsed (__wallpaper_loop_parse $line)
        if test -z "$parsed"
            continue
        end
        set -l fields (string split \t $parsed)
        if test (count $fields) -lt 3
            continue
        end
        set -l name $fields[2]
        set -l p (string join \t $fields[3..])
        if test -z "$name"
            set name (basename $p)
        end
        set -l skip 0
        for i in (seq (count $paths))
            if test "$paths[$i]" = "$p"
                set skip 1
                break
            end
        end
        if test $skip -eq 0 ; and test -n "$name"
            for i in (seq (count $names))
                if test "$names[$i]" = "$name"
                    set skip 1
                    break
                end
            end
        end
        if test $skip -eq 0
            set -a names "$name"
            set -a paths $p
        end
    end < $dirs_file

    # LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Emit stack entries as a compact 0-based index array. 2026-09-04.
    set -l i 0
    for j in (seq (count $paths))
        printf '%s\t%s\t%s\n' $i $names[$j] $paths[$j]
        set i (math $i + 1)
    end
    # LLM PROMPT [end]
end

function __wallpaper_loop_save --argument-names dirs_file
    mkdir -p (dirname $dirs_file)
    set -l names
    set -l paths
    set -l rest $argv[2..]
    while test (count $rest) -ge 3
        set -a names "$rest[2]"
        set -a paths $rest[3]
        set rest $rest[4..]
    end
    # LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Rewrite the dirs file with contiguous 0-based indexes. 2026-09-04.
    set -l lines
    set -l i 0
    for j in (seq (count $paths))
        set -l line "$i=$paths[$j]"
        if test -n "$names[$j]"
            set line "$line # $names[$j]"
        end
        set -a lines $line
        set i (math $i + 1)
    end
    # LLM PROMPT [end]
    if test (count $lines) -eq 0
        echo -n "" > $dirs_file
    else
        printf '%s\n' $lines > $dirs_file
    end
end

function __wallpaper_loop_image_count --argument-names dir
    set -l n 0
    if not test -d $dir
        echo 0
        return
    end
    for f in $dir/*
        if test -f $f
            set -l ext (string lower (string split -r -m1 . -- $f)[-1])
            if contains -- $ext jpg jpeg png webp
                set n (math $n + 1)
            end
        end
    end
    echo $n
end

function wallpaper_loop --description 'Quick access for wp-daemon. Use name, compact index, or path.'
    set wp_daemon $HOME/wp-daemon/target/release/wp-daemon
    set dirs_file $HOME/.config/wp-daemon/dirs

    if test (count $argv) -eq 0
        $wp_daemon start $HOME/Wallpapers
    else if contains -- "$argv[1]" -h --help
        echo "Usage: wallpaper_loop [name|index|path|list|add|name|del|stop]"
        echo "  (no args)     - Start with default dir (~/Wallpapers)"
        echo "  <name>        - Use a named dir from the stack"
        echo "  <name> f      - Same, but show instantly"
        echo "  <index>       - Use stack slot (0, 1, 2, ... no gaps)"
        echo "  <path>        - Use directory path directly"
        echo "  list          - Show the stack and compact indexes"
        echo "  add <name> <path>  - Append (or replace same name/path); index is assigned"
        echo "  name <i|old> <new> - Rename a stack entry"
        echo "  del <i|name|path>  - Remove an entry and compact the stack"
        echo "  stop          - Stop daemon"
    else if test "$argv[1]" = "list"
        set -l entries (__wallpaper_loop_load $dirs_file)
        if test (count $entries) -eq 0
            echo "No dirs config at $dirs_file"
            return 0
        end
        set -l save_args $dirs_file
        for row in $entries
            set -l fields (string split \t $row)
            set -a save_args $fields[1] "$fields[2]" (string join \t $fields[3..])
        end
        __wallpaper_loop_save $save_args
        printf "%-6s  %-16s  %-8s  %s\n" Index Name Images Path
        printf "%-6s  %-16s  %-8s  %s\n" ----- ---- ------ ----
        for row in $entries
            set -l fields (string split \t $row)
            set -l idx $fields[1]
            set -l name $fields[2]
            set -l p (string join \t $fields[3..])
            set -l n (__wallpaper_loop_image_count $p)
            if test -z "$name"
                set name "-"
            end
            printf "%-6s  %-16s  %-8s  %s\n" $idx $name $n $p
            if not test -d $p
                echo "Warning: index $idx is not a directory: $p" >&2
            else if test $n -eq 0
                echo "Warning: index $idx has no images: $p" >&2
            end
        end
    else if test "$argv[1]" = "add"
        # LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Add stack entries by name only and assign the next compact index. 2026-09-04.
        if test (count $argv) -lt 3
            echo "Usage: wallpaper_loop add <name> <path>"
            return 1
        end
        set -l new_path $argv[-1]
        set -l new_name (string join " " $argv[2..-2])
        if test -z "$new_name"
            echo "Usage: wallpaper_loop add <name> <path>"
            return 1
        end
        set -l resolved (realpath $new_path 2>/dev/null; or echo $new_path)
        if not test -d "$resolved"
            echo "Not a directory: $new_path"
            return 1
        end
        set -l n (__wallpaper_loop_image_count $resolved)
        if test $n -eq 0
            echo "Warning: no images in $resolved" >&2
        end
        set -l entries (__wallpaper_loop_load $dirs_file)
        set -l names
        set -l paths
        for row in $entries
            set -l fields (string split \t $row)
            set -a names "$fields[2]"
            set -a paths (string join \t $fields[3..])
        end
        set -l replaced 0
        for i in (seq (count $paths))
            if test "$names[$i]" = "$new_name" ; or test "$paths[$i]" = "$resolved"
                set names[$i] $new_name
                set paths[$i] $resolved
                set replaced 1
                break
            end
        end
        if test $replaced -eq 0
            set -a names "$new_name"
            set -a paths $resolved
        end
        set -l save_args $dirs_file
        for i in (seq (count $paths))
            set -a save_args $i "$names[$i]" $paths[$i]
        end
        __wallpaper_loop_save $save_args
        set -l assigned (math (count $paths) - 1)
        if test $replaced -eq 1
            for i in (seq (count $paths))
                if test "$names[$i]" = "$new_name"
                    set assigned (math $i - 1)
                    break
                end
            end
        end
        echo "Set $assigned ($new_name) -> $resolved"
    else if test "$argv[1]" = "name"
        if test (count $argv) -lt 3
            echo "Usage: wallpaper_loop name <index|oldname> <newname>"
            return 1
        end
        set -l target $argv[2]
        set -l new_name (string join " " $argv[3..])
        set -l entries (__wallpaper_loop_load $dirs_file)
        set -l names
        set -l paths
        set -l found 0
        for row in $entries
            set -l fields (string split \t $row)
            set -a paths (string join \t $fields[3..])
            if test "$fields[1]" = "$target" ; or test "$fields[2]" = "$target"
                set -a names "$new_name"
                set found 1
            else
                set -a names "$fields[2]"
            end
        end
        if test $found -eq 0
            echo "Warning: invalid index or name '$target'" >&2
            echo "Use 'wallpaper_loop list' to see the stack"
            return 1
        end
        set -l save_args $dirs_file
        for i in (seq (count $paths))
            set -a save_args $i "$names[$i]" $paths[$i]
        end
        __wallpaper_loop_save $save_args
        echo "Named $target -> $new_name"
        # LLM PROMPT [end]
    else if contains -- "$argv[1]" del delete rm
        if test (count $argv) -lt 2
            echo "Usage: wallpaper_loop del <index|name|path>"
            return 1
        end
        set -l target (string join " " $argv[2..])
        set -l resolved (realpath $target 2>/dev/null; or echo $target)
        set -l entries (__wallpaper_loop_load $dirs_file)
        set -l idxs
        set -l names
        set -l paths
        set -l found 0
        for row in $entries
            set -l fields (string split \t $row)
            set -l p (string join \t $fields[3..])
            set -l keep 1
            if test "$fields[1]" = "$target" ; or test "$fields[2]" = "$target" ; or test "$p" = "$target" ; or test "$p" = "$resolved"
                set keep 0
                set found 1
            end
            if test $keep -eq 1
                set -a idxs $fields[1]
                set -a names "$fields[2]"
                set -a paths $p
            end
        end
        if test $found -eq 0
            echo "Warning: nothing to delete for '$target'" >&2
            return 1
        end
        set -l save_args $dirs_file
        for i in (seq (count $idxs))
            set -a save_args $idxs[$i] "$names[$i]" $paths[$i]
        end
        __wallpaper_loop_save $save_args
        echo "Removed $target"
    else if test "$argv[1]" = "stop"
        $wp_daemon stop
    else
        set arg $argv[1]
        set instant "false"
        if test (count $argv) -ge 2 ; and test "$argv[2]" = "f"
            set instant "true"
        end
        set images_dir ""
        set -l used_index ""
        set -l used_name ""

        if not test "$arg" = "f"
            set -l entries (__wallpaper_loop_load $dirs_file)
            for row in $entries
                set -l fields (string split \t $row)
                set -l p (string join \t $fields[3..])
                if test "$fields[2]" = "$arg" ; or test "$fields[1]" = "$arg" ; or test "$p" = "$arg"
                    set used_index $fields[1]
                    set used_name $fields[2]
                    set images_dir $p
                    break
                end
            end
            if test -z "$images_dir"
                if string match -qr '^[0-9]+$' $arg
                    echo "Warning: invalid index $arg" >&2
                    echo "Use 'wallpaper_loop list' to see the stack"
                    return 1
                else if test -d $arg
                    set images_dir $arg
                else
                    echo "Warning: unknown name or path: $arg" >&2
                    echo "Use 'wallpaper_loop list' to see the stack"
                    return 1
                end
            end
        end

        if test -n "$images_dir"
            if not test -d "$images_dir"
                echo "Warning: not a directory: $images_dir" >&2
                return 1
            end
            set -l n (__wallpaper_loop_image_count $images_dir)
            if test $n -eq 0
                if test -n "$used_index"
                    echo "Warning: index $used_index has no images: $images_dir" >&2
                else
                    echo "Warning: no images in $images_dir" >&2
                end
                return 1
            end
            $wp_daemon set $images_dir
            $wp_daemon start $images_dir
            if test "$instant" = "true"
                $wp_daemon show $images_dir
            end
        else
            echo "Warning: unknown name or path: $arg" >&2
            echo "Use 'wallpaper_loop list' to see the stack"
            return 1
        end
    end
end
# LLM PROMPT [end]
