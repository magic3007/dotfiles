#!/usr/bin/env bash
# Joshuto 0.9.9: --path FILE --preview-width COLS --preview-height ROWS.
# Python supervises optional converters so malformed files cannot hang previews.
command -v python3 >/dev/null 2>&1 || { printf 'Preview requires python3.\n'; exit 0; }
exec python3 - "$@" <<'PY'
import argparse
import os
import re
import selectors
import shutil
import signal
import stat
import subprocess
import sys
import time

parser = argparse.ArgumentParser(add_help=False)
parser.add_argument('--path', required=True)
parser.add_argument('--preview-width', type=int, default=80)
parser.add_argument('--preview-height', type=int, default=40)
args = parser.parse_args()
path = os.path.abspath(args.path)
try:
    info = os.stat(path)
except OSError:
    sys.exit(1)
if not stat.S_ISREG(info.st_mode):
    sys.exit(1)

# Bound all converter output and the total conversion time (including fallbacks).
MAX_BYTES = 128 * 1024
MAX_TEXT_INPUT = 2 * 1024 * 1024
deadline = time.monotonic() + 6
width = max(1, min(args.preview_width, 1000))


def run(command):
    if not shutil.which(command[0]) or time.monotonic() >= deadline:
        return None
    try:
        process = subprocess.Popen(command, stdin=subprocess.DEVNULL,
                                   stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                   start_new_session=True)
    except OSError:
        return None
    chunks = bytearray()
    limited = False
    timer = min(deadline, time.monotonic() + 4)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    try:
        while True:
            remaining = timer - time.monotonic()
            if remaining <= 0:
                return None
            if not selector.select(remaining):
                return None
            block = os.read(process.stdout.fileno(), min(8192, MAX_BYTES - len(chunks)))
            if not block:
                break
            chunks.extend(block)
            if len(chunks) >= MAX_BYTES:
                limited = True
                break
        if not limited:
            try:
                if process.wait(timeout=max(0.01, timer - time.monotonic())) != 0:
                    return None
            except subprocess.TimeoutExpired:
                return None
        return bytes(chunks)
    finally:
        selector.close()
        # Kill the whole group, including descendants that kept stdout open.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
        process.stdout.close()


def display(data):
    if isinstance(data, bytes):
        data = data.decode('utf-8', errors='replace')
    # Preserve colors only: filenames/content must not inject terminal commands.
    data = re.sub(r'\x1b\][^\x07\x1b]*(?:\x07|\x1b\\|$)', '', data)
    data = re.sub(r'\x1b\[(?![0-9;]*m)[0-?]*[ -/]*[@-~]', '', data)
    data = re.sub(r'\x1b(?!\[[0-9;]*m)', '', data)
    data = re.sub(r'[\x00-\x08\x0b-\x1f\x7f-\x9f]',
                  lambda match: '\x1b' if match[0] == '\x1b' else '', data)
    print('\n'.join(data.expandtabs(2).splitlines()[:1000]))
    sys.exit(0)


mime_data = run(['file', '--brief', '--mime-type', '--dereference', '--', path])
mime = mime_data.decode().strip() if mime_data else 'application/octet-stream'
extension = os.path.splitext(path)[1].lower()

if mime == 'application/pdf' or extension == '.pdf':
    result = run(['pdftotext', '-f', '1', '-l', '10', '-layout', '-nopgbrk', path, '-'])
    if result and result.strip():
        display(result)
    display(f'PDF document · {info.st_size:,} bytes\nText preview unavailable (pdftotext required; scanned PDFs need OCR).')

archives = {'.zip', '.7z', '.rar', '.tar', '.gz', '.tgz', '.bz2', '.xz',
            '.zst', '.tbz2', '.txz', '.jar', '.war', '.xpi', '.epub'}
if extension in archives or mime in {'application/zip', 'application/x-tar',
                                     'application/x-7z-compressed', 'application/x-rar'}:
    for command in (['7zz', 'l', '-p', '--', path],
                    ['7z', 'l', '-p', '--', path],
                    ['bsdtar', '-tf', path], ['unzip', '-l', path]):
        result = run(command)
        if result:
            display(result)
    display(f'Archive · {info.st_size:,} bytes\nListing unavailable (7zz, 7z, bsdtar or unzip required).')

if mime.startswith(('image/', 'video/', 'audio/')):
    result = run(['ffprobe', '-v', 'error', '-show_entries',
                  'format=format_name,duration,size,bit_rate:stream=codec_name,codec_type,width,height,sample_rate,channels',
                  '-of', 'default=noprint_wrappers=1', path])
    if result:
        display(result)
    # Success is essential: it enables Joshuto's native image renderer.
    result = run(['file', '--brief', '--dereference', '--', path])
    display(result or f'{mime}\n{info.st_size:,} bytes')

# Detect extensionless UTF-8 text as well as MIME-identified source files.
try:
    with open(path, 'rb') as source:
        sample = source.read(MAX_BYTES)
except OSError:
    sys.exit(1)
is_text = b'\0' not in sample
try:
    sample.decode('utf-8')
except UnicodeDecodeError as error:
    # A bounded read may end halfway through a UTF-8 character.
    is_text = is_text and error.reason == 'unexpected end of data'
is_text = is_text and not any(c < 32 and c not in (7, 9, 10, 12, 13, 27) for c in sample)
if is_text:
    if (extension in {'.json', '.ipynb'} or mime == 'application/json') and info.st_size <= MAX_TEXT_INPUT:
        result = run(['jq', '--color-output', '.', path])
        if result:
            display(result)
    if info.st_size <= MAX_TEXT_INPUT:
        # Use terminal palette colors to match the file manager's ANSI theme.
        for bat in ('bat', 'batcat'):
            result = run([bat, '--color=always', '--paging=never', '--style=plain',
                          '--wrap=never', '--tabs=2', '--theme=base16',
                          f'--terminal-width={width}', '--line-range=:1000', '--', path])
            if result is not None:
                display(result)
    display(sample)

result = run(['file', '--brief', '--dereference', '--', path])
display(f'{mime}\n{info.st_size:,} bytes\n' +
        (result.decode('utf-8', errors='replace').strip() if result else 'Binary file'))
PY
