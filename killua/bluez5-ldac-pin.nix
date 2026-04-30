# libldac-dec decoder-init fix for the killua (MSI Claw) host.
#
# pipewire 1.6.x's bluez5 LDAC codec links libldac-dec for the decoder
# path. The version currently in nixpkgs (libldac-dec 0.0.2-unstable-
# 2024-11-12, upstream rev 8c15f53) has a bug in
# ldacBT_init_handle_decode(): four struct members (cci, frmlen, cm,
# frm_status) are passed to ldaclib_set_config_info() *before* they're
# assigned, so it sees zero-initialised values from calloc. Decoder
# init fails with LDACBT_ERR_FATAL (268981248) and wireplumber refuses
# to bring up the LDAC codec.
#
# Fix: nixpkgs PR #502690 (merged 2026-03-23, after this flake's nixpkgs
# lock). The patch moves the four assignments before the
# ldaclib_set_config_info() call. We apply the same patch to
# pkgs.libldac-dec via overrideAttrs and override pipewire and
# wireplumber to take the patched libldac-dec.
#
# Approach matches NixOS Discourse thread "Bluetooth audio broken after
# recent update - Likely LDAC + PipeWire 1.6.2": override
# services.pipewire.package and services.pipewire.wireplumber.package
# rather than overlaying pkgs.libldac-dec, so the change is scoped to
# the pipewire/wireplumber service binaries and does *not* cascade into
# the rest of the closure (ffmpeg, gtk4, electron, …) the way an
# overlay would.
#
# Cost: pipewire and wireplumber rebuild from source (~5-10 min on this
# host) because their libldac-dec buildtime input changed. None of the
# downstream pipewire consumers rebuild.
#
# Caveat: this only addresses the libldac-dec init failure. There is a
# separate SIGSEGV in libspa-bluez5.so spa_bt_device_supports_media_codec()
# that triggers when wireplumber enumerates supported codecs (e.g. when
# you select LDAC); that one is fixed in pipewire 1.6.3 by upstream
# commit 99f901d and is *not* addressed here. If you hit it, switch to
# the bluez5/-subdir-swap approach instead.
{
  pkgs,
  ...
}: let
  fixDecodeInitPatch = pkgs.writeText "fix-decode-init.patch" ''
    --- a/src/ldacBT_api.o.c
    +++ b/src/ldacBT_api.o.c
    @@ -165,6 +165,10 @@
       // tbl_ldacbt_config[0].frmlen_1ch;
       // frmlen = 165 * channel - LDACBT_FRMHDRBYTES;
       frmlen = tbl_ldacbt_config[0].frmlen_1ch * channel - LDACBT_FRMHDRBYTES;
    +  hLdacBT->frmlen = frmlen;
    +  hLdacBT->cm = cm;
    +  hLdacBT->cci = cci;
    +  hLdacBT->frm_status = 0;
       /* Set Configuration Information */
       result = ldaclib_set_config_info(
           hLdacBT->hLDAC, hLdacBT->sfid, hLdacBT->cci, hLdacBT->frmlen, hLdacBT->frm_status);
    @@ -174,10 +178,6 @@
       } else if (result != LDAC_S_OK) {
         hLdacBT->error_code_api = LDACBT_GET_LDACLIB_ERROR_CODE;
       }
    -  hLdacBT->frmlen = frmlen;
    -  hLdacBT->cm = cm;
    -  hLdacBT->cci = cci;
    -  hLdacBT->frm_status = 0;
       hLdacBT->sfid = sfid;
       result = ldaclib_init_decode(hLdacBT->hLDAC, nshift);
       if (LDAC_FAILED(result)) {
  '';

  patchedLibldacDec = pkgs.libldac-dec.overrideAttrs (old: {
    pname = "libldac-dec-patched";
    patches = (old.patches or []) ++ [fixDecodeInitPatch];
  });

  patchedPipewire = pkgs.pipewire.override {libldac-dec = patchedLibldacDec;};
  patchedWireplumber = pkgs.wireplumber.override {pipewire = patchedPipewire;};
in {
  services.pipewire.package = patchedPipewire;
  services.pipewire.wireplumber.package = patchedWireplumber;
}
