{
  environment.shellAliases = {
    la  = "ls --all";
    ll  = "ls --long";
    lla = "ls --long --all";
    sl  = "ls";

    cp = "cp --recursive --verbose --progress";
    mk = "mkdir";
    mv = "mv --verbose";
    rm = "rm --recursive --verbose";

    pstree = "pstree -g 3";
    tree   = "eza --tree --git-ignore --group-directories-first";
  };
}
