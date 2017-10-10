#!/system/bin/sh
# This script will be executed in post-fs-data mode
# More info in the main Magisk thread
SH=${0%/*}
MODID=<MODID>

# DETECT IS SUPERSU MOUNTED
supersu_is_mounted() {
  case `mount` in
    *" $1 "*) echo 1;;
    *) echo 0;;
  esac;
}

# MOUNT SUPERSU IMG
supersuimg_mount() {
  supersuimg=$(ls /cache/su.img /data/su.img 2>/dev/null)
  if [ "$supersuimg" ]; then
    if [ "$(supersu_is_mounted /su)" == 0 ]; then
      ui_print "   Mounting /su..."
      test ! -e /su && mkdir /su
      mount -t ext4 -o rw,noatime $supersuimg /su 2>/dev/null
      for i in 0 1 2 3 4 5 6 7; do
        test "$(supersu_is_mounted /su)" == 1 && break
        loop=/dev/block/loop$i
        mknod $loop b 7 $i
        losetup $loop $supersuimg
        mount -t ext4 -o loop $loop /su 2>/dev/null
      done
    fi
  fi
}

# DETERMINE ROOT BOOT SCRIPT TYPE
EXT=".sh"
AMLPATH=""
MAGISK=false
test -L /system/vendor && VEN=/vendor || VEN=/system/vendor
if [ -f /data/magisk.img ] || [ -f /cache/magisk.img ] || [ -d /magisk ]; then
  SYS=/system
  MAGISK=true
  SEINJECT=magiskpolicy
  test -d /magisk/audmodlib$SYS && { MAGISK=true; AMLPATH=/magisk/audmodlib; VEN=/system/vendor; }
else
  # DETERMINE IF PIXEL (A/B OTA) DEVICE
  if [ $(cat /proc/cmdline | grep slot_suffix | wc -l) -gt 0 ]; then
    test -d "/system_root" && SYS=/system_root/system || SYS=/system/system
  else
    SYS=/system
  fi
  supersuimg_mount
  if [ -d "/data/adb/su/bin" ]; then
    SEINJECT=/data/adb/su/bin/supolicy
  elif [ -d "/data/supersu_install/bin" ]; then
    SEINJECT=/data/supersu_install/bin/supolicy
  elif [ -d "/cache/supersu_install/bin" ]; then
    SEINJECT=/cache/supersu_install/bin/supolicy
  elif [ "$supersuimg" ] || [ -d /su ]; then
    SEINJECT=/su/bin/supolicy
  elif [ -d $SYS/su ] || [ -f $SYS/xbin/daemonsu ] || [ -f $SYS/xbin/sugote ]; then
    SEINJECT=$SYS/xbin/supolicy
  elif [ -f $SYS/xbin/su ]; then
    if [ "$(cat $SYS/xbin/su | grep SuperSU)" ]; then
      SEINJECT=$SYS/xbin/supolicy
    else
      SEINJECT=/sepolicy
      EXT=""
    fi
  else
    SEINJECT=/sepolicy
    EXT=""
  fi
fi

# XMLSTARLET
if [ "$MAGISK" == true ]; then
  XML_PRFX=$AMLPATH/system/xbin/xmlstarlet
elif [ "${SH%/*}" != "$SYS/etc" ]; then
  XML_PRFX=$AMLPATH${SH%/*}/xbin/xmlstarlet
else
  XML_PRFX=$AMLPATH$SYS/xbin/xmlstarlet
fi

# AUDIO EFFECTS
CONFIG_FILE=$AMLPATH$SYS/etc/audio_effects.conf
HTC_CONFIG_FILE=$AMLPATH$SYS/etc/htc_audio_effects.conf
OTHER_V_FILE=$AMLPATH$SYS/etc/audio_effects_vendor.conf
OFFLOAD_CONFIG=$AMLPATH$SYS/etc/audio_effects_offload.conf
V_CONFIG_FILE=$AMLPATH$VEN/etc/audio_effects.conf
# AUDIO POLICY
A2DP_AUD_POL=$AMLPATH$SYS/etc/a2dp_audio_policy_configuration.xml
AUD_POL=$AMLPATH$SYS/etc/audio_policy.conf
AUD_POL_CONF=$AMLPATH$SYS/etc/audio_policy_configuration.xml
AUD_POL_VOL=$AMLPATH$SYS/etc/audio_policy_volumes.xml
SUB_AUD_POL=$AMLPATH$SYS/etc/r_submix_audio_policy_configuration.xml
USB_AUD_POL=$AMLPATH$SYS/etc/usb_audio_policy_configuration.xml
V_AUD_OUT_POL=$AMLPATH$VEN/etc/audio_output_policy.conf
V_AUD_POL=$AMLPATH$VEN/etc/audio_policy.conf
# MIXER PATHS
MIX_PATH=$AMLPATH$SYS/etc/mixer_paths.xml
MIX_PATH_DTP=$AMLPATH$SYS/etc/mixer_paths_dtp.xml
MIX_PATH_i2s=$AMLPATH$SYS/etc/mixer_paths_i2s.xml
MIX_PATH_TASH=$AMLPATH$SYS/etc/mixer_paths_tasha.xml
STRIGG_MIX_PATH=$AMLPATH$SYS/sound_trigger_mixer_paths.xml
STRIGG_MIX_PATH_9330=$AMLPATH$SYS/sound_trigger_mixer_paths_wcd9330.xml
V_MIX_PATH=$AMLPATH$VEN/etc/mixer_paths.xml
 
test -d $AMLPATH$SYS/priv-app && SOURCE=priv_app || SOURCE=system_app

# CUSTOM USER SCRIPT