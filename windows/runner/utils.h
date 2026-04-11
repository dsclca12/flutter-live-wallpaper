#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// Creates a console for the process, and redirects stdout and stderr to
// it for both the runner and the Flutter library.
void CreateAndAttachConsole();

// Redirects stdout and stderr to the currently attached console.
void AttachToExistingConsoleStreams();

// Takes a null-terminated wchar_t* encoded in UTF-16 and returns a std::string
// encoded in UTF-8. Returns an empty std::string on failure.
std::string Utf8FromUtf16(const wchar_t* utf16_string);

// Gets the command line arguments passed in as a std::vector<std::string>,
// encoded in UTF-8. Returns an empty std::vector<std::string> on failure.
std::vector<std::string> GetCommandLineArguments();

// Writes a timestamped line to stdout and the debugger output stream.
void LogToConsole(const std::string& message);

// Returns the current log file path used by LogToConsole.
std::string GetLogFilePath();

#endif  // RUNNER_UTILS_H_
