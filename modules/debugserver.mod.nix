{
  flake.darwinModules.debugserver = {
    # https://sourcegraph.com/github.com/llvm/llvm-project@70906f0514826b5e64bd9354210ae836740c2053/-/blob/lldb/source/Plugins/Process/gdb-remote/GDBRemoteCommunication.cpp?L883
    environment.variables.LLDB_DEBUGSERVER_PATH = "/Library/Developer/CommandLineTools/Library/PrivateFrameworks/LLDB.framework/Versions/A/Resources/debugserver";
  };
}
