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
   
   - Installed and maintained through package management system (slapd
     ldap-utils packages)
   - Set LDAP domain and admin password on firstboot (convenience,
     security).
   - TLS support for ldaps out of the box (security). Note, you can
     find the pre-generated CA certificate as /etc/ldap/tls/ca_cert.pem
     and/or regenerate one with the 'turnkey-regen-ldap-certs' command.
   - Includes Users/Groups OU and default PosixGroup (convenience).

- Includes phpLDAPadmin for web based LDAP administration, with SSL
  support out of the box.
   
   - Installed from upstream source code to /var/www/phpldapadmin

- Webmin modules for configuring Apache2, PHP, MySQL and Postfix.

See the `OpenLDAP docs`_ for further details.

Credentials *(passwords set at first boot)*
-------------------------------------------

-  Webmin, SSH, MySQL: username **root**
-  OpenLDAP: default domain **example.com**


.. _OpenLDAP: http://www.openldap.org/
.. _TurnKey Core: https://www.turnkeylinux.org/core
.. _OpenLDAP docs: https://www.turnkeylinux.org/docs/openldap
