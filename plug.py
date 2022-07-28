import datetime
import functools
import os
try:
    import queue
except ImportError:
    import Queue as queue
import random
import re
import shutil
import signal
import subprocess
import tempfile
import threading as thr
import time
import traceback
import vim

G_NVIM      = vim.eval("has('nvim')") == '1'
G_PULL      = vim.eval('s:update.pull') == '1'
G_RETRIES   = int(vim.eval('get(g:, "plug_retries", 2)')) + 1
G_TIMEOUT   = int(vim.eval('get(g:, "plug_timeout", 60)'))
G_CLONE_OPT = ' '.join(vim.eval('s:clone_opt'))
G_PROGRESS  = vim.eval('s:progress_opt(1)')
G_LOG_PROB  = 1.0 / int(vim.eval('s:update.threads'))
G_STOP      = thr.Event()
G_IS_WIN    = vim.eval('s:is_win') == '1'

class PlugError(Exception):
    def __init__(self, msg):
        self.msg = msg

class CmdTimedOut(PlugError):
    pass

class CmdFailed(PlugError):
    pass

class InvalidURI(PlugError):
    pass

class Action(object):
    INSTALL, UPDATE, ERROR, DONE = ['+', '*', 'x', '-']

class Buffer(object):
    def __init__(self, lock, num_plugs, is_pull):
        self.bar       = ''
        self.event     = 'Updating' if is_pull else 'Installing'
        self.lock      = lock
        self.maxy      = int(vim.eval('winheight(".")'))
        self.num_plugs = num_plugs

    def __where(self, name):
        """ Find first line with name in current buffer. Return line num. """
        found, lnum = False, 0
        matcher = re.compile('^[-+x*] {0}:'.format(name))
        for line in vim.current.buffer:
            if matcher.search(line) is not None:
                found = True
                break
            lnum += 1

        if not found:
            lnum = -1
        return lnum

    def header(self):
        curbuf = vim.current.buffer
        curbuf[0] = self.event + ' plugins ({0}/{1})'.format(len(self.bar), self.num_plugs)

        num_spaces = self.num_plugs - len(self.bar)
        curbuf[1] = '[{0}{1}]'.format(self.bar, num_spaces * ' ')

        with self.lock:
            vim.command('normal! 2G')
            vim.command('redraw')

    def write(self, action, name, lines):
        first, rest = lines[0], lines[1:]
        msg = ['{0} {1}{2}{3}'.format(action, name, ': ' if first else '', first)]
        msg.extend(['    ' + line for line in rest])

        try:
            if action == Action.ERROR:
                self.bar += 'x'
                vim.command("call add(s:update.errors, '{0}')".format(name))
            elif action == Action.DONE:
                self.bar += '='

            curbuf = vim.current.buffer
            lnum = self.__where(name)
            if lnum != -1: # Found matching line num
                del curbuf[lnum]
                if lnum > self.maxy and action in set([Action.INSTALL, Action.UPDATE]):
                    lnum = 3
            else:
                lnum = 3
            curbuf.append(msg, lnum)

            self.header()
        except vim.error:
            pass

class Command(object):
    CD = 'cd /d' if G_IS_WIN else 'cd'

    def __init__(self, cmd, cmd_dir=None, timeout=60, cb=None, clean=None):
        self.cmd = cmd
        if cmd_dir:
            self.cmd = '{0} {1} && {2}'.format(Command.CD, cmd_dir, self.cmd)
        self.timeout = timeout
        self.callback = cb if cb else (lambda msg: None)
        self.clean = clean if clean else (lambda: None)
        self.proc = None

    @property
    def alive(self):
        """ Returns true only if command still running. """
        return self.proc and self.proc.poll() is None

    def execute(self, ntries=3):
        """ Execute the command with ntries if CmdTimedOut.
                Returns the output of the command if no Exception.
        """
        attempt, finished, limit = 0, False, self.timeout

        while not finished:
            try:
                attempt += 1
                result = self.try_command()
                finished = True
                return result
            except CmdTimedOut:
                if attempt != ntries:
                    self.notify_retry()
                    self.timeout += limit
                else:
                    raise

    def notify_retry(self):
        """ Retry required for command, notify user. """
        for count in range(3, 0, -1):
            if G_STOP.is_set():
                raise KeyboardInterrupt
            msg = 'Timeout. Will retry in {0} second{1} ...'.format(
                        count, 's' if count != 1 else '')
            self.callback([msg])
            time.sleep(1)
        self.callback(['Retrying ...'])

    def try_command(self):
        """ Execute a cmd & poll for callback. Returns list of output.
                Raises CmdFailed   -> return code for Popen isn't 0
                Raises CmdTimedOut -> command exceeded timeout without new output
        """
        first_line = True

        try:
            tfile = tempfile.NamedTemporaryFile(mode='w+b')
            preexec_fn = not G_IS_WIN and os.setsid or None
            self.proc = subprocess.Popen(self.cmd, stdout=tfile,
                                                                     stderr=subprocess.STDOUT,
                                                                     stdin=subprocess.PIPE, shell=True,
                                                                     preexec_fn=preexec_fn)
            thrd = thr.Thread(target=(lambda proc: proc.wait()), args=(self.proc,))
            thrd.start()

            thread_not_started = True
            while thread_not_started:
                try:
                    thrd.join(0.1)
                    thread_not_started = False
                except RuntimeError:
                    pass

            while self.alive:
                if G_STOP.is_set():
                    raise KeyboardInterrupt

                if first_line or random.random() < G_LOG_PROB:
                    first_line = False
                    line = '' if G_IS_WIN else nonblock_read(tfile.name)
                    if line:
                        self.callback([line])

                time_diff = time.time() - os.path.getmtime(tfile.name)
                if time_diff > self.timeout:
                    raise CmdTimedOut(['Timeout!'])

                thrd.join(0.5)

            tfile.seek(0)
            result = [line.decode('utf-8', 'replace').rstrip() for line in tfile]

            if self.proc.returncode != 0:
                raise CmdFailed([''] + result)

            return result
        except:
            self.terminate()
            raise

    def terminate(self):
        """ Terminate process and cleanup. """
        if self.alive:
            if G_IS_WIN:
                os.kill(self.proc.pid, signal.SIGINT)
            else:
                os.killpg(self.proc.pid, signal.SIGTERM)
        self.clean()

class Plugin(object):
    def __init__(self, name, args, buf_q, lock):
        self.name = name
        self.args = args
        self.buf_q = buf_q
        self.lock = lock
        self.tag = args.get('tag', 0)

    def manage(self):
        try:
            if os.path.exists(self.args['dir']):
                self.update()
            else:
                self.install()
                with self.lock:
                    thread_vim_command("let s:update.new['{0}'] = 1".format(self.name))
        except PlugError as exc:
            self.write(Action.ERROR, self.name, exc.msg)
        except KeyboardInterrupt:
            G_STOP.set()
            self.write(Action.ERROR, self.name, ['Interrupted!'])
        except:
            # Any exception except those above print stack trace
            msg = 'Trace:\n{0}'.format(traceback.format_exc().rstrip())
            self.write(Action.ERROR, self.name, msg.split('\n'))
            raise

    def install(self):
        target = self.args['dir']
        if target[-1] == '\\':
            target = target[0:-1]

        def clean(target):
            def _clean():
                try:
                    shutil.rmtree(target)
                except OSError:
                    pass
            return _clean

        self.write(Action.INSTALL, self.name, ['Installing ...'])
        callback = functools.partial(self.write, Action.INSTALL, self.name)
        cmd = 'git clone {0} {1} {2} {3} 2>&1'.format(
                    '' if self.tag else G_CLONE_OPT, G_PROGRESS, self.args['uri'],
                    esc(target))
        com = Command(cmd, None, G_TIMEOUT, callback, clean(target))
        result = com.execute(G_RETRIES)
        self.write(Action.DONE, self.name, result[-1:])

    def repo_uri(self):
        cmd = 'git rev-parse --abbrev-ref HEAD 2>&1 && git config -f .git/config remote.origin.url'
        command = Command(cmd, self.args['dir'], G_TIMEOUT,)
        result = command.execute(G_RETRIES)
        return result[-1]

    def update(self):
        actual_uri = self.repo_uri()
        expect_uri = self.args['uri']
        regex = re.compile(r'^(?:\w+://)?(?:[^@/]*@)?([^:/]*(?::[0-9]*)?)[:/](.*?)(?:\.git)?/?$')
        ma = regex.match(actual_uri)
        mb = regex.match(expect_uri)
        if ma is None or mb is None or ma.groups() != mb.groups():
            msg = ['',
                         'Invalid URI: {0}'.format(actual_uri),
                         'Expected     {0}'.format(expect_uri),
                         'PlugClean required.']
            raise InvalidURI(msg)

        if G_PULL:
            self.write(Action.UPDATE, self.name, ['Updating ...'])
            callback = functools.partial(self.write, Action.UPDATE, self.name)
            fetch_opt = '--depth 99999999' if self.tag and os.path.isfile(os.path.join(self.args['dir'], '.git/shallow')) else ''
            cmd = 'git fetch {0} {1} 2>&1'.format(fetch_opt, G_PROGRESS)
            com = Command(cmd, self.args['dir'], G_TIMEOUT, callback)
            result = com.execute(G_RETRIES)
            self.write(Action.DONE, self.name, result[-1:])
        else:
            self.write(Action.DONE, self.name, ['Already installed'])

    def write(self, action, name, msg):
        self.buf_q.put((action, name, msg))

class PlugThread(thr.Thread):
    def __init__(self, tname, args):
        super(PlugThread, self).__init__()
        self.tname = tname
        self.args = args

    def run(self):
        thr.current_thread().name = self.tname
        buf_q, work_q, lock = self.args

        try:
            while not G_STOP.is_set():
                name, args = work_q.get_nowait()
                plug = Plugin(name, args, buf_q, lock)
                plug.manage()
                work_q.task_done()
        except queue.Empty:
            pass

class RefreshThread(thr.Thread):
    def __init__(self, lock):
        super(RefreshThread, self).__init__()
        self.lock = lock
        self.running = True

    def run(self):
        while self.running:
            with self.lock:
                thread_vim_command('noautocmd normal! a')
            time.sleep(0.33)

    def stop(self):
        self.running = False

if G_NVIM:
    def thread_vim_command(cmd):
        vim.session.threadsafe_call(lambda: vim.command(cmd))
else:
    def thread_vim_command(cmd):
        vim.command(cmd)

def esc(name):
    return '"' + name.replace('"', '\"') + '"'

def nonblock_read(fname):
    """ Read a file with nonblock flag. Return the last line. """
    fread = os.open(fname, os.O_RDONLY | os.O_NONBLOCK)
    buf = os.read(fread, 100000).decode('utf-8', 'replace')
    os.close(fread)

    line = buf.rstrip('\r\n')
    left = max(line.rfind('\r'), line.rfind('\n'))
    if left != -1:
        left += 1
        line = line[left:]

    return line

def main():
    thr.current_thread().name = 'main'
    nthreads = int(vim.eval('s:update.threads'))
    plugs = vim.eval('s:update.todo')
    mac_gui = vim.eval('s:mac_gui') == '1'

    lock = thr.Lock()
    buf = Buffer(lock, len(plugs), G_PULL)
    buf_q, work_q = queue.Queue(), queue.Queue()
    for work in plugs.items():
        work_q.put(work)

    start_cnt = thr.active_count()
    for num in range(nthreads):
        tname = 'PlugT-{0:02}'.format(num)
        thread = PlugThread(tname, (buf_q, work_q, lock))
        thread.start()
    if mac_gui:
        rthread = RefreshThread(lock)
        rthread.start()

    while not buf_q.empty() or thr.active_count() != start_cnt:
        try:
            action, name, msg = buf_q.get(True, 0.25)
            buf.write(action, name, ['OK'] if not msg else msg)
            buf_q.task_done()
        except queue.Empty:
            pass
        except KeyboardInterrupt:
            G_STOP.set()

    if mac_gui:
        rthread.stop()
        rthread.join()

main()

