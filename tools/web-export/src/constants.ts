/** Godot preset name in `game/export_presets.cfg`. */
export const WEB_PRESET_NAME = "Web";

/** Export directory relative to the repo root. gitignored. */
export const EXPORT_RELATIVE_DIR = "export/web";

/** `--export-release` output path, relative to `game/` (matches the README). */
export const EXPORT_OUTPUT_FROM_GAME = "../export/web/index.html";

/**
 * Conventional VPS directory. Not a machine address. Nginx `root` and
 * `CRAFTARENA_WEB_DEPLOY_PATH` must stay the same string.
 */
export const DEFAULT_REMOTE_PATH = "/var/www/craftarena-web";

export const DEPLOY_HOST_ENV = "CRAFTARENA_WEB_DEPLOY_HOST";
export const DEPLOY_USER_ENV = "CRAFTARENA_WEB_DEPLOY_USER";
export const DEPLOY_PATH_ENV = "CRAFTARENA_WEB_DEPLOY_PATH";
export const DEPLOY_SSH_PORT_ENV = "CRAFTARENA_WEB_DEPLOY_SSH_PORT";
