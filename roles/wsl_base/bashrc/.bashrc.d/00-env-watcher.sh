# Add to ~/.bashrc
# Reload source: source ~/.bashrc
#
# --- Auto-load per-project .env.local (~/code/<project>/.env.local) ---
# Loads and exports variables from `.env.local` for the current project under `~/code/`.
# Additionally:
# - cleans variables when leaving the project (or switching to another project),
# - reloads variables when entering back.
#
# Note: `source` executes the file in the current shell; keep `.env.local` trusted.
__code_env_local_unload() {
if [ "${__CODE_ENV_LOCAL_LOADED_FOR:-}" = "" ]; then
return 0
fi

    # Backward-compatibility: if keys list is missing/empty (e.g. after upgrading
    # this snippet in an already running shell), derive keys from the env file.
    if ! declare -p __CODE_ENV_LOCAL_KEYS >/dev/null 2>&1 || [ "${#__CODE_ENV_LOCAL_KEYS[@]}" -eq 0 ]; then
        local fallback_env_file="${__CODE_ENV_LOCAL_LOADED_FOR}/.env.local"
        if [ -f "$fallback_env_file" ]; then
            __CODE_ENV_LOCAL_KEYS=()

            local line trimmed key
            while IFS= read -r line || [ -n "$line" ]; do
                line="${line%$'\r'}"
                trimmed="${line#"${line%%[![:space:]]*}"}"

                [ -z "$trimmed" ] && continue
                case "$trimmed" in
                    \#*) continue ;;
                esac

                case "$trimmed" in
                    export[[:space:]]*) trimmed="${trimmed#export }" ;;
                esac

                case "$trimmed" in
                    *=*)
                        key="${trimmed%%=*}"
                        key="${key%"${key##*[![:space:]]}"}"
                        key="${key#"${key%%[![:space:]]*}"}"
                        if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                            __CODE_ENV_LOCAL_KEYS+=("$key")
                        fi
                        ;;
                esac
            done < "$fallback_env_file"
        fi
    fi

    local keys_count=0
    if declare -p __CODE_ENV_LOCAL_KEYS >/dev/null 2>&1; then
        keys_count=${#__CODE_ENV_LOCAL_KEYS[@]}
    fi

    if [ "$keys_count" -gt 0 ]; then
        local key
        for key in "${__CODE_ENV_LOCAL_KEYS[@]}"; do
            unset "$key"
        done
    fi

    __CODE_ENV_LOCAL_LOADED_FOR=""
    __CODE_ENV_LOCAL_KEYS=()
}

__code_env_local_load() {
local project_root="$1"
local env_file="$2"

    __CODE_ENV_LOCAL_KEYS=()

    # Collect variable names defined in the env file so we can unset them later.
    # We only need the KEY from lines like:
    # - KEY=VALUE
    # - export KEY=VALUE
    local line trimmed key
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        trimmed="${line#"${line%%[![:space:]]*}"}"

        [ -z "$trimmed" ] && continue
        case "$trimmed" in
            \#*) continue ;;
        esac

        case "$trimmed" in
            export[[:space:]]*) trimmed="${trimmed#export }" ;;
        esac

        case "$trimmed" in
            *=*)
                key="${trimmed%%=*}"
                key="${key%"${key##*[![:space:]]}"}"
                key="${key#"${key%%[![:space:]]*}"}"
                if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
                    __CODE_ENV_LOCAL_KEYS+=("$key")
                fi
                ;;
        esac
    done < "$env_file"

    set -a
    # shellcheck disable=SC1090
    . "$env_file"
    set +a

    __CODE_ENV_LOCAL_LOADED_FOR="$project_root"
}

__code_project_env_local_autoload() {
local code_root="$HOME/code"
local project_root=""
local env_file=""

    case "$PWD" in
        "$code_root"/*)
            local relative_path="${PWD#"$code_root"/}"
            local project_name="${relative_path%%/*}"
            project_root="$code_root/$project_name"
            env_file="$project_root/.env.local"
            ;;
        *)
            project_root=""
            env_file=""
            ;;
    esac

    # Leaving project (or switching project) -> unload previously loaded vars.
    if [ "${__CODE_ENV_LOCAL_LOADED_FOR:-}" != "" ] && [ "$project_root" != "${__CODE_ENV_LOCAL_LOADED_FOR:-}" ]; then
        __code_env_local_unload
    fi

    # Entering project -> load vars if file exists and not loaded yet.
    if [ "$project_root" != "" ] && [ -f "$env_file" ] && [ "${__CODE_ENV_LOCAL_LOADED_FOR:-}" != "$project_root" ]; then
        __code_env_local_load "$project_root" "$env_file"
    fi

    # Backward-compatibility: if we are in the project and it's marked as loaded,
    # but we don't have a key list (e.g. after updating this snippet mid-session),
    # reload once to capture keys for proper unloading.
    if [ "$project_root" != "" ] && [ -f "$env_file" ] && [ "${__CODE_ENV_LOCAL_LOADED_FOR:-}" = "$project_root" ]; then
        if ! declare -p __CODE_ENV_LOCAL_KEYS >/dev/null 2>&1 || [ "${#__CODE_ENV_LOCAL_KEYS[@]}" -eq 0 ]; then
            __code_env_local_load "$project_root" "$env_file"
        fi
    fi
}

PROMPT_COMMAND="__code_project_env_local_autoload${PROMPT_COMMAND:+; $PROMPT_COMMAND}"