"""Set Interpreter values dynamically.

"""
import os
import argparse
import tempfile
import shutil
import logging
import jinja2

LOG = logging.getLogger('interpreter_setter')
if not LOG.handlers:
    LOG.propagate = 0
    CONSOLE = logging.StreamHandler()
    LOG.addHandler(CONSOLE)
    FORMATTER = logging.Formatter('%(asctime)s:%(name)s:%(levelname)s: %(message)s')
    CONSOLE.setFormatter(FORMATTER)

LOG.setLevel(logging.INFO)

DESCRIPTION = """Set Interpreter values dynamically"""


def main():
    """Script entry point.
    """
    parser = argparse.ArgumentParser(description=DESCRIPTION)
    parser.add_argument('-t',
                        '--template',
                        help='path to Jinja2 template (absolute, or relative to user home)',
                        required=True)

    # Prepare the argument list.
    args = parser.parse_args()

    _build_interpreter_definition(_get_interpreter_values(), args.template)


def _get_interpreter_values(token='ZEPPELIN_INTERPRETER') -> dict:
    """Returns a dictionary structure of all Zeppelin Interpreter values from the
    environment starting with the token *token*.

    """
    env_variables = {}
    for env_variable in os.environ:
        if env_variable.startswith(token):
            env_variables[env_variable] = os.environ[env_variable]

    LOG.info('%s-based token environment variables: %s', token, env_variables)

    return env_variables


def _build_interpreter_definition(config_map, template_file_path) -> str:
    """Take *template_file_path* and convert environment
    variables into runtime Zeppelin Interpreter definition files
    based on values contained in *config_map*.

    *template_file_path* needs to end with a `.j2` extension as the generated
    content will be output to the *template_file_path* less the ``.j2``.

    Returns the name of the output content's file path.

    """
    target_template_file_path = os.path.splitext(template_file_path)
    LOG.info('Generating Zeppelin Interpreter file for "%s"', template_file_path)

    if len(target_template_file_path) > 1 and target_template_file_path[1] == '.j2':
        file_loader = jinja2.FileSystemLoader(os.path.dirname(template_file_path))
        j2_env = jinja2.Environment(loader=file_loader)
        template = j2_env.get_template(os.path.basename(template_file_path))

        output = template.render(**config_map)

        out_fh = tempfile.NamedTemporaryFile()
        out_fh.write(output.encode())
        out_fh.flush()
        shutil.copy(out_fh.name, target_template_file_path[0])
        LOG.info('Zeppelin Interpreter file "%s" generated', target_template_file_path[0])
    else:
        LOG.error('Skipping "%s" Zeppelin Interpreter generation as it does not end with ".j2"',
                  template_file_path)


if __name__ == '__main__':
    main()
