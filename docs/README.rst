Overview
--------

With `Turnkey OpenLDAP`_ , active directory tasks are easier than ever.
OpenLDAP is an open source implementation of the Lightweight Directory Access Protocol (LDAP) developed by the `OpenLDAP` Project, a collaborative effort to develop 
a robust, commercial-grade, fully featured, and open source LDAP suite of applications 
and development tools.
-----------------

 "Simple things should be simple. Hard things should be possible."

 -- Alan Kay
-----------------

Sadly, we've gotten into the nasty habit of prepending TKL - the TurnKey
Linux initials - to all things TurnKey but don't let that fool you.
Under the hood OpenLDAP is 100% general purpose.

This appliance includes the features in `Turnkey Core`_ , along with additional OpenLDAP configurations.
Of course we'll be delighted if you end up using OpenLDAP to help us
improve TurnKey but everyone is more than welcome to use it for other
things as well.

Testing
-------------------------------------------

You can go through and test your LDAP connection with this `GUI LDAP browser`_ application.

Additionally
-------------------------------------------

More advanced Linux users may be able to fast forward through most of it and learn the most by examining a few real-life examples from the
TurnKey library: https://github.com/turnkeylinux-apps/openldap

If you find yourself confused, take a step back and read through the
rest of the `documentation_` first to get an overview of how things works,
learn more about development best `practices`, etc. We've made this easy
enough so anyone that wants to can jump in and make cool stuff happen.

Update
-------------------------------------------
The latest version 17.0 update addreses samba schema archives changing to plain text files. Version 17.0 also addresses LigHTTPd config error due to changes made in common for v17 udpate.
Lastly, the update refactors python inithooks overlay to be comopatible with v17.x.

.. _OpenLDAP: https://www.openldap.org/
.. _Turnkey Core: https://www.turnkeylinux.org/core
.. _Turnkey OpenLDAP: https://www.turnkeylinux.org/openldap
.. _documentation: https://www.turnkeylinux.org/docs/openldap
.. _practices: https://www.openldap.org/doc/admin24/guide.html
.. _GUI LDAP browser: https://www.ldapadministrator.com/softerra-ldap-browser.htm