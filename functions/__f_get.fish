function __f_get
    cat ~/.cache/f | sort | uniq | tee /tmp/f | fzf
    mv /tmp/f ~/.cache/f
end
