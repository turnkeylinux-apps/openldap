WEBMIN_FW_TCP_INCOMING = 22 80 389 443 636 12320 12321
WEBMIN_FW_UDP_INCOMING = 389 636

include $(FAB_PATH)/common/mk/turnkey/lighttpd.mk
include $(FAB_PATH)/common/mk/turnkey/php-fpm.mk
include $(FAB_PATH)/common/mk/turnkey.mk
