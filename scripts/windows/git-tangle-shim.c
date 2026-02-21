#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <winver.h>
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

static int get_version_string(const wchar_t *exe_path, wchar_t *version, size_t cap) {
  DWORD dummy = 0;
  DWORD size = GetFileVersionInfoSizeW(exe_path, &dummy);
  if (size == 0) {
    return 0;
  }

  BYTE *buf = (BYTE *)malloc(size);
  if (!buf) {
    return 0;
  }

  if (!GetFileVersionInfoW(exe_path, 0, size, buf)) {
    free(buf);
    return 0;
  }

  wchar_t *value = NULL;
  UINT len = 0;
  if (VerQueryValueW(buf, L"\\StringFileInfo\\040904E4\\ProductVersion", (LPVOID *)&value, &len) && len > 1) {
    wcsncpy(version, value, cap);
    version[cap - 1] = L'\0';
    free(buf);
    return 1;
  }

  VS_FIXEDFILEINFO *ffi = NULL;
  if (VerQueryValueW(buf, L"\\", (LPVOID *)&ffi, &len) && len >= sizeof(VS_FIXEDFILEINFO)) {
    _snwprintf(
        version,
        cap,
        L"%u.%u.%u.%u",
        HIWORD(ffi->dwProductVersionMS),
        LOWORD(ffi->dwProductVersionMS),
        HIWORD(ffi->dwProductVersionLS),
        LOWORD(ffi->dwProductVersionLS));
    version[cap - 1] = L'\0';
    free(buf);
    return 1;
  }

  free(buf);
  return 0;
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

static int resolve_script_near_base(const wchar_t *base_dir, wchar_t *script_path, size_t cap) {
  wchar_t script_path_alt[MAX_PATH];

  path_join(script_path, cap, base_dir, L"bin\\git-tangle");
  path_join(script_path_alt, MAX_PATH, base_dir, L"git-tangle");

  if (!file_exists(script_path) && file_exists(script_path_alt)) {
    wcsncpy(script_path, script_path_alt, cap);
    script_path[cap - 1] = L'\0';
  }

  return file_exists(script_path);
}

static int resolve_script_from_winget_packages(wchar_t *script_path, size_t cap) {
  wchar_t local_app_data[MAX_PATH];
  if (GetEnvironmentVariableW(L"LOCALAPPDATA", local_app_data, MAX_PATH) == 0) {
    return 0;
  }

  wchar_t packages_root[MAX_PATH];
  path_join(packages_root, MAX_PATH, local_app_data, L"Microsoft\\WinGet\\Packages");

  wchar_t search_pattern[MAX_PATH];
  path_join(search_pattern, MAX_PATH, packages_root, L"taygunsavas.git-tangle*");

  WIN32_FIND_DATAW find_data;
  HANDLE find = FindFirstFileW(search_pattern, &find_data);
  if (find == INVALID_HANDLE_VALUE) {
    return 0;
  }

  int found = 0;
  FILETIME best_time = {0};
  wchar_t best_script[MAX_PATH] = {0};

  do {
    if (!(find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) {
      continue;
    }
    if (wcscmp(find_data.cFileName, L".") == 0 || wcscmp(find_data.cFileName, L"..") == 0) {
      continue;
    }

    wchar_t package_dir[MAX_PATH];
    wchar_t candidate_script[MAX_PATH];
    path_join(package_dir, MAX_PATH, packages_root, find_data.cFileName);
    path_join(candidate_script, MAX_PATH, package_dir, L"bin\\git-tangle");

    if (!file_exists(candidate_script)) {
      continue;
    }

    if (!found || CompareFileTime(&find_data.ftLastWriteTime, &best_time) > 0) {
      best_time = find_data.ftLastWriteTime;
      wcsncpy(best_script, candidate_script, MAX_PATH);
      best_script[MAX_PATH - 1] = L'\0';
      found = 1;
    }
  } while (FindNextFileW(find, &find_data));

  FindClose(find);

  if (!found) {
    return 0;
  }

  wcsncpy(script_path, best_script, cap);
  script_path[cap - 1] = L'\0';
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
  wchar_t bash_path[MAX_PATH];

  if (!GetModuleFileNameW(NULL, exe_path, MAX_PATH)) {
    fwprintf(stderr, L"[tangle] ERROR: cannot resolve executable path.\n");
    return 1;
  }

  if (argc >= 2 && (wcscmp(argv[1], L"--version") == 0 || wcscmp(argv[1], L"-v") == 0)) {
    wchar_t version[128];
    if (get_version_string(exe_path, version, sizeof(version) / sizeof(version[0]))) {
      wprintf(L"git-tangle %ls\n", version);
    } else {
      wprintf(L"git-tangle\n");
    }
    return 0;
  }

  wcsncpy(base_dir, exe_path, MAX_PATH);
  base_dir[MAX_PATH - 1] = L'\0';
  wchar_t *last_sep = wcsrchr(base_dir, L'\\');
  if (!last_sep) {
    fwprintf(stderr, L"[tangle] ERROR: invalid executable directory.\n");
    return 1;
  }
  *last_sep = L'\0';

  if (!resolve_script_near_base(base_dir, script_path, MAX_PATH) && !resolve_script_from_winget_packages(script_path, MAX_PATH)) {
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
