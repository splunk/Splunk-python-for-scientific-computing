from exec_anaconda import exec_anaconda_or_die
exec_anaconda_or_die()

import os
import sys
import time

script_dir = os.path.dirname(__file__)
sys.path.insert(0, os.path.join(script_dir, "..", "lib"))
from splunklib.searchcommands import dispatch, GeneratingCommand, Configuration

import psutil


def get_psc_process_count():
    # get number of PSC process
    psc_process_count = 0
    for proc in psutil.process_iter():
        try:
            # Get process name & pid from process object.
            processID = proc.cmdline()
            if len(processID) >= 1 and 'Splunk_SA_Scientific_Python_linux_x86_64' in processID[0] and 'pscmanage.py' not in processID[1]:
                psc_process_count += 1
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            pass
    return psc_process_count


def get_dir_content(target):
    prefix=target+'/'
    dir_content = []
    dirs_tmp = []
    files_tmp = []
    for root, dirs, files in os.walk(target, followlinks=False):
        for name in dirs:
            dirs_tmp.append(pstrip(os.path.join(root, name), prefix))
        for name in files:
            if name != 'build.manifest':
                files_tmp.append(pstrip(os.path.join(root, name), prefix))
    dirs_tmp.reverse()
    dir_content = files_tmp + dirs_tmp
    return dir_content


def pstrip(line, prefix):
    # strip beginning of the line with prefix
    # does not strip if prefix doesn't exist
    result = line
    if line.startswith(prefix):
        result = line[len(prefix):]
    return result.strip()


@Configuration()
class PSCManage(GeneratingCommand):

    def generate(self):
        if len(self.fieldnames) < 0:
            self.write_error("Please specify an option, available options: cleanup, disable, enable")
        else:
            manage_option = self.fieldnames[0]
            if manage_option == 'cleanup':
                print('cleanup', file=sys.stderr)
                build_dir = os.path.join(script_dir, 'linux_x86_64')
                with open(os.path.join(build_dir, 'build.manifest')) as f:
                    print(f"open file", file=sys.stderr)
                    files_in_manifest = list(map(lambda x: x.strip(), f.readlines()))
                    files_in_build = get_dir_content(build_dir)
                    files_in_manifest.remove('.')
                    for y in files_in_build:
                        print(f"file in build", file=sys.stderr)
                        if y not in files_in_manifest:
                            try:
                                p = os.path.join(build_dir, y)
                                print(f"removing {p}", file=sys.stderr)
                                if (os.path.isfile(p)):
                                    os.remove(p)
                                elif os.path.islink(p):
                                    os.unlink(p)
                                elif os.path.isdir(p):
                                    os.rmdir(p)
                                else:
                                    print(f"unhandled {p}", file=sys.stderr)
                                yield { '_time': time.time(), 'filename': y, 'removed': 'true' , 'reason': ''}
                            except Exception as e:
                                yield { '_time': time.time(), 'filename': y, 'removed': 'false', 'reason': str(e) }
                        else:
                            files_in_manifest.remove(y)
            if manage_option == 'show':
                show_option = self.fieldnames[1]
                if show_option == 'process':
                    yield {'process_count': get_psc_process_count()}


dispatch(PSCManage, sys.argv, sys.stdin, sys.stdout, __name__)
