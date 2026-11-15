"""Run a program on a separate Windows desktop that is never displayed, and wait for it.

Why: a program that needs a real window and a real graphics driver (for example Godot drawing
screenshots) can then run without anything appearing on the user's screen, without taking
keyboard focus and without showing up on the taskbar. Windows shows only the windows of the
desktop that currently receives input; this script never switches to the desktop it creates.

What it does:
  1. creates a desktop with a random name in the current window station;
  2. starts the program suspended on that desktop, inside a job that is killed when this
     script exits, with stdout and stderr sent to a log file and stdin from NUL;
  3. while the program runs, checks several times a second that none of its processes owns a
     window on the user's desktop; if one ever does, the whole job is killed at once;
  4. kills the job on timeout;
  5. reports the exit code, the windows seen on the hidden desktop, and whether the user's
     foreground window was the same before and after.

It sends no keyboard or mouse input. It does not silence the program: pass the program its own
option for that (for Godot: --audio-driver Dummy). Windows only.

Usage:
  python run_hidden.py --log out.log --timeout 300 [--cwd DIR] -- program arg1 arg2 ...
Exit code: the program's exit code; 124 on timeout; 125 if a window leaked; 126 on set-up failure.

Example: draw the game's capture run (game/tests/capture_shift.gd) from the repository root.
Give the Godot GUI executable, not the "_console" wrapper, and absolute paths:
  python tools/run_hidden.py --log captures.log --timeout 540 --cwd <repository root> -- <Godot GUI exe>
      --audio-driver Dummy --fixed-fps 60 --path game --script res://tests/capture_shift.gd
      -- --out=<absolute folder for the frames>
Add "--attacks-only --less-blood" after the --out option for the attack scenes without the blood.

What such a run is: frames drawn by the real renderer, in a real window, on a desktop that is
never displayed, with the sound driver the program was given and (for capture_shift.gd) a
simulated microphone. Nobody watches it while it runs. It is not interactive testing, not
microphone testing and not a playtest; describe its frames as automated captures.

Reading the report:
  windows_leaked_to_user_desktop     must be []. Anything else means the run was killed.
  windows_seen_on_hidden_desktop     the program's own windows, for the record.
  user_foreground_window_unchanged   false only says the foreground window was a different one
                                     afterwards. A person switching windows during the run does
                                     that too, so on its own it is not a sign of a problem.
"""
import argparse
import ctypes
import ctypes.wintypes as wt
import json
import os
import subprocess
import sys
import time
import uuid

if os.name != "nt":
    sys.exit("run_hidden.py only works on Windows")

user32 = ctypes.WinDLL("user32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)

HANDLE = ctypes.c_void_p
GENERIC_READ = 0x80000000
GENERIC_WRITE = 0x40000000
GENERIC_ALL = 0x10000000
FILE_SHARE_READ = 1
FILE_SHARE_WRITE = 2
CREATE_ALWAYS = 2
OPEN_EXISTING = 3
FILE_ATTRIBUTE_NORMAL = 0x80
INVALID_HANDLE_VALUE = ctypes.c_void_p(-1).value
STARTF_USESTDHANDLES = 0x100
CREATE_SUSPENDED = 0x4
CREATE_NO_WINDOW = 0x08000000
CREATE_UNICODE_ENVIRONMENT = 0x400
WAIT_TIMEOUT = 0x102
JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x2000
JobObjectExtendedLimitInformation = 9
JobObjectBasicProcessIdList = 3
UOI_NAME = 2


class SECURITY_ATTRIBUTES(ctypes.Structure):
    _fields_ = [("nLength", wt.DWORD), ("lpSecurityDescriptor", ctypes.c_void_p), ("bInheritHandle", wt.BOOL)]


class STARTUPINFOW(ctypes.Structure):
    _fields_ = [
        ("cb", wt.DWORD), ("lpReserved", wt.LPWSTR), ("lpDesktop", wt.LPWSTR), ("lpTitle", wt.LPWSTR),
        ("dwX", wt.DWORD), ("dwY", wt.DWORD), ("dwXSize", wt.DWORD), ("dwYSize", wt.DWORD),
        ("dwXCountChars", wt.DWORD), ("dwYCountChars", wt.DWORD), ("dwFillAttribute", wt.DWORD),
        ("dwFlags", wt.DWORD), ("wShowWindow", wt.WORD), ("cbReserved2", wt.WORD),
        ("lpReserved2", ctypes.c_void_p), ("hStdInput", HANDLE), ("hStdOutput", HANDLE), ("hStdError", HANDLE),
    ]


class PROCESS_INFORMATION(ctypes.Structure):
    _fields_ = [("hProcess", HANDLE), ("hThread", HANDLE), ("dwProcessId", wt.DWORD), ("dwThreadId", wt.DWORD)]


class IO_COUNTERS(ctypes.Structure):
    _fields_ = [(name, ctypes.c_ulonglong) for name in (
        "ReadOperationCount", "WriteOperationCount", "OtherOperationCount",
        "ReadTransferCount", "WriteTransferCount", "OtherTransferCount")]


class JOBOBJECT_BASIC_LIMIT_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("PerProcessUserTimeLimit", ctypes.c_longlong), ("PerJobUserTimeLimit", ctypes.c_longlong),
        ("LimitFlags", wt.DWORD), ("MinimumWorkingSetSize", ctypes.c_size_t),
        ("MaximumWorkingSetSize", ctypes.c_size_t), ("ActiveProcessLimit", wt.DWORD),
        ("Affinity", ctypes.c_size_t), ("PriorityClass", wt.DWORD), ("SchedulingClass", wt.DWORD),
    ]


class JOBOBJECT_EXTENDED_LIMIT_INFORMATION(ctypes.Structure):
    _fields_ = [
        ("BasicLimitInformation", JOBOBJECT_BASIC_LIMIT_INFORMATION), ("IoInfo", IO_COUNTERS),
        ("ProcessMemoryLimit", ctypes.c_size_t), ("JobMemoryLimit", ctypes.c_size_t),
        ("PeakProcessMemoryUsed", ctypes.c_size_t), ("PeakJobMemoryUsed", ctypes.c_size_t),
    ]


class JOBOBJECT_BASIC_PROCESS_ID_LIST(ctypes.Structure):
    _fields_ = [("NumberOfAssignedProcesses", wt.DWORD), ("NumberOfProcessIdsInList", wt.DWORD),
                ("ProcessIdList", ctypes.c_size_t * 64)]


WNDENUMPROC = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)

user32.CreateDesktopW.restype = HANDLE
user32.CreateDesktopW.argtypes = [wt.LPCWSTR, wt.LPCWSTR, ctypes.c_void_p, wt.DWORD, wt.DWORD, ctypes.c_void_p]
user32.CloseDesktop.argtypes = [HANDLE]
user32.EnumWindows.argtypes = [WNDENUMPROC, wt.LPARAM]
user32.EnumDesktopWindows.argtypes = [HANDLE, WNDENUMPROC, wt.LPARAM]
user32.GetWindowThreadProcessId.argtypes = [wt.HWND, ctypes.POINTER(wt.DWORD)]
user32.GetWindowThreadProcessId.restype = wt.DWORD
user32.GetWindowTextW.argtypes = [wt.HWND, wt.LPWSTR, ctypes.c_int]
user32.IsWindowVisible.argtypes = [wt.HWND]
user32.GetForegroundWindow.restype = wt.HWND
user32.GetThreadDesktop.restype = HANDLE
user32.GetThreadDesktop.argtypes = [wt.DWORD]
user32.GetUserObjectInformationW.argtypes = [HANDLE, ctypes.c_int, ctypes.c_void_p, wt.DWORD, ctypes.POINTER(wt.DWORD)]
kernel32.GetCurrentThreadId.restype = wt.DWORD
kernel32.CreateFileW.restype = HANDLE
kernel32.CreateFileW.argtypes = [wt.LPCWSTR, wt.DWORD, wt.DWORD, ctypes.c_void_p, wt.DWORD, wt.DWORD, HANDLE]
kernel32.CloseHandle.argtypes = [HANDLE]
kernel32.CreateProcessW.argtypes = [wt.LPCWSTR, wt.LPWSTR, ctypes.c_void_p, ctypes.c_void_p, wt.BOOL, wt.DWORD,
                                    ctypes.c_void_p, wt.LPCWSTR, ctypes.POINTER(STARTUPINFOW),
                                    ctypes.POINTER(PROCESS_INFORMATION)]
kernel32.CreateJobObjectW.restype = HANDLE
kernel32.CreateJobObjectW.argtypes = [ctypes.c_void_p, wt.LPCWSTR]
kernel32.SetInformationJobObject.argtypes = [HANDLE, ctypes.c_int, ctypes.c_void_p, wt.DWORD]
kernel32.QueryInformationJobObject.argtypes = [HANDLE, ctypes.c_int, ctypes.c_void_p, wt.DWORD, ctypes.POINTER(wt.DWORD)]
kernel32.AssignProcessToJobObject.argtypes = [HANDLE, HANDLE]
kernel32.TerminateJobObject.argtypes = [HANDLE, wt.UINT]
kernel32.ResumeThread.argtypes = [HANDLE]
kernel32.TerminateProcess.argtypes = [HANDLE, wt.UINT]
kernel32.WaitForSingleObject.argtypes = [HANDLE, wt.DWORD]
kernel32.WaitForSingleObject.restype = wt.DWORD
kernel32.GetExitCodeProcess.argtypes = [HANDLE, ctypes.POINTER(wt.DWORD)]


def fail(message):
    print(json.dumps({"ok": False, "error": message, "winerror": ctypes.get_last_error()}))
    sys.exit(126)


def desktop_name(handle):
    buffer = ctypes.create_unicode_buffer(256)
    needed = wt.DWORD(0)
    if not user32.GetUserObjectInformationW(handle, UOI_NAME, buffer, ctypes.sizeof(buffer), ctypes.byref(needed)):
        return ""
    return buffer.value


def windows_of(enumerate_call):
    """Return [(hwnd, pid, visible, title)] for every top-level window the call enumerates."""
    found = []

    def visit(hwnd, _lparam):
        pid = wt.DWORD(0)
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        title = ctypes.create_unicode_buffer(200)
        user32.GetWindowTextW(hwnd, title, 200)
        found.append((int(hwnd), int(pid.value), bool(user32.IsWindowVisible(hwnd)), title.value))
        return True

    callback = WNDENUMPROC(visit)
    enumerate_call(callback)
    return found


def job_pids(job):
    info = JOBOBJECT_BASIC_PROCESS_ID_LIST()
    if not kernel32.QueryInformationJobObject(job, JobObjectBasicProcessIdList, ctypes.byref(info),
                                              ctypes.sizeof(info), None):
        return set()
    return {int(info.ProcessIdList[i]) for i in range(min(info.NumberOfProcessIdsInList, 64))}


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--log", required=True, help="file that receives the program's stdout and stderr")
    parser.add_argument("--timeout", type=float, default=300.0, help="seconds before the program is killed")
    parser.add_argument("--cwd", default=None, help="working directory for the program")
    parser.add_argument("command", nargs=argparse.REMAINDER, help="-- program and its arguments")
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        fail("no program given")

    own_desktop = desktop_name(user32.GetThreadDesktop(kernel32.GetCurrentThreadId()))
    name = "btc-hidden-" + uuid.uuid4().hex[:12]
    desktop = user32.CreateDesktopW(name, None, None, 0, GENERIC_ALL, None)
    if not desktop:
        fail("CreateDesktopW failed")
    if desktop_name(desktop) != name or name == own_desktop:
        user32.CloseDesktop(desktop)
        fail("the new desktop is not the one that was asked for")

    inherit = SECURITY_ATTRIBUTES(ctypes.sizeof(SECURITY_ATTRIBUTES), None, True)
    log = kernel32.CreateFileW(os.path.abspath(args.log), GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE,
                               ctypes.byref(inherit), CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, None)
    nul = kernel32.CreateFileW("NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                               ctypes.byref(inherit), OPEN_EXISTING, 0, None)
    if log in (None, INVALID_HANDLE_VALUE) or nul in (None, INVALID_HANDLE_VALUE):
        user32.CloseDesktop(desktop)
        fail("could not open the log file or NUL")

    job = kernel32.CreateJobObjectW(None, None)
    limits = JOBOBJECT_EXTENDED_LIMIT_INFORMATION()
    limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
    if not job or not kernel32.SetInformationJobObject(job, JobObjectExtendedLimitInformation,
                                                       ctypes.byref(limits), ctypes.sizeof(limits)):
        user32.CloseDesktop(desktop)
        fail("could not create the job")

    startup = STARTUPINFOW()
    startup.cb = ctypes.sizeof(STARTUPINFOW)
    startup.lpDesktop = "WinSta0\\" + name
    startup.dwFlags = STARTF_USESTDHANDLES
    startup.hStdInput = nul
    startup.hStdOutput = log
    startup.hStdError = log
    process = PROCESS_INFORMATION()
    command_line = ctypes.create_unicode_buffer(subprocess.list2cmdline(command))
    foreground_before = int(user32.GetForegroundWindow() or 0)
    created = kernel32.CreateProcessW(None, command_line, None, None, True,
                                      CREATE_SUSPENDED | CREATE_NO_WINDOW | CREATE_UNICODE_ENVIRONMENT,
                                      None, args.cwd, ctypes.byref(startup), ctypes.byref(process))
    if not created:
        error = ctypes.get_last_error()
        kernel32.CloseHandle(job)
        user32.CloseDesktop(desktop)
        print(json.dumps({"ok": False, "error": "CreateProcessW failed", "winerror": error}))
        sys.exit(126)
    if not kernel32.AssignProcessToJobObject(job, process.hProcess):
        kernel32.TerminateProcess(process.hProcess, 126)
        kernel32.CloseHandle(job)
        user32.CloseDesktop(desktop)
        fail("could not put the program into the job")
    kernel32.ResumeThread(process.hThread)

    started = time.monotonic()
    outcome = "exited"
    leaked = []
    hidden_seen = {}
    while kernel32.WaitForSingleObject(process.hProcess, 120) == WAIT_TIMEOUT:
        watched = job_pids(job) | {int(process.dwProcessId)}
        mine = windows_of(lambda cb: user32.EnumWindows(cb, 0))
        leaked = [w for w in mine if w[1] in watched]
        if leaked:
            kernel32.TerminateJobObject(job, 125)
            outcome = "killed: a window appeared on the user's desktop"
            break
        for hwnd, pid, visible, title in windows_of(lambda cb: user32.EnumDesktopWindows(desktop, cb, 0)):
            if title:
                hidden_seen[title] = {"pid": pid, "visible": visible}
        if time.monotonic() - started > args.timeout:
            kernel32.TerminateJobObject(job, 124)
            outcome = "killed: timeout"
            break
    kernel32.WaitForSingleObject(process.hProcess, 5000)
    code = wt.DWORD(0)
    kernel32.GetExitCodeProcess(process.hProcess, ctypes.byref(code))
    foreground_after = int(user32.GetForegroundWindow() or 0)
    seconds = round(time.monotonic() - started, 1)

    kernel32.CloseHandle(process.hThread)
    kernel32.CloseHandle(process.hProcess)
    kernel32.CloseHandle(job)          # kills anything the program left behind
    kernel32.CloseHandle(log)
    kernel32.CloseHandle(nul)
    user32.CloseDesktop(desktop)

    exit_code = int(ctypes.c_int32(code.value).value)
    print(json.dumps({
        "ok": outcome == "exited",
        "outcome": outcome,
        "exit_code": exit_code,
        "seconds": seconds,
        "hidden_desktop": name,
        "user_desktop": own_desktop,
        "windows_seen_on_hidden_desktop": hidden_seen,
        "windows_leaked_to_user_desktop": [{"pid": w[1], "visible": w[2], "title": w[3]} for w in leaked],
        "user_foreground_window_unchanged": foreground_before == foreground_after,
    }, indent=1))
    if outcome.startswith("killed: timeout"):
        sys.exit(124)
    if leaked:
        sys.exit(125)
    sys.exit(exit_code & 0xFF if exit_code >= 0 else 1)


if __name__ == "__main__":
    main()
