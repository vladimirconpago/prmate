#!/bin/bash

# Ensure the script exits on any error
set -e

INSTALL_DIR="$HOME/.tools"
SCRIPT_NAME="prmate.sh"
SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"
GITHUB_RAW_URL="https://raw.githubusercontent.com/vladimirconpago/prmate/master/prmate.sh"
GITHUB_INSTALLER_URL="https://raw.githubusercontent.com/vladimirconpago/prmate/master/install.sh"
# Function to get the SHA fingerprint of a file
get_sha_fingerprint() {
    if command -v shasum &> /dev/null; then
        shasum -a 256 "$1" | awk '{print $1}'
    elif command -v sha256sum &> /dev/null; then
        sha256sum "$1" | awk '{print $1}'
    else
        echo "❌ SHA256 command not found."
        exit 1
    fi
}

# Function to check for updates
check_for_updates() {
    echo "🔍 Checking for updates..."
    
    # Fetch latest script SHA from GitHub
    LATEST_SHA=$(curl -sSL "$GITHUB_RAW_URL" | shasum -a 256 | awk '{print $1}')

    # Compute local script SHA
    LOCAL_SHA=$(get_sha_fingerprint "$SCRIPT_PATH")

    if [[ "$LATEST_SHA" != "$LOCAL_SHA" ]]; then
        echo "🔔 A new version of PRMate is available!"
        read -rp "Do you want to update now? (y/n): " CONFIRM
        if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
            echo "⬇️ Installing new version..."
            prmate reinstall
            echo "✅ PRMate updated successfully! Restart your shell or run 'prmate' again."
            exit 0
        else
            echo "⚠️ Skipping update. You can update manually later."
        fi
    else
        echo "✅ PRMate is up to date."
    fi
}

# Function to reinstall PRMate
reinstall_prmate() {
    echo "⬇️ Fetching the latest version of PRMate..."
    curl -sSL "$GITHUB_INSTALLER_URL" | bash
    echo "✅ PRMate has been reinstalled successfully!"
    exit 0
}

if [[ "$1" == "reinstall" ]]; then
    reinstall_prmate
fi

# Call the update checker at script startup
check_for_updates

echo "🤝 Running PRMate..." 

# Default branch is the current branch
BRANCH=$(git branch --show-current)
DRY_RUN=false

# Function to display usage instructions
usage() {
    echo "Usage: $0 [-b <branch>] [--dry-run]"
    echo "  -b  Specify a branch (default: current branch)"
    echo "  --dry-run  Preview PR body without creating PR"
    exit 1
}

# Parse optional flags
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -b) BRANCH="$2"; shift ;;
        --dry-run) DRY_RUN=true ;;
        *) usage ;;
    esac
    shift
done

# Ensure `gh` CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed."
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Ensure `git` CLI is installed
if ! command -v git &> /dev/null; then
    echo "❌ Git CLI is not installed."
    echo "Install it from: https://git-scm.com/"
    exit 1
fi

# Ensure the branch exists
if ! git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "❌ Branch '$BRANCH' does not exist."
    exit 1
fi

# Prompt user for Fibery Title
read -rp "Enter Fibery Title: " FIBERY_TITLE

# Prompt user for Fibery Task Link
read -rp "Enter Fibery Task Link: " FIBERY_TASK

# Get GitHub repo URL
GITHUB_REPO_URL=$(git remote get-url origin | sed -E 's#(git@|https://)([^:/]+)[:/]([^/]+)/([^/.]+).*#https://\2/\3/\4#')

# Fetch commit messages with hashes
COMMIT_MESSAGES=$(git log --pretty=format:"%h %s%n%b" origin/develop..$BRANCH)

# Check if there are commits
if [ -z "$COMMIT_MESSAGES" ]; then
    echo "❌ No new commits to create a PR from branch '$BRANCH'."
    exit 1
fi

# Mapping commit types to emoji icons
declare -A EMOJI_MAP=(
    ["feat"]="✨ Features"
    ["fix"]="🐛 Bug Fixes"
    ["docs"]="📝 Documentation"
    ["style"]="🎨 Code Style"
    ["refactor"]="♻️ Refactoring"
    ["perf"]="⚡ Performance"
    ["test"]="✅ Tests"
    ["build"]="🏗️ Build System"
    ["ci"]="🚀 CI/CD"
    ["chore"]="🧹 Chores"
    ["revert"]="⏪ Reverts"
)

# Group commit messages by scope first
declare -A GROUPED_SCOPES
UNCATEGORIZED_COMMITS=""
BREAKING_CHANGES=""

while IFS= read -r commit; do
    COMMIT_HASH=$(echo "$commit" | awk '{print $1}')
    COMMIT_MESSAGE=$(echo "$commit" | cut -d' ' -f2-)
    FULL_COMMIT_MESSAGE=$(git show --no-patch --format=%B "$COMMIT_HASH") # Get full commit message body

    # Extract type and scope
    if [[ $COMMIT_MESSAGE =~ ^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(([^\)]+)\))?(!)?: ]]; then
        commit_type="${BASH_REMATCH[1]}"
        commit_scope="${BASH_REMATCH[3]}"
    else
        commit_type="other"
        commit_scope="Uncategorized"
    fi

    # Remove prefix from commit message
    clean_message=$(echo "$COMMIT_MESSAGE" | sed -E 's/^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([^\)]+\))?(!)?: //')

    # Create GitHub commit link
    commit_link="[$clean_message]($GITHUB_REPO_URL/commit/$COMMIT_HASH)"

    # Identify actual breaking changes (commit must contain "BREAKING CHANGE:")
    if echo "$FULL_COMMIT_MESSAGE" | grep -q "BREAKING CHANGE:"; then
        BREAKING_CHANGES+="- ⚠️ $commit_link"$'\n'
    elif [[ "$commit_type" == "other" ]]; then
        UNCATEGORIZED_COMMITS+="- 🗑️ $commit_link"$'\n'
    else
        GROUPED_SCOPES["$commit_scope"]+="- ${EMOJI_MAP[$commit_type]} $commit_link"$'\n'
    fi
done <<< "$COMMIT_MESSAGES"

# Build the PR body with grouped commits
PR_BODY="## Description"$'\n\n'

# Add breaking changes only if they exist
if [[ -n "$BREAKING_CHANGES" ]]; then
    PR_BODY+="### ⚠️ Breaking Changes"$'\n\n'
    PR_BODY+="$BREAKING_CHANGES"$'\n'
fi

# Add grouped commits by scope
for scope in "${!GROUPED_SCOPES[@]}"; do
    PR_BODY+="### $scope"$'\n\n'
    PR_BODY+="${GROUPED_SCOPES[$scope]}"$'\n'
done

# Add uncategorized commits at the bottom
if [[ -n "$UNCATEGORIZED_COMMITS" ]]; then
    PR_BODY+="### 🗑️ Uncategorized"$'\n\n'
    PR_BODY+="$UNCATEGORIZED_COMMITS"$'\n'
fi

PR_BODY+="
## Fibery Task
$FIBERY_TASK

## Testing Instructions
\`\`\`sh
pnpm test
\`\`\`
"

# If --dry-run is set, print the PR body and exit
if [ "$DRY_RUN" = true ]; then
    echo -e "$PR_BODY"
    exit 0
fi

# Run the `gh pr create` command
echo "🚀 Creating PR from branch '$BRANCH'..."
gh pr create --title "$FIBERY_TITLE" --body "$PR_BODY" --head "$BRANCH"

# Check success
if [ $? -eq 0 ]; then
    echo "✅ Pull request created successfully from '$BRANCH'!"
else
    echo "❌ Failed to create pull request."
fi

