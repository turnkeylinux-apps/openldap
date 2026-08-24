#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
entry_uid=tklv19$$
entry_file=/tmp/tkl-openldap-entry.$$.ldif
response=/tmp/tkl-openldap-response.$$
policy=/tmp/tkl-openldap-policy.$$
entry_dn=
admin_dn=

cleanup() {
    if [[ -n $entry_dn ]]; then
        ldapdelete -x -H ldap://127.0.0.1 \
            -D "$admin_dn" -w "$password" "$entry_dn" >/dev/null 2>&1 || true
    fi
    rm -f -- "$entry_file" "$response" "$policy"
}
trap cleanup EXIT

php_fpm_service=$(systemctl list-unit-files 'php*-fpm.service' --no-legend |
    awk 'NR == 1 {print $1}')
test -n "$php_fpm_service"
systemctl --quiet is-active slapd.service lighttpd.service \
    "$php_fpm_service" multi-user.target

slapd_version=$(dpkg-query -W -f='${Version}' slapd)
ldap_utils_version=$(dpkg-query -W -f='${Version}' ldap-utils)
phpldapadmin_version=$(dpkg-query -W -f='${Version}' phpldapadmin)
lighttpd_version=$(dpkg-query -W -f='${Version}' lighttpd)
php_version=$(dpkg-query -W -f='${Version}' php-fpm)
libldap_version=$(dpkg-query -W -f='${Version}' libldap-common)

base_dn=$(ldapsearch -LLL -x -H ldap://127.0.0.1 \
    -s base -b '' namingContexts |
    awk '/^namingContexts: / && !found {
             sub(/^namingContexts: /, ""); print; found=1
         }')
test -n "$base_dn"
admin_dn="cn=admin,$base_dn"

ldapwhoami -x -H ldap://127.0.0.1 \
    -D "$admin_dn" -w "$password" >"$response"
grep -Fqi "dn:$admin_dn" "$response"

ldapsearch -LLL -x -H ldap://127.0.0.1 \
    -D "$admin_dn" -w "$password" -b "$base_dn" \
    '(|(ou=Users)(ou=Groups)(cn=users))' dn >"$response"
grep -Fqi "dn: ou=Users,$base_dn" "$response"
grep -Fqi "dn: ou=Groups,$base_dn" "$response"
grep -Fqi "dn: cn=users,ou=Groups,$base_dn" "$response"

entry_dn="uid=$entry_uid,ou=Users,$base_dn"
cat >"$entry_file" <<EOF
dn: $entry_dn
objectClass: top
objectClass: inetOrgPerson
uid: $entry_uid
cn: TurnKey v19 LDAP Test
sn: Test
description: openldap-roundtrip-ok
EOF
ldapadd -x -H ldap://127.0.0.1 \
    -D "$admin_dn" -w "$password" -f "$entry_file" >/dev/null
ldapsearch -LLL -x -H ldap://127.0.0.1 \
    -D "$admin_dn" -w "$password" -b "$entry_dn" -s base \
    '(objectClass=inetOrgPerson)' uid description >"$response"
grep -Fxq "uid: $entry_uid" "$response"
grep -Fxq 'description: openldap-roundtrip-ok' "$response"
ldapdelete -x -H ldap://127.0.0.1 \
    -D "$admin_dn" -w "$password" "$entry_dn"
entry_dn=
if ldapsearch -LLL -x -H ldap://127.0.0.1 \
        -D "$admin_dn" -w "$password" -b "uid=$entry_uid,ou=Users,$base_dn" \
        -s base dn >/dev/null 2>&1; then
    echo 'deleted LDAP entry remained searchable' >&2
    exit 1
fi

ldap_host=$(hostname -f)
test -s /etc/ldap/tls/ca_cert.pem
test -s /etc/ldap/tls/openldap_crt.pem
LDAPTLS_CACERT=/etc/ldap/tls/ca_cert.pem LDAPTLS_REQCERT=demand \
    ldapwhoami -x -H "ldaps://$ldap_host" \
        -D "$admin_dn" -w "$password" >"$response"
grep -Fqi "dn:$admin_dn" "$response"
ss -ltn | awk '$4 ~ /:636$/ { found=1 } END { exit !found }'

curl --insecure --fail --location --silent --show-error \
    https://127.0.0.1/ >"$response"
grep -qi 'phpLDAPadmin' "$response"
dpkg-query -W webmin-ldap-server >/dev/null

before="$slapd_version|$ldap_utils_version|$phpldapadmin_version|$lighttpd_version|$php_version|$libldap_version"
apt-get update >/dev/null
for package in slapd ldap-utils phpldapadmin lighttpd php-fpm libldap-common; do
    apt-cache policy "$package" >"$policy"
    candidate=$(awk '/Candidate:/ {print $2}' "$policy")
    test -n "$candidate"
    test "$candidate" != '(none)'
    grep -Eq 'http://deb\.debian\.org/debian trixie/main|http://security\.debian\.org/debian-security trixie-security/main' "$policy"
done
after="$(dpkg-query -W -f='${Version}' slapd)|$(dpkg-query -W -f='${Version}' ldap-utils)|$(dpkg-query -W -f='${Version}' phpldapadmin)|$(dpkg-query -W -f='${Version}' lighttpd)|$(dpkg-query -W -f='${Version}' php-fpm)|$(dpkg-query -W -f='${Version}' libldap-common)"
test "$after" = "$before"
grep -Rqs '^Suites: trixie' /etc/apt/sources.list.d
! grep -Rqi bookworm /etc/apt/sources.list.d

cat >"$result" <<EOF
package_source=Debian 13 Trixie APT repositories for OpenLDAP, ldap-utils, phpLDAPadmin, Lighttpd, PHP-FPM and LDAP client configuration; TurnKey APT for Webmin LDAP module
installed_version=slapd $slapd_version; ldap-utils $ldap_utils_version; phpldapadmin $phpldapadmin_version; lighttpd $lighttpd_version; php-fpm $php_version; libldap-common $libldap_version
runtime_checks=normal init; slapd, Lighttpd and PHP-FPM active; administrator LDAP and trusted LDAPS binds; default Users and Groups structure; LDAP add, search and delete round trip; phpLDAPadmin HTTPS interface; Webmin LDAP module
updater_command=apt-get update; apt-cache policy slapd ldap-utils phpldapadmin lighttpd php-fpm libldap-common
updater_result=signed metadata refreshed; eligible candidates found; installed versions unchanged
updater_channel=Debian Trixie and TurnKey Trixie APT repositories
integrity_evidence=APT accepted signed repository metadata through configured Deb822 sources and keyrings; no Bookworm source remained
EOF
