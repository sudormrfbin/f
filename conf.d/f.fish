if test -z "$F_DATA"
    if test -n "$XDG_DATA_HOME"
        set -U F_DATA_DIR "$XDG_DATA_HOME/f"
    else 
        set -U F_DATA_DIR "$HOME/.local/share/f"
    end
    set -U F_DATA "$F_DATA_DIR/data"
end

if test ! -e "$F_DATA"
    if test ! -e "$F_DATA_DIR"
        mkdir -p -m 700 "$F_DATA_DIR"  
    end
    touch "$F_DATA"
end

if test -z "$F_CMD"
    set -U F_CMD "f"
end

function $F_CMD -d "jump around"
    __f $argv
end

function __f_on_event_postexec --on-event fish_postexec
    set -l paths (__f_extract_paths $argv)
    for path in $paths
        __f_add $path
    end
end

# Setup completions once first
__f_complete
