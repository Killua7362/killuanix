{
  config,
  pkgs,
  lib,
  ...
}: let
  p = config.theme.palette;

  # Heavy dark-scheme override for Ferdium.
  # Ferdium clobbers config.json / services.json on every launch, so
  # custom.css is the only declarative surface for theming. Selectors
  # target the Ferdium shell (sidebar + top bar + service tabs +
  # settings panels). Per-service webviews ignore custom.css.
  customCss = ''
    /* Generated from config.theme.palette — do not edit by hand. */

    :root {
      --killua-bg: ${p.bg};
      --killua-bg-low: ${p.surface_low};
      --killua-bg-alt: ${p.surface};
      --killua-bg-high: ${p.surface_high};
      --killua-fg: ${p.fg};
      --killua-fg-bright: ${p.fg_bright};
      --killua-fg-dim: ${p.fg_dim};
      --killua-fg-muted: ${p.fg_muted};
      --killua-accent: ${p.color4};
      --killua-outline: ${p.outline};
      --killua-error: ${p.error};
      --killua-sel-bg: ${p.selection_bg};
      --killua-sel-fg: ${p.selection_fg};
    }

    /* App shell */
    body,
    .app,
    .app .app__content,
    .app__service,
    .services,
    .darwin .app .app__content {
      background-color: var(--killua-bg) !important;
      color: var(--killua-fg) !important;
    }

    /* Sidebar (service strip) */
    .sidebar,
    .sidebar__options {
      background-color: var(--killua-bg-low) !important;
      border-right: 1px solid var(--killua-outline) !important;
    }

    .sidebar .tab-item {
      color: var(--killua-fg-dim) !important;
      border-left: 3px solid transparent !important;
      background: transparent !important;
    }

    .sidebar .tab-item:hover {
      background-color: var(--killua-bg-alt) !important;
      color: var(--killua-fg-bright) !important;
    }

    .sidebar .tab-item.is-active {
      background-color: var(--killua-bg-alt) !important;
      border-left-color: var(--killua-accent) !important;
      color: var(--killua-fg-bright) !important;
    }

    .sidebar .tab-item .tab-item__icon,
    .sidebar .tab-item .tab-item__label {
      color: inherit !important;
    }

    /* Unread badges */
    .tab-item__message-count,
    .tab-item__message-count--unread {
      background-color: var(--killua-accent) !important;
      color: var(--killua-bg) !important;
    }

    .tab-item__message-count--direct {
      background-color: var(--killua-error) !important;
      color: var(--killua-fg-bright) !important;
    }

    /* Top bar / titlebar */
    .titlebar,
    .titlebar-inverted,
    .app .app__service-icons {
      background-color: var(--killua-bg-low) !important;
      color: var(--killua-fg) !important;
      border-bottom: 1px solid var(--killua-outline) !important;
    }

    /* Settings + preferences panes */
    .settings,
    .settings__main,
    .settings__body,
    .settings-navigation,
    .settings__container,
    .recipes,
    .recipes__list,
    .recipe-teaser,
    .service-table,
    .workspaces-drawer {
      background-color: var(--killua-bg) !important;
      color: var(--killua-fg) !important;
    }

    .settings-navigation .settings-navigation__link {
      color: var(--killua-fg-dim) !important;
    }

    .settings-navigation .settings-navigation__link.is-active,
    .settings-navigation .settings-navigation__link:hover {
      background-color: var(--killua-bg-alt) !important;
      color: var(--killua-fg-bright) !important;
    }

    /* Headings + dividers in settings */
    .settings h1,
    .settings h2,
    .settings h3 {
      color: var(--killua-fg-bright) !important;
      border-bottom-color: var(--killua-outline) !important;
    }

    /* Inputs / buttons */
    .franz-form__input,
    .franz-form__select select,
    .franz-form__textarea,
    input[type="text"],
    input[type="email"],
    input[type="password"],
    input[type="search"],
    textarea,
    select {
      background-color: var(--killua-bg-alt) !important;
      color: var(--killua-fg-bright) !important;
      border: 1px solid var(--killua-outline) !important;
    }

    .franz-form__input:focus,
    input:focus,
    textarea:focus,
    select:focus {
      border-color: var(--killua-accent) !important;
      outline: none !important;
    }

    .franz-form__button,
    .button {
      background-color: var(--killua-bg-high) !important;
      color: var(--killua-fg-bright) !important;
      border: 1px solid var(--killua-outline) !important;
    }

    .franz-form__button--primary,
    .button--primary,
    .franz-form__button--inverted {
      background-color: var(--killua-accent) !important;
      color: var(--killua-bg) !important;
      border-color: var(--killua-accent) !important;
    }

    .franz-form__button:hover {
      filter: brightness(1.1);
    }

    /* Recipe cards (Add a Service grid) */
    .recipe-teaser {
      background-color: var(--killua-bg-alt) !important;
      border: 1px solid var(--killua-outline) !important;
      color: var(--killua-fg) !important;
    }

    .recipe-teaser:hover {
      border-color: var(--killua-accent) !important;
    }

    .recipe-teaser .recipe-teaser__label {
      color: var(--killua-fg-bright) !important;
    }

    /* Workspaces drawer */
    .workspaces-drawer__item,
    .workspaces-drawer__item--active {
      background-color: var(--killua-bg-alt) !important;
      color: var(--killua-fg) !important;
      border-color: var(--killua-outline) !important;
    }

    .workspaces-drawer__item--active {
      border-left: 3px solid var(--killua-accent) !important;
      color: var(--killua-fg-bright) !important;
    }

    /* Selection */
    ::selection {
      background-color: var(--killua-sel-bg) !important;
      color: var(--killua-sel-fg) !important;
    }

    /* Scrollbars */
    ::-webkit-scrollbar {
      width: 8px;
      height: 8px;
    }
    ::-webkit-scrollbar-track {
      background: var(--killua-bg-low);
    }
    ::-webkit-scrollbar-thumb {
      background: var(--killua-bg-high);
      border-radius: 4px;
    }
    ::-webkit-scrollbar-thumb:hover {
      background: var(--killua-outline);
    }

    /* Misc dividers + tooltips */
    hr,
    .divider {
      border-color: var(--killua-outline) !important;
      background-color: var(--killua-outline) !important;
    }

    .tooltip,
    [class*="tooltip"] {
      background-color: var(--killua-bg-high) !important;
      color: var(--killua-fg-bright) !important;
      border: 1px solid var(--killua-outline) !important;
    }
  '';
in {
  config = lib.mkIf pkgs.stdenv.isLinux {
    home.packages = [pkgs.ferdium];

    xdg.configFile."Ferdium/config/custom.css".text = customCss;
  };
}
