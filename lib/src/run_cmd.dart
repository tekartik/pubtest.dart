import 'package:process_run/shell_run.dart';
import 'package:tekartik_io_utils/io_utils_import.dart';

/// Verbose run of command
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

  Future<ProcessResult> doRunCmd(ProcessCmd cmd, {bool? verbose}) async {
    return await Shell(
      workingDirectory: cmd.workingDirectory,
      verbose: true,
    ).runExecutableArguments(cmd.executable, cmd.arguments);
  }

  if (dryRun == true) {
    writeWorkingDirectory();
    stdout.writeln('\$ $cmd');
    return null;
  }
  ProcessResult result;
  if (oneByOne == true) {
    writeWorkingDirectory();

    result = await doRunCmd(cmd, verbose: verbose);
    if (result.exitCode != 0) {
      throw Exception('error $cmd exitCode: ${result.exitCode}');
    }
  } else {
    result = await doRunCmd(cmd, verbose: verbose);
    writeWorkingDirectory();
    stdout.writeln('\$ $cmd');
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      throw Exception('error $cmd exitCode: ${result.exitCode}');
    }
  }
  return result;
}
