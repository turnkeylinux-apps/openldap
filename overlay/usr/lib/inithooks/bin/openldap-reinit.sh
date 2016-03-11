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
LDAP_PASS_RAND=`slappasswd -g`
LDAP_PASS_HASH=`slappasswd -h {ssha} -s $LDAP_PASS`

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

# create Users/Groups OU's and users posixGroup
ldapadd -x -D cn=admin,$LDAP_BASEDN -w $LDAP_PASS <<EOL
dn: ou=Groups,$LDAP_BASEDN
objectclass: organizationalUnit
objectclass: top
ou: Groups

dn: cn=users,ou=Groups,$LDAP_BASEDN
cn: users
gidnumber: 100
objectclass: posixGroup
objectclass: top

dn: ou=Users,$LDAP_BASEDN
objectclass: organizationalUnit
objectclass: top
ou: Users

dn: ou=Hosts,$LDAP_BASEDN
objectclass: organizationalUnit
objectclass: top
ou: Hosts

dn: ou=Idmaps,$LDAP_BASEDN
objectclass: organizationalUnit
objectclass: top
ou: Idmaps

dn: cn=samba,$LDAP_BASEDN
cn: samba
objectclass: simpleSecurityObject
objectclass: organizationalRole
description: SAMBA Access Account
userPassword: $LDAP_PASS_RAND

dn: ou=Aliases,$LDAP_BASEDN
objectclass: organizationalUnit
objectclass: top
ou: Aliases

dn: cn=nsspam,$LDAP_BASEDN
cn: nsspam
objectclass: simpleSecurityObject
objectclass: organizationalRole
description: NSS/PAM Access Account
userPassword: $LDAP_PASS_RAND
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

# configure Database Indices
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOL
dn: olcDatabase={1}hdb,cn=config
delete: olcDbIndex
olcDbIndex: cn,uid eq
-
delete: olcDbIndex
olcDbIndex: member,memberUid eq
-
add: olcDbIndex
olcDbIndex: cn eq,pres,sub
-
add: olcDbIndex
olcDbIndex: sn eq,pres,sub
-
add: olcDbIndex
olcDbIndex: ou eq,pres,sub
-
add: olcDbIndex
olcDbIndex: uid eq,pres,sub
-
add: olcDbIndex
olcDbIndex: displayName eq,pres,sub
-
add: olcDbIndex
olcDbIndex: mail,givenName eq,subinitial
-
add: olcDbIndex
olcDbIndex: loginShell eq
-
add: olcDbIndex
olcDbIndex: memberUid eq,pres,sub
-
add: olcDbIndex
olcDbIndex: member eq,pres
-
add: olcDbIndex
olcDbIndex: uniqueMember eq,pres
-
add: olcDbIndex
olcDbIndex: dc eq
-
add: olcDbIndex
olcDbIndex: default sub
EOL

# configure olcRootPW
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOL
dn: olcDatabase={0}config,cn=config
replace: olcRootPW
olcRootPW: $LDAP_PASS_HASH
EOL

# add samba schema
ldapadd -Q -Y EXTERNAL -H ldapi:/// -f /etc/ldap/schema/samba.ldif

# add nsspam user to access rules
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOL
dn: olcDatabase={1}hdb,cn=config
delete: olcAccess
olcAccess: {0}
-
add: olcAccess
olcAccess: {0}to attrs=userPassword,shadowLastChange,SambaLMPassword,SambaNTPassword by self write by anonymous auth by dn="cn=nsspam,$LDAP_BASEDN" write by dn="cn=admin,$LDAP_BASEDN" write by * none
EOL

# add samba specific indices
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOL
dn: olcDatabase={1}hdb,cn=config
add: olcDbIndex
olcDbIndex: sambaSID eq
-
add: olcDbIndex
olcDbIndex: sambaPrimaryGroupSID eq
-
add: olcDbIndex
olcDbIndex: sambaGroupType eq
-
add: olcDbIndex
olcDbIndex: sambaSIDList eq
-
add: olcDbIndex
olcDbIndex: sambaDomainName eq
EOL

# add samba specific access rules
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOL
dn: olcDatabase={1}hdb,cn=config
add: olcAccess
olcAccess: {0}to dn.base="$LDAP_BASEDN" attrs=children by dn="cn=samba,$LDAP_BASEDN" write by dn="cn=admin,$LDAP_BASEDN" write by * read
-
add: olcAccess
olcAccess: {0}to filter=(objectClass=sambaDomain) by dn="cn=samba,$LDAP_BASEDN" write by dn="cn=admin,$LDAP_BASEDN" write by * read
-
add: olcAccess
olcAccess: {0}to dn.children="ou=Users,$LDAP_BASEDN" by self write by dn="cn=samba,$LDAP_BASEDN" write by dn="cn=nsspam,$LDAP_BASEDN" write by dn="cn=admin,$LDAP_BASEDN" write by * read
-
add: olcAccess
olcAccess: {0}to dn.children="ou=Users,$LDAP_BASEDN" attrs=userPassword,shadowLastChange,SambaLMPassword,SambaNTPassword by self write by anonymous auth by dn="cn=samba,$LDAP_BASEDN" write by dn="cn=nsspam,$LDAP_BASEDN" write by dn="cn=admin,$LDAP_BASEDN" write by * none
-
add: olcAccess
olcAccess: {0}to dn.subtree="ou=Hosts,$LDAP_BASEDN" by self write by dn="cn=samba,$LDAP_BASEDN" write by dn="cn=admin,$LDAP_BASEDN" write by * read
-
add: olcAccess
olcAccess: {0}to dn.children="ou=Hosts,$LDAP_BASEDN" attrs=userPassword,shadowLastChange,SambaLMPassword,SambaNTPassword by self write by anonymous auth by dn="cn=samba,$LDAP_BASEDN" write by dn="cn=admin,$LDAP_BASEDN" write by * none
-
add: olcAccess
olcAccess: {0}to dn.subtree="ou=Idmaps,$LDAP_BASEDN" by self write by dn="cn=samba,$LDAP_BASEDN" write by dn="cn=admin,$LDAP_BASEDN" write by * read
-
add: olcAccess
olcAccess: {0}to dn.children="ou=Idmaps,$LDAP_BASEDN" attrs=userPassword,shadowLastChange,SambaLMPassword,SambaNTPassword by self write by anonymous auth by dn="cn=samba,$LDAP_BASEDN" write by dn="cn=admin,$LDAP_BASEDN" write by * none
EOL

# update phpldapadmin
CONF=/var/www/phpldapadmin/config/config.php
sed -i "s|'base'.*|'base',array('cn=config','$LDAP_BASEDN'));|" $CONF
sed -i "s|bind_id.*|bind_id','cn=admin,$LDAP_BASEDN');|" $CONF

sed -i "s|search_base.*|search_base','ou=Users,$LDAP_BASEDN');|" $CONF

CONF=/var/www/phpldapadmin/templates/creation/tkl-shadowAccount.xml
sed -i "s|@example.com|@$LDAP_DOMAIN|" $CONF

CONF=/var/www/phpldapadmin/templates/creation/tkl-sambaSamAccount.xml
sed -i "s|@example.com|@$LDAP_DOMAIN|" $CONF

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

