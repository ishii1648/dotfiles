#!/bin/bash
# マニフェスト読み込み・プロファイル検証

# マニフェストを読み込み MANIFEST_JSON をセットする
load_manifest() {
    local manifest="$1"
    local manifest_local="${manifest%.yml}.local.yml"

    if [[ -f "$manifest_local" ]]; then
        MANIFEST_JSON=$(python3 -c "
import yaml, json, sys
def deep_merge(base, overlay):
    for k, v in overlay.items():
        if k in base and isinstance(base[k], dict) and isinstance(v, dict):
            deep_merge(base[k], v)
        else:
            base[k] = v
    return base
base = yaml.safe_load(open(sys.argv[1]))
overlay = yaml.safe_load(open(sys.argv[2]))
print(json.dumps(deep_merge(base, overlay)))
" "$manifest" "$manifest_local")
    else
        MANIFEST_JSON=$(python3 -c "import yaml,json,sys; print(json.dumps(yaml.safe_load(open(sys.argv[1]))))" "$manifest")
    fi
}

# プロファイルを検証し COMPONENT_LIST をセットする
validate_profile() {
    local profile="$1"

    COMPONENT_LIST=$(echo "$MANIFEST_JSON" | jq -r --arg p "$profile" '.profiles[$p] // empty | .[]')
    if [[ -z "$COMPONENT_LIST" ]]; then
        echo "Error: Unknown profile: $profile" >&2
        echo "Available profiles: $(echo "$MANIFEST_JSON" | jq -r '.profiles | keys | join(", ")')" >&2
        exit 1
    fi
}
