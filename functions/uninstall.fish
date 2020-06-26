functions -e __f_on_event_postexec
functions -e $F_CMD

if test -n "$F_DATA"
    echo "To purge f's data, remove: $F_DATA" > /dev/stderr
end

set -e F_CMD
set -e F_DATA
set -e F_EXCLUDE
