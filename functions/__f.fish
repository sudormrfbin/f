function __f -d "Open recent files entered on command line"

    function __print_help
        echo "
            Usage: $F_CMD [-kdcelprth] [-w cmd] regex1 regex2 ..

                    -k --pick      Launch fzf for selection and then open with \$EDITOR
                    -w --with cmd  Open the file with command cmd rather than \$EDITOR
                    -d --cd        cd to the file directory after selection
                    -c --clean     Remove files that no longer exist from $F_DATA
                    -o --echo      Print match and return
                    -l --list      List matches and scores
                    -p --purge     Delete all entries from $F_DATA
                    -r --rank      Search by rank
                    -t --recent    Search by recency
                    -h --help      Print this help
        " | string replace -r '^ {12}' ''  # remove unnecessary indent
    end

    set -l options "h/help" "c/clean" "o/echo" "l/list" "p/purge" "r/rank" "t/recent" "k/pick" "w/with=" "d/cd"

    argparse -n $F_CMD $options -- $argv
    or return

    if set -q _flag_help
        __print_help
        return 0
    else if set -q _flag_clean
        __f_clean
        echo "$F_DATA cleaned!" 
        return 0
    else if set -q _flag_purge
        echo > $F_DATA
        echo "$F_DATA purged!" 
        return 0
    end

    set -l typ

    if set -q _flag_rank
        set typ "rank"
    else if set -q _flag_recent
        set typ "recent"
    end

    set -l f_script '
        function frecent(rank, time) {
            dx = t-time
            if( dx < 3600 ) return rank*4
            if( dx < 86400 ) return rank*2
            if( dx < 604800 ) return rank/2
            return rank/4
        }

        function output(matches, best_match, common) {
            # list or return the desired file
            if( list ) {
                cmd = "sort -nr"
                for( x in matches ) {
                    if( matches[x] ) {
                        printf "%-10s %s\n", matches[x], x | cmd
                    }
                }
                if( common ) {
                    printf "%-10s %s\n", "common:", common > "/dev/stderr"
                }
            } else {
                if( common ) best_match = common
                print best_match
            }
        }

        function common(matches) {
            # find the common root of a list of matches, if it exists
            for( x in matches ) {
                if( matches[x] && (!short || length(x) < length(short)) ) {
                    short = x
                }
            }
            if( short == "/" ) return
            for( x in matches ) if( matches[x] && index(x, short) != 1 ) {
                    return
                }
            return short
        }

        BEGIN {
            hi_rank = ihi_rank = -9999999999
        }
        {
            if( typ == "rank" ) {
                rank = $2
            } else if( typ == "recent" ) {
                rank = $3 - t
            } else rank = frecent($2, $3)
            if( $1 ~ q ) {
                matches[$1] = rank
            } else if( tolower($1) ~ tolower(q) ) imatches[$1] = rank
            if( matches[$1] && matches[$1] > hi_rank ) {
                best_match = $1
                hi_rank = matches[$1]
            } else if( imatches[$1] && imatches[$1] > ihi_rank ) {
                ibest_match = $1
                ihi_rank = imatches[$1]
            }
        }

        END {
        # prefer case sensitive
            if( best_match ) {
                output(matches, best_match, common(matches))
            } else if( ibest_match ) {
                output(imatches, ibest_match, common(imatches))
            }
        }
    '

    set -l qs
    for arg in $argv
        set -l escaped $arg
        set escaped (string escape --style=regex $escaped)
        # Need to escape twice, see https://www.math.utah.edu/docs/info/gawk_5.html#SEC32
        set escaped (string replace --all \\ \\\\ $escaped)
        set qs $qs $escaped
    end
    set -l q (string join '.*' $qs)

    if set -q _flag_list
        # Handle list separately as it can print common path information to stderr
        # which cannot be captured from a subcommand.
        command awk -v t=(date +%s) -v list="list" -v typ="$typ" -v q="$q" -F "|" $f_script "$F_DATA"
    else
        set -l target

        if set -q _flag_pick
            set target (
                command awk -v t=(date +%s) -v list="list" -v typ="$typ" -v q=".*" -F "|" $f_script "$F_DATA" |
                string replace -r '^.{11}' '' |
                fzf
            )
        else
            set target (command awk -v t=(date +%s) -v typ="$typ" -v q="$q" -F "|" $f_script "$F_DATA")
        end

        if test "$status" -gt 0
            return
        end

        if test -z "$target"
            echo "$argv did not match any results"
            return 1
        end

        if set -q _flag_cd
            # cd into directory of file
            pushd (string split -rm 1 '/' $target)[1] 2> /dev/null
            if test $status -gt 0
                echo "Parent directory of $target does not exist"
                return 1
            end
        end

        __f_add $target

        if set -q _flag_echo
            printf "%s\n" "$target"
            return 0
        else
            set -l opencmd

            if set -q _flag_with
                set opencmd $_flag_with
            else if set -q VISUAL
                set opencmd $VISUAL
            else if set -q EDITOR
                set opencmd $EDITOR
            else
                echo "\$EDITOR not set; cannot open file" > /dev/stderr
                return 1
            end

            # `$opencmd $target` won't work if $opencmd is quoted; use source instead
            printf '%s ' $opencmd (string escape $target) | source
        end
    end
end
