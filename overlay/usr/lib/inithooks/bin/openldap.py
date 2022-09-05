#!/usr/bin/python3
"""Set OpenLDAP domain and admin password (will reinitialize LDAP)

Option:
    --pass=     unless provided, will ask interactively
    --domain=   unless provided, will ask interactively
                DEFAULT=example.com

"""

import os
import sys
import getopt
import subprocess

from libinithooks import inithooks_cache
from libinithooks.dialog_wrapper import Dialog

DEFAULT_DOMAIN = "example.com"


def usage(s=None):
    if s:
        print("Error:", s, file=sys.stderr)
    print("Syntax: %s [options]" % sys.argv[0], file=sys.stderr)
    print(__doc__, file=sys.stderr)
    sys.exit(1)


def main():
    try:
        opts, args = getopt.gnu_getopt(sys.argv[1:], "h",
                                       ['help', 'pass=', 'domain='])
    except getopt.GetoptError as e:
        usage(e)

    domain = ""
    password = ""
    for opt, val in opts:
        if opt in ('-h', '--help'):
            usage()
        elif opt == '--pass':
            password = val
        elif opt == '--domain':
            domain = val

    if not password:
        d = Dialog('TurnKey Linux - First boot configuration')
        password = d.get_password(
            "OpenLDAP Password",
            "Enter new password for the OpenLDAP 'admin' account.")

    if not domain:
        if 'd' not in locals():
            d = Dialog('TurnKey Linux - First boot configuration')

        domain = d.get_input(
            "OpenLDAP Domain",
            "Enter the OpenLDAP domain.",
            DEFAULT_DOMAIN)

    if domain == "DEFAULT":
        domain = DEFAULT_DOMAIN

    inithooks_cache.write('APP_DOMAIN', domain)

    script = os.path.join(os.path.dirname(__file__), 'openldap-reinit.sh')
    subprocess.check_output([script, domain, password])


if __name__ == "__main__":
    main()
