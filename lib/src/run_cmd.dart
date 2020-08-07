import 'package:process_run/cmd_run.dart' hide runCmd;
import 'package:process_run/cmd_run.dart' as cmd_run;
import 'package:tekartik_io_utils/io_utils_import.dart';

/// Verbose run of command
Future<ProcessResult> runCmd(ProcessCmd cmd,
    {bool dryRun, bool oneByOne, bool verbose}) async {
  void _writeWorkingDirectory() {
    if (cmd.workingDirectory != '.' && cmd.workingDirectory != null) {
      stdout.writeln('[${cmd.workingDirectory}]');
    }
  }

  if (dryRun == true) {
    _writeWorkingDirectory();
    stdout.writeln('\$ $cmd');
    return null;
  }
  ProcessResult result;
  if (oneByOne == true) {
    _writeWorkingDirectory();
    result = await cmd_run.runCmd(cmd, verbose: verbose);
    if (result.exitCode != 0) {
      throw Exception('error $cmd exitCode: ${result.exitCode}');
    }
  } else {
    result = await cmd_run.runCmd(cmd, verbose: verbose);
    _writeWorkingDirectory();
    stdout.writeln('\$ $cmd');
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      throw Exception('error $cmd exitCode: ${result.exitCode}');
    }
  }
  return result;
}