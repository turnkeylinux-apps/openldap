#!/bin/bash -e

fatal() {
    echo "fatal: $@" 1>&2
    exit 1
}

usage() {
cat<<EOF
Syntax: $(basename $0) domain password
Re-initialize LDAP

Arguments:
    domain          # LDAP domain
    password        # LDAP admin password

EOF
    exit 1
}

if [[ "$#" != "2" ]]; then
    usage
fi

LDAP_DOMAIN=$1
LDAP_PASS=$2
LDAP_BASEDN="dc=`echo $LDAP_DOMAIN | sed 's/^\.//; s/\./,dc=/g'`"

TLS=/etc/ldap/tls
TLS_CA_CRT=$TLS/ca_cert.pem
TLS_LDAP_KEY=$TLS/openldap_key.pem
TLS_LDAP_CRT=$TLS/openldap_crt.pem

SLAPD_RUNNING=$(/etc/init.d/slapd status > /dev/null; echo $?)

# re-configure ldap
debconf-set-selections << EOF
slapd slapd/backend string HDB
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/no_configuration boolean false
slapd slapd/move_old_database boolean true
slapd slapd/purge_database boolean true
slapd slapd/password1 password $LDAP_PASS
slapd slapd/password2 password $LDAP_PASS
slapd slapd/domain string $LDAP_DOMAIN
slapd shared/organization string $LDAP_DOMAIN
EOF

rm -rf /var/backups/slapd-
rm -rf /var/backups/*.ldapdb
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure slapd

# create Users/Groups OU's and default posixGroup
ldapadd -x -D cn=admin,$LDAP_BASEDN -w $LDAP_PASS <<EOL
dn: ou=Groups,$LDAP_BASEDN
objectclass: organizationalUnit
objectclass: top
ou: Groups

dn: cn=default,ou=Groups,$LDAP_BASEDN
cn: default
gidnumber: 500
objectclass: posixGroup
objectclass: top

dn: ou=Users,$LDAP_BASEDN
objectclass: organizationalUnit
objectclass: top
ou: Users
EOL

# configure TLS
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOL
dn: cn=config
add: olcTLSCACertificateFile
olcTLSCACertificateFile: $TLS_CA_CRT
-
add: olcTLSCertificateFile
olcTLSCertificateFile: $TLS_LDAP_CRT
-
add: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: $TLS_LDAP_KEY
-
add: olcTLSCipherSuite
olcTLSCipherSuite: normal
-
add: olcTLSVerifyClient
olcTLSVerifyClient: never
EOL

# update phpldapadmin
CONF=/var/www/phpldapadmin/config/config.php
sed -i "s|bind_id.*|bind_id','cn=admin,$LDAP_BASEDN');|" $CONF

# update ldapscripts
CONF=/etc/ldapscripts/ldapscripts.conf
sed -i "s|^BINDDN.*|BINDDN=\"cn=admin,$LDAP_BASEDN\"|" $CONF
sed -i "s|^SUFFIX.*|SUFFIX=\"$LDAP_BASEDN\"|" $CONF

CONF=/etc/ldapscripts/ldapscripts.passwd
echo -n $LDAP_PASS > $CONF
chmod 640 $CONF

# restart slapd if it was running, or stop it
if [ "$SLAPD_RUNNING" == "0" ]; then
    /etc/init.d/slapd restart
else
    /etc/init.d/slapd stop
fi

