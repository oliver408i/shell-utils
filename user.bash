#!/bin/bash

# Define variables
GITHUB_URL="https://raw.githubusercontent.com/oliver408i/shell-utils/refs/heads/main/alias.json"
JSON_FILE="aliases.json"
if [ -n "$ZSH_VERSION" ]; then
    ALIAS_FILE="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    ALIAS_FILE="$HOME/.bashrc"
else
    echo "Unsupported shell. Please use Bash or Zsh."
    exit 1
fi
INSTALLED_FILE="$HOME/.installed_aliases"

touch "$INSTALLED_FILE"  # File to keep track of installed aliases

# Fetch JSON file
fetch_json() {
    echo "Fetching alias JSON from GitHub..."
    curl -s -o "$JSON_FILE" "$GITHUB_URL"
    if [[ $? -ne 0 ]]; then
        echo "Failed to fetch JSON file. Check the URL and your internet connection."
        exit 1
    fi
}

# Display terminal-based menu
show_menu() {
    echo "\nAlias Manager"
    echo "================================="
    echo "Available aliases:"

    local options=()
    local index=1
    
    while IFS= read -r alias; do
        key=$(echo "$alias" | awk -F' - ' '{print $1}')
        desc=$(echo "$alias" | awk -F' - ' '{print $2}')

        # Check if alias is installed
        if grep -q "$key" "$INSTALLED_FILE"; then
            options+=("$key [INSTALLED]" "$index")
            echo "  $index) $key [INSTALLED] - $desc"
        else
            options+=("$key" "$index")
            echo "  $index) $key - $desc"
        fi
        index=$((index + 1))
    done <<< "$(jq -r '.alias | to_entries[] | "\(.key) - \(.value.description)"' "$JSON_FILE")"

    echo "\nChoose an alias by entering its number, or press 'q' to quit: "
    read -r choice

    if [[ "$choice" == "q" ]]; then
        exit 0
    elif [[ "$choice" =~ ^[0-9]+$ ]]; then
        local selected_alias
        selected_alias=$(jq -r ".alias | to_entries[$((choice - 1))].key" "$JSON_FILE")
        if [[ -n "$selected_alias" ]]; then
            manage_alias "$selected_alias"
        else
            echo "Invalid selection."
        fi
    else
        echo "Invalid input."
    fi
}

# Install an alias
install_alias() {
    local alias_name="$1"
    local command
    command=$(jq -r ".alias[\"$alias_name\"].command" "$JSON_FILE")

    if ! grep -q "$alias_name" "$INSTALLED_FILE"; then
        echo "# Alias: $alias_name" >> "$ALIAS_FILE"
        echo "$command" >> "$ALIAS_FILE"
        echo "$alias_name" >> "$INSTALLED_FILE"
        echo "Alias '$alias_name' installed successfully."
    else
        echo "Alias '$alias_name' is already installed."
    fi
}

# Remove an alias
remove_alias() {
    local alias_name="$1"

    if grep -q "$alias_name" "$INSTALLED_FILE"; then
        # Remove from alias file
        sed -i "/# Alias: $alias_name/,+1d" "$ALIAS_FILE"
        # Remove from installed list
        sed -i "/$alias_name/d" "$INSTALLED_FILE"
        echo "Alias '$alias_name' removed successfully."
    else
        echo "Alias '$alias_name' is not installed."
    fi
}

# Manage alias
manage_alias() {
    local alias_name="$1"
    echo "\nManaging Alias: $alias_name"
    echo "================================="
    echo "1) Install Alias"
    echo "2) Remove Alias"
    echo "3) Show Alias Info"
    echo "4) Back to Menu"
    echo -n "Choose an action: "
    read -r action

    case "$action" in
        1)
            install_alias "$alias_name"
            ;;
        2)
            remove_alias "$alias_name"
            ;;
        3)
            jq -r ".alias[\"$alias_name\"] | \"Description: \(.description)\nCommand: \(.command)\nCategory: \(.category)\nOS: \(.os | join(", "))\"" "$JSON_FILE"
            read -p "Press Enter to return to menu..."
            ;;
        4)
            return
            ;;
        *)
            echo "Invalid option."
            ;;
    esac
}

# Main logic
fetch_json
while true; do
    show_menu
done
