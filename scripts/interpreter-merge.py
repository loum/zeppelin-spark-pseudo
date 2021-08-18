"""Merge custom interpreters into Zeppelin's conf/interpreter.json

"""
import os
import sys
import re
import json
import logging
import pathlib
import argparse

LOG = logging.getLogger('interpreter_merge')
if not LOG.handlers:
    LOG.propagate = 0
    CONSOLE = logging.StreamHandler()
    LOG.addHandler(CONSOLE)
    FORMATTER = logging.Formatter('%(asctime)s:%(name)s:%(levelname)s: %(message)s')
    CONSOLE.setFormatter(FORMATTER)

LOG.setLevel(logging.INFO)

DESCRIPTION = """Merge custom interpreters into Zeppelin's conf/interpreter.json"""


def main():
    """Script entry point.

    """
    parser = argparse.ArgumentParser(description=DESCRIPTION)
    parser.add_argument('-p', '--path',
                        help='Path to interpreter.json (absolute, or relative to user home directory)',
                        default='conf')

    args = parser.parse_args()

    _merge(args.path)


def _merge(interpreter_path='conf'):
    """Merge Zeppelin interpreter JSON files.

    """
    qualified_interpreter_path = interpreter_path
    if not os.path.isabs(qualified_interpreter_path):
        qualified_interpreter_path = os.path.join(str(pathlib.Path.home()), interpreter_path)

    interpreter = json.loads('{"interpreterSettings": {}}')
    if os.path.exists(os.path.join(qualified_interpreter_path, 'interpreter.json')):
        with open(os.path.join(qualified_interpreter_path, 'interpreter.json')) as _fp:
            interpreter = json.load(_fp)

        interpreter_bak_file_path = os.path.join(qualified_interpreter_path, 'interpreter.json.bak')
        with open(interpreter_bak_file_path, 'w') as _fp_out:
            LOG.info('Backing up "%s" to "%s"',
                     os.path.join(qualified_interpreter_path, 'interpreter.json'),
                     interpreter_bak_file_path)
            _fp_out.write(json.dumps(interpreter, indent=2))

    for interpreter_file in get_directory_files(qualified_interpreter_path, '^interpreter-.*\.json$'):
        with open(interpreter_file) as _fp:
            LOG.info('Found extra interpreter file "%s"', interpreter_file)
            interpreter_extra = json.load(_fp)

            interpreter.get('interpreterSettings').update(interpreter_extra)

    with open(os.path.join(qualified_interpreter_path, 'interpreter.json'), 'w') as _fp_out:
        LOG.info('Writing out to "%s"', os.path.join(qualified_interpreter_path, 'interpreter.json'))
        _fp_out.write(json.dumps(interpreter, indent=2))


def get_directory_files(directory_path, file_filter=None):
    """Generator that returns the files in the directory given by *directory_path*.
    Does not include the special entries '.' and '..' even if they are
    present in the directory.

    If *file_filter* is provided, will perform a regular expression match
    against the files within *directory_path*.

    """
    directory_files = []
    try:
        directory_files = os.listdir(directory_path)
    except (TypeError, OSError) as err:
        LOG.error('Directory listing error for %s: %s', directory_path, err)

    for this_file in directory_files:
        this_file = os.path.join(directory_path, this_file)
        if not os.path.isfile(this_file):
            continue

        if file_filter is None:
            yield this_file
        else:
            reg_c = re.compile(file_filter)
            reg_match = reg_c.match(os.path.basename(this_file))
            if reg_match:
                yield this_file


if __name__ == "__main__":
    main()
