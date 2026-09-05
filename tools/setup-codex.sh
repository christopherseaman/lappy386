#!/bin/bash

# Codex setup for user-scoped MCP servers and the Ponytail plugin.
# This script configures Codex's ~/.codex/config.toml; it does not modify Claude's MCP state.

set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

CODEX_COMMAND="$(command -v codex || true)"
if [ -z "$CODEX_COMMAND" ]; then
    echo "Codex CLI not found on PATH. Run setup-cli.sh first." >&2
    exit 1
fi

echo "=== Codex Setup Script ==="
echo "This script configures Codex MCP servers and the Ponytail plugin."
echo ""

remove_mcp_server() {
    local name="$1"
    "$CODEX_COMMAND" mcp remove "$name" >/dev/null 2>&1 || true
}

setup_notion() {
    echo "=== Setting up Notion MCP ==="
    echo ""

    remove_mcp_server notion
    "$CODEX_COMMAND" mcp add notion --url https://mcp.notion.com/mcp

    echo "Authenticate with Notion in the browser that Codex opens."
    "$CODEX_COMMAND" mcp login notion

    echo "✓ Notion MCP server configured successfully!"
    echo ""
}

setup_atlassian() {
    echo "=== Setting up Atlassian MCP ==="
    echo ""
    echo "This uses Atlassian Rovo MCP's OAuth flow for user-scoped access."
    echo ""

    remove_mcp_server atlassian
    "$CODEX_COMMAND" mcp add atlassian --url https://mcp.atlassian.com/v2/mcp

    echo "Authenticate with Atlassian in the browser that Codex opens."
    "$CODEX_COMMAND" mcp login atlassian

    echo "✓ Atlassian MCP server configured successfully!"
    echo ""
}

setup_ucsf_confluence() {
    echo "=== Setting up UCSF Confluence MCP ==="
    echo ""
    echo "Uses sooperset/mcp-atlassian via uvx against the UCSF Data Center instance."
    echo "Requires uv and network reachability to wiki.library.ucsf.edu (campus VPN)."
    echo ""

    local pat="${UCSF_CONFLUENCE_PAT:-}"
    if [ -z "$pat" ]; then
        read -r -s -p "Enter your UCSF Confluence Personal Access Token: " pat
        echo ""
    fi

    if [ -z "$pat" ]; then
        echo "No PAT provided. Skipping UCSF Confluence setup."
        echo ""
        return 0
    fi

    remove_mcp_server ucsf-confluence
    "$CODEX_COMMAND" mcp add ucsf-confluence \
        --env "CONFLUENCE_URL=https://wiki.library.ucsf.edu" \
        --env "CONFLUENCE_PERSONAL_TOKEN=$pat" \
        -- uvx mcp-atlassian

    echo "✓ UCSF Confluence MCP server configured successfully!"
    echo ""
}

setup_ponytail() {
    echo "=== Setting up Ponytail Codex plugin ==="
    echo ""

    local marketplaces
    marketplaces="$("$CODEX_COMMAND" plugin marketplace list)"
    if ! printf '%s\n' "$marketplaces" | grep -Eq '^[[:space:]]*ponytail[[:space:]]'; then
        "$CODEX_COMMAND" plugin marketplace add DietrichGebert/ponytail
    fi

    if ! "$CODEX_COMMAND" plugin list --json 2>/dev/null \
        | grep -Eq '"pluginId"[[:space:]]*:[[:space:]]*"ponytail@ponytail"'; then
        "$CODEX_COMMAND" plugin add ponytail@ponytail
    fi

    if command -v node >/dev/null 2>&1; then
        echo "Node: available; Ponytail lifecycle hooks can run."
    else
        echo "Warning: node is not on PATH; Ponytail skills install, but lifecycle hooks stay inactive."
    fi
    echo "Review and trust Ponytail's hooks in Codex with /hooks, then start a new session."
    echo "✓ Ponytail plugin configured successfully!"
    echo ""
}

echo "Which Codex components would you like to configure?"
echo "1) Notion only"
echo "2) Atlassian only (OAuth)"
echo "3) UCSF Confluence only (self-hosted, PAT)"
echo "4) Ponytail only"
echo "5) All: Notion, Atlassian, UCSF Confluence, and Ponytail"
echo ""
read -r -p "Enter your choice (1-5): " choice

case "$choice" in
    1)
        setup_notion
        ;;
    2)
        setup_atlassian
        ;;
    3)
        setup_ucsf_confluence
        ;;
    4)
        setup_ponytail
        ;;
    5)
        setup_notion
        setup_atlassian
        setup_ucsf_confluence
        setup_ponytail
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo "=== Codex Setup Complete ==="
echo ""
echo "Verify MCP servers with: codex mcp list"
echo "Verify plugins with: codex plugin list"
echo "Codex MCP configuration is stored in ~/.codex/config.toml."
