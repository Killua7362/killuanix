# mautrix bridges — telegram, whatsapp, meta-instagram, meta-messenger.
#
# Architecture:
#   - All four bridges follow an identical shape; the bridge list below
#     parametrises image, ports, network-specific config keys, and sops
#     secret names. mkBridgeContainer / mkBridgeConfigService emit the
#     quadlet container and the oneshot config-render unit per bridge.
#
#   - On every boot, <bridge>-config.service writes two files:
#       /run/mautrix-<name>/config.yaml          (bridge reads this)
#       /var/lib/matrix-appservices/<name>.yaml  (synapse reads this)
#     Both contain the same as_token / hs_token from sops, so the
#     appservice handshake works without ever running `mautrix-<bridge> -g`.
#
#   - mautrix-meta is one image; instagram and messenger differ only in
#     `network.mode` (`instagram` vs `facebook`) and bot mxid.
#
# Tokens (32-byte hex, generated once, kept in sops; see matrix/CLAUDE.md):
#   matrix_bridge_<name>_as_token
#   matrix_bridge_<name>_hs_token
#   matrix_bridge_<name>_pickle_key
#   matrix_bridge_<name>_db_password
# Telegram-only:
#   matrix_bridge_telegram_api_id
#   matrix_bridge_telegram_api_hash
{
  pkgs,
  config,
  lib,
  ...
}: let
  sopsPath = name: config.sops.secrets.${name}.path;

  serverName = "matrix.killua.local";
  adminMxid = "@akshay:${serverName}";

  # Per-bridge knobs. Identifier (key) is used everywhere: container name,
  # systemd unit name, sops prefix, db name, volume name.
  bridges = {
    telegram = {
      image = "dock.mau.dev/mautrix/telegram:latest";
      botUsername = "telegrambot";
      botDisplayname = "Telegram bridge bot";
      asPort = 29317;
      usernamePrefix = "telegram"; # produces @telegram_<id>:server
      displayNameSuffix = "Telegram";
      networkConfig = ''
        network:
          api_id: $TELEGRAM_API_ID
          api_hash: "$TELEGRAM_API_HASH"
          bot_token: ""
          device_info:
            device_model: mautrix-telegram
            system_version: ""
            app_version: ""
            lang_code: en
            system_lang_code: en
          max_member_count: -1
          inline_buttons_as_text: true
      '';
    };
    whatsapp = {
      # Pinned to last pre-bridgev2 release — bridgev2 (v0.11+) requires
      # a different config schema and won't load legacy configs. Bump only
      # after rewriting this module's config block to bridgev2 layout.
      image = "dock.mau.dev/mautrix/whatsapp:v0.10.9";
      botUsername = "whatsappbot";
      botDisplayname = "WhatsApp bridge bot";
      asPort = 29318;
      usernamePrefix = "whatsapp";
      displayNameSuffix = "WhatsApp";
      networkConfig = ''
        network:
          os_name: mautrix-whatsapp
          browser_name: Mautrix-WhatsApp bridge
          history_sync:
            request_full_sync: false
            max_initial_conversations: 25
          displayname_template: '{{or .FullName .PushName .JID}}'
      '';
    };
    meta-instagram = {
      image = "dock.mau.dev/mautrix/meta:v0.4.2";
      botUsername = "instagrambot";
      botDisplayname = "Instagram bridge bot";
      asPort = 29319;
      usernamePrefix = "instagram";
      displayNameSuffix = "Instagram";
      networkConfig = ''
        network:
          mode: instagram
          displayname_template: '{{or .DisplayName .Username (printf "User %d" .ID)}}'
      '';
    };
    meta-messenger = {
      image = "dock.mau.dev/mautrix/meta:v0.4.2";
      botUsername = "messengerbot";
      botDisplayname = "Messenger bridge bot";
      asPort = 29320;
      usernamePrefix = "messenger";
      displayNameSuffix = "Messenger";
      networkConfig = ''
        network:
          mode: facebook
          displayname_template: '{{or .DisplayName .Username (printf "User %d" .ID)}}'
      '';
    };
  };

  sopsName = name: kind: "matrix_bridge_${builtins.replaceStrings ["-"] ["_"] name}_${kind}";
  dbRole = name: "mautrix_${builtins.replaceStrings ["-"] ["_"] name}";
  dbName = dbRole;
  volumeName = name: "mautrix_${builtins.replaceStrings ["-"] ["_"] name}_data";
  containerName = name: "mautrix-${name}";

  # Build a bridge-config oneshot service. Renders config.yaml + registration.yaml.
  mkConfigService = name: b: let
    cn = containerName name;
    pwSecret = sopsName name "db_password";
    asTokenSecret = sopsName name "as_token";
    hsTokenSecret = sopsName name "hs_token";
    pickleSecret = sopsName name "pickle_key";

    # Telegram needs the additional api_id/api_hash; other bridges don't.
    telegramExports =
      if name == "telegram"
      then ''
        TELEGRAM_API_ID="$(cat ${sopsPath "matrix_bridge_telegram_api_id"})"
        TELEGRAM_API_HASH="$(cat ${sopsPath "matrix_bridge_telegram_api_hash"})"
      ''
      else "";

    userRegex = "@${b.usernamePrefix}_.*:${lib.escapeRegex serverName}";
    botRegex = "@${b.botUsername}:${lib.escapeRegex serverName}";
  in {
    description = "Render mautrix-${name} config + registration from sops";
    wantedBy = ["multi-user.target"];
    before = ["${cn}.service" "synapse.service"];
    after = ["matrix-postgres-ready.service"];
    requires = ["matrix-postgres-ready.service"];
    path = [pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = cn;
      RuntimeDirectoryMode = "0750";
    };
    script = ''
      set -eu
      umask 027

      DB_PW="$(cat ${sopsPath pwSecret})"
      AS_TOKEN="$(cat ${sopsPath asTokenSecret})"
      HS_TOKEN="$(cat ${sopsPath hsTokenSecret})"
      PICKLE_KEY="$(cat ${sopsPath pickleSecret})"
      ${telegramExports}

      install -d -m 0755 /var/lib/matrix-appservices

      cat > /run/${cn}/config.yaml <<EOF
      # Auto-rendered by ${cn}-config.service. Edits will not survive.
      homeserver:
        address: http://synapse:8008
        domain: ${serverName}
        software: standard
        async_media: false
        media_proxy: false
        max_upload_size: 4294967296

      appservice:
        address: http://${cn}:${toString b.asPort}
        hostname: 0.0.0.0
        port: ${toString b.asPort}
        database:
          type: postgres
          uri: postgres://${dbRole name}:$DB_PW@matrix-postgres/${dbName name}?sslmode=disable
          max_open_conns: 20
          max_idle_conns: 2
        id: ${name}
        bot:
          username: ${b.botUsername}
          displayname: ${b.botDisplayname}
          avatar: ""
        ephemeral_events: true
        as_token: "$AS_TOKEN"
        hs_token: "$HS_TOKEN"

      ${b.networkConfig}

      bridge:
        # Tells bridgev2-flavored bridges (whatsapp, meta) to accept our
        # legacy-style config sections instead of refusing to start.
        hacky_network_config_migrator: true
        username_template: "${b.usernamePrefix}_{{.}}"
        displayname_template: '{{.}} (${b.displayNameSuffix})'
        personal_filtering_spaces: true
        delivery_receipts: false
        message_status_events: false
        message_error_notices: true
        # Don't forward your Matrix read receipts to remote network — WhatsApp
        # blue ticks / Telegram read indicator won't trigger when you read in Element.
        sync_manual_marked_unread: false
        read_receipts: false
        sync_with_custom_puppets: true
        permissions:
          "*": relay
          "${serverName}": user
          "${adminMxid}": admin
        encryption:
          allow: true
          default: true
          require: false
          appservice: true
          msc4190: true
          allow_key_sharing: true
          plaintext_mentions: false
          delete_keys:
            delete_outbound_on_ack: false
            dont_store_outbound: false
            ratchet_on_decrypt: false
            delete_fully_used_on_decrypt: false
            delete_prev_on_new_session: false
            delete_on_device_delete: false
            periodically_delete_expired: false
            delete_outdated_inbound: false
          pickle_key: "$PICKLE_KEY"
          rotation:
            enable_custom: false
            milliseconds: 604800000
            messages: 100
            disable_device_change_key_rotation: false
        relay:
          enabled: false
        cleanup_rooms_on_logout: false
        backfill:
          enabled: false
        portal_event_buffer: 1024

      logging:
        min_level: info
        writers:
          - type: stdout
            format: pretty-colored
      EOF

      cat > /var/lib/matrix-appservices/${name}.yaml <<EOF
      # Auto-rendered by ${cn}-config.service. Synapse loads via app_service_config_files.
      id: ${name}
      url: http://${cn}:${toString b.asPort}
      as_token: "$AS_TOKEN"
      hs_token: "$HS_TOKEN"
      sender_localpart: ${b.botUsername}
      rate_limited: false
      namespaces:
        users:
          - exclusive: true
            regex: '${userRegex}'
          - exclusive: true
            regex: '${botRegex}'
        aliases: []
        rooms: []
      de.sorunome.msc2409.push_ephemeral: true
      push_ephemeral: true
      org.matrix.msc3202: true
      org.matrix.msc4190: true
      EOF

      chmod 0644 /var/lib/matrix-appservices/${name}.yaml
      chmod 0644 /run/${cn}/config.yaml
    '';
  };

  mkContainer = name: b: let
    cn = containerName name;
    cfgService = "${cn}-config.service";
  in {
    autoStart = false;

    containerConfig = {
      image = b.image;
      networks = ["matrix-net"];
      volumes = [
        "${volumeName name}:/data:z"
        # Not :ro — telegram bridge image chowns /data/* on entrypoint;
        # readonly mount triggers `Read-only file system` failure.
        "/run/${cn}/config.yaml:/data/config.yaml:z"
      ];
      labels = ["io.containers.autoupdate=registry"];
    };

    serviceConfig = {
      Restart = "always";
      TimeoutStartSec = 300;
    };

    unitConfig = {
      Description = "mautrix-${name} bridge";
      After = [
        "network-online.target"
        "podman.socket"
        "matrix-postgres-ready.service"
        "synapse.service"
        cfgService
      ];
      Requires = [
        "podman.socket"
        "matrix-postgres-ready.service"
        "synapse.service"
        cfgService
      ];
    };
  };
in {
  virtualisation.quadlet.containers =
    lib.mapAttrs' (name: b: lib.nameValuePair (containerName name) (mkContainer name b)) bridges;

  systemd.services =
    lib.mapAttrs' (name: b: lib.nameValuePair "${containerName name}-config" (mkConfigService name b)) bridges;
}
