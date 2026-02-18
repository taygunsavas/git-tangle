#include <windows.h>
#include <shellapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

static int file_exists(const wchar_t *path) {
  DWORD attrs = GetFileAttributesW(path);
  return attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_DIRECTORY);
}

static void path_join(wchar_t *out, size_t cap, const wchar_t *a, const wchar_t *b) {
  _snwprintf(out, cap, L"%ls\\%ls", a, b);
  out[cap - 1] = L'\0';
}

static void path_to_unix_slashes(wchar_t *path) {
  for (wchar_t *p = path; *p; ++p) {
    if (*p == L'\\') {
      *p = L'/';
    }
  }
}

static int append_quoted(wchar_t *dst, size_t cap, size_t *len, const wchar_t *arg) {
  if (*len + 3 >= cap) {
    return 0;
  }
  if (*len > 0) {
    dst[(*len)++] = L' ';
  }
  dst[(*len)++] = L'"';
  for (const wchar_t *p = arg; *p; ++p) {
    if (*p == L'"') {
      if (*len + 2 >= cap) {
        return 0;
      }
      dst[(*len)++] = L'\\';
      dst[(*len)++] = L'"';
    } else {
      if (*len + 1 >= cap) {
        return 0;
      }
      dst[(*len)++] = *p;
    }
  }
  if (*len + 2 >= cap) {
    return 0;
  }
  dst[(*len)++] = L'"';
  dst[*len] = L'\0';
  return 1;
}

static int resolve_bash(wchar_t *bash_path, size_t cap) {
  const wchar_t *env_vars[] = {L"ProgramFiles", L"ProgramFiles(x86)"};
  const wchar_t *suffixes[] = {L"Git\\bin\\bash.exe", L"Git\\usr\\bin\\bash.exe"};
  wchar_t root[MAX_PATH];
  wchar_t candidate[MAX_PATH];

  for (size_t i = 0; i < sizeof(env_vars) / sizeof(env_vars[0]); ++i) {
    if (GetEnvironmentVariableW(env_vars[i], root, MAX_PATH) == 0) {
      continue;
    }
    for (size_t j = 0; j < sizeof(suffixes) / sizeof(suffixes[0]); ++j) {
      path_join(candidate, MAX_PATH, root, suffixes[j]);
      if (file_exists(candidate)) {
        wcsncpy(bash_path, candidate, cap);
        bash_path[cap - 1] = L'\0';
        return 1;
      }
    }
  }

  if (SearchPathW(NULL, L"bash.exe", NULL, (DWORD)cap, bash_path, NULL) > 0) {
    return 1;
  }

  return 0;
}

int wmain(int argc, wchar_t **argv) {
  wchar_t exe_path[MAX_PATH];
  wchar_t base_dir[MAX_PATH];
  wchar_t script_path[MAX_PATH];
  wchar_t script_path_alt[MAX_PATH];
  wchar_t bash_path[MAX_PATH];

  if (!GetModuleFileNameW(NULL, exe_path, MAX_PATH)) {
    fwprintf(stderr, L"[tangle] ERROR: cannot resolve executable path.\n");
    return 1;
  }

  wcsncpy(base_dir, exe_path, MAX_PATH);
  base_dir[MAX_PATH - 1] = L'\0';
  wchar_t *last_sep = wcsrchr(base_dir, L'\\');
  if (!last_sep) {
    fwprintf(stderr, L"[tangle] ERROR: invalid executable directory.\n");
    return 1;
  }
  *last_sep = L'\0';

  path_join(script_path, MAX_PATH, base_dir, L"bin\\git-tangle");
  path_join(script_path_alt, MAX_PATH, base_dir, L"git-tangle");

  if (!file_exists(script_path) && file_exists(script_path_alt)) {
    wcsncpy(script_path, script_path_alt, MAX_PATH);
    script_path[MAX_PATH - 1] = L'\0';
  }

  if (!file_exists(script_path)) {
    fwprintf(stderr, L"[tangle] ERROR: could not locate git-tangle bash entrypoint.\n");
    return 1;
  }

  if (!resolve_bash(bash_path, MAX_PATH)) {
    fwprintf(stderr, L"[tangle] ERROR: Git Bash was not found. Install Git for Windows first.\n");
    return 1;
  }

  path_to_unix_slashes(script_path);

  size_t cmd_cap = 16384;
  wchar_t *cmdline = (wchar_t *)calloc(cmd_cap, sizeof(wchar_t));
  if (!cmdline) {
    fwprintf(stderr, L"[tangle] ERROR: out of memory.\n");
    return 1;
  }

  size_t cmd_len = 0;
  if (!append_quoted(cmdline, cmd_cap, &cmd_len, bash_path) ||
      !append_quoted(cmdline, cmd_cap, &cmd_len, script_path)) {
    fwprintf(stderr, L"[tangle] ERROR: failed to build command line.\n");
    free(cmdline);
    return 1;
  }

  for (int i = 1; i < argc; ++i) {
    if (!append_quoted(cmdline, cmd_cap, &cmd_len, argv[i])) {
      fwprintf(stderr, L"[tangle] ERROR: argument list is too long.\n");
      free(cmdline);
      return 1;
    }
  }

  STARTUPINFOW si;
  PROCESS_INFORMATION pi;
  ZeroMemory(&si, sizeof(si));
  ZeroMemory(&pi, sizeof(pi));
  si.cb = sizeof(si);

  if (!CreateProcessW(NULL, cmdline, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
    fwprintf(stderr, L"[tangle] ERROR: failed to launch Git Bash (error %lu).\n", GetLastError());
    free(cmdline);
    return 1;
  }

  WaitForSingleObject(pi.hProcess, INFINITE);
  DWORD code = 1;
  GetExitCodeProcess(pi.hProcess, &code);
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);
  free(cmdline);
  return (int)code;
}
