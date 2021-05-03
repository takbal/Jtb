const HANDLE = Ptr{Cvoid}
const DWORD = UInt32
const BOOL = Cint

"""
    is_pid_alive(pid::Int32)::Bool

Returns if the passed pid is alive. Works on Unix and Windows.
"""
function is_pid_alive(pid::Integer)::Bool

    # an Absolutely Ridiculous Difference

    if !Sys.iswindows()

        return ccall(:kill, Int32, (Int32, Int32), pid, 0) == 0

    else

        # translation of the following C code:

        # int pid_is_running(DWORD pid)
        # {
        #     HANDLE hProcess;
        #     DWORD exitCode;
        #
        #     //Special case for PID 0 System Idle Process
        #     if (pid == 0) {
        #         return 1;
        #     }
        #
        #     //skip testing bogus PIDs
        #     if (pid < 0) {
        #         return 0;
        #     }
        #
        #     hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
        #     if (NULL == hProcess) {
        #         //invalid parameter means PID isn't in the system
        #         if (GetLastError() == ERROR_INVALID_PARAMETER) {
        #             return 0;
        #         }
        #
        #         //some other error with OpenProcess
        #         return -1;
        #     }
        #
        #     if (GetExitCodeProcess(hProcess, &exitCode)) {
        #         CloseHandle(hProcess);
        #         return (exitCode == STILL_ACTIVE);
        #     }
        #
        #     //error in GetExitCodeProcess()
        #     CloseHandle(hProcess);
        #     return -1;
        # }

        PROCESS_QUERY_INFORMATION = 0x0400
        ERROR_INVALID_PARAMETER = 0x57
        STILL_ACTIVE = 259

        function CloseHandle(handle)
            Base.windowserror(:CloseHandle, 0 == ccall(:CloseHandle, stdcall,
                                Cint, (HANDLE,), handle))
            nothing
        end

        function OpenProcess(id::Integer, rights = PROCESS_QUERY_INFORMATION)
            proc = ccall((:OpenProcess, "kernel32"), stdcall, HANDLE, (DWORD, BOOL, DWORD),
                            rights, false, id)
            Base.windowserror(:OpenProcess, proc == C_NULL)
            proc
        end

        if pid == 0
            return true
        end

        if pid < 0
            return false
        end

        hProcess = try OpenProcess(pid)
        catch err
            if err isa SystemError && err.extrainfo.errnum == ERROR_INVALID_PARAMETER
                return false
            end
            rethrow()
        end

        exitCode = Ref{DWORD}()

        if ccall(:GetExitCodeProcess, stdcall, BOOL, (HANDLE, Ref{DWORD}), hProcess, exitCode) != 0
            CloseHandle(hProcess)
            return exitCode[] == STILL_ACTIVE
        else
            CloseHandle(hProcess)
            throw( AssertionError("GetExitCodeProcess() failed") )
        end

    end
end
