WEBMIN_FW_TCP_INCOMING = 22 80 389 443 636 12320 12321
WEBMIN_FW_UDP_INCOMING = 389 636

COMMON_OVERLAYS = lighttpd
COMMON_CONF = lighttpd-fastcgi

include $(FAB_PATH)/common/mk/turnkey/php.mk
include $(FAB_PATH)/common/mk/turnkey.mk
