#!/bin/bash
# Run before any firstboot input, once through external LDAP and again LDAPS.
# For LDAPS, provide the fixture CA and a hostname matching the certificate.
set -Eeuo pipefail
umask 077
uri=${TKL_TEST_LDAP_URI:?Set the externally reachable LDAP or LDAPS URI}
export LDAPTLS_REQCERT=demand
base=dc=example,dc=com
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

# Denial is meaningful only if this exact endpoint is responding normally.
ldapsearch -LLL -x -H "$uri" -b '' -s base namingContexts >"$work/rootdse"
grep -Fqi "namingContexts: $base" "$work/rootdse"
for dn in "cn=admin,$base" cn=config 'cn=admin,cn=config' \
        "cn=samba,$base" "cn=nsspam,$base"; do
    if ldapwhoami -x -H "$uri" -D "$dn" -w turnkey \
            >"$work/bind" 2>&1; then
        echo "Factory password unexpectedly authenticated $dn" >&2
        exit 1
    else
        status=$?
    fi
    test "$status" = 49 || { cat "$work/bind" >&2; exit 1; }
done

# No password-bearing entry, including root-DN fallback, may remain.
if ldapsearch -LLL -x -H "$uri" -b "$base" -s base dn \
        >"$work/base" 2>&1; then
    echo 'Factory DIT unexpectedly contains an entry before setup' >&2
    exit 1
else
    status=$?
fi
test "$status" = 32 || { cat "$work/base" >&2; exit 1; }

cat >"$work/add" <<EOF
dn: $base
objectClass: top
objectClass: dcObject
objectClass: organization
dc: example
o: Factory write denial control
EOF
if ldapadd -x -H "$uri" -f "$work/add" >"$work/write" 2>&1; then
    echo 'Anonymous factory write unexpectedly succeeded' >&2
    exit 1
else
    status=$?
fi
case "$status" in
    8|50|53) ;;
    *) cat "$work/write" >&2; exit 1 ;;
esac
cat >"$work/config" <<EOF
dn: cn=config
changetype: modify
replace: olcLogLevel
olcLogLevel: 0
EOF
if ldapmodify -x -H "$uri" -f "$work/config" >"$work/config-write" 2>&1; then
    echo 'Anonymous configuration-database write unexpectedly succeeded' >&2
    exit 1
else
    status=$?
fi
case "$status" in
    8|32|50|53) ;;
    *) cat "$work/config-write" >&2; exit 1 ;;
esac
printf 'PASS factory bind and write denial at %s\n' "$uri"
