import 'package:process_run/shell_run.dart';
import 'package:tekartik_io_utils/io_utils_import.dart';

/// Run a command, its output is printed once.
///
/// With [oneByOne] or [verbose] the output is streamed while the command runs,
/// otherwise it is printed when the command is done (convenient when several
/// packages are handled at the same time).
///
/// Throws an exception if the exit code is not 0, after printing the output.
Future<ProcessResult?> runCmd(
  ProcessCmd cmd, {
  bool? dryRun,
  bool? oneByOne,
  bool? verbose,
}) async {
  void writeWorkingDirectory() {
    if (cmd.workingDirectory != '.' && cmd.workingDirectory != null) {
      stdout.writeln('[${cmd.workingDirectory}]');
    }
  }

  if (dryRun == true) {
    writeWorkingDirectory();
    stdout.writeln('\$ $cmd');
    return null;
  }
  var stream = (oneByOne ?? false) || (verbose ?? false);
  ProcessResult result;
  if (stream) {
    writeWorkingDirectory();
    result = await Shell(
      workingDirectory: cmd.workingDirectory,
      throwOnError: false,
    ).runExecutableArguments(cmd.executable, cmd.arguments);
  } else {
    result = await Shell(
      workingDirectory: cmd.workingDirectory,
      throwOnError: false,
      verbose: false,
    ).runExecutableArguments(cmd.executable, cmd.arguments);
    writeWorkingDirectory();
    stdout.writeln('\$ $cmd');
    stdout.write(result.stdout);
    stderr.write(result.stderr);
  }
  if (result.exitCode != 0) {
    throw Exception('error $cmd exitCode: ${result.exitCode}');
  }
  return result;
}
