OpenLDAP - Open Source Directory Services
=========================================

`OpenLDAP`_ is an open source implementation of the Lightweight
Directory Access Protocol (LDAP) developed by the OpenLDAP Project, a
collaborative effort to develop a robust, commercial-grade, fully
featured, and open source LDAP suite of applications and development
tools.

This appliance includes all the standard features in `TurnKey Core`_,
and on top of that:

- OpenLDAP configurations:
   
   - OpenLDAP and its client utilities installed and maintained through
     Debian's package management system.
   - LDAP domain and administrator password configured at first boot.
   - TLS support for LDAPS out of the box. The generated CA certificate is
     available at ``/etc/ldap/tls/ca_cert.pem`` and certificates can be
     regenerated with ``turnkey-regen-ldap-certs``.
   - Users and Groups organizational units plus a default ``users`` POSIX
     group.

- phpLDAPadmin installed from Debian and served over TLS for web-based LDAP
  administration.

- Webmin LDAP server module.

See the `OpenLDAP docs`_ for further details.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH: username **root**
-  OpenLDAP and phpLDAPadmin: administrator DN **cn=admin,dc=example,dc=com**
   for the default domain **example.com**


.. _OpenLDAP: https://www.openldap.org/
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _OpenLDAP docs: https://www.turnkeylinux.org/docs/openldap
