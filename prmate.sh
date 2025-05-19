#!/bin/bash

# Exit immediately if any command fails to ensure script reliability
set -e

# Current version of PRMate - increment when making changes
VERSION="0.0.8"

# Configuration constants
# Conventional commit types supported by the tool
COMMIT_TYPES=("feat" "fix" "docs" "style" "refactor" "perf" "test" "build" "ci" "chore" "revert")
# Emojis corresponding to each commit type for visual representation in PR
EMOJIS=("✨ Features" "🐛 Bug Fixes" "📝 Documentation" "🎨 Code Style" "♻️ Refactoring" "⚡ Performance" "✅ Tests" "🏗️ Build System" "🚀 CI/CD" "🧹 Chores" "⏪ Reverts")
# URLs for self-update functionality
GITHUB_RAW_URL="https://raw.githubusercontent.com/vladimirconpago/prmate/master/prmate.sh"
GITHUB_INSTALLER_URL="https://raw.githubusercontent.com/vladimirconpago/prmate/master/install.sh"
# Default configuration
DRY_RUN=false
IS_DRAFT=false
TARGET_BRANCH="develop"
# Arrays for storing grouped commit messages by scope
GROUPED_SCOPES_KEYS=()
GROUPED_SCOPES_VALUES=()
# Storage for special commit categories
UNCATEGORIZED_COMMITS=""
BREAKING_CHANGES=""


# Display help information and usage examples
usage() {
    echo "🧢 PRMate v$VERSION "
    echo "Usage: $0 [-b <branch>] [--dry-run] [--draft] [--reinstall] [--version]"
    echo "  -b  Specify a target branch (default: current branch)"
    echo "  --draft  Create the PR in draft"
    echo "  --dry-run  Preview PR body without creating PR"
    echo "  --reinstall  Reinstall PRMate to update to the latest version"
    echo "  --version  Display the current version"
    echo "  --help  Display this help message"
    echo " -------------------------------------------"
    echo "Available commit types: ${COMMIT_TYPES[*]}"
    exit 1
}

# Verify git is installed - required for all operations
if ! command -v git &> /dev/null; then
    echo "❌ Git CLI is not installed."
    echo "Install it from: https://git-scm.com/"
    exit 1
fi

# Verify GitHub CLI is installed - required for PR creation
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed."
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Get current branch name and repository URL for PR creation
BASE_BRANCH=$(git branch --show-current)
GITHUB_REPO_URL=$(git remote get-url origin | sed -E 's#(git@|https://)([^:/]+)[:/]([^/]+)/([^/.]+).*#https://\2/\3/\4#')

# Validate that the current branch exists in the repository
if ! git show-ref --verify --quiet "refs/heads/$BASE_BRANCH"; then
    echo "❌ Branch '$BASE_BRANCH' does not exist."
    exit 1
fi

# Calculate SHA256 hash of a file for integrity verification
# Used during update checks to verify downloaded files
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

# Check for newer versions of PRMate and offer to update
# Skipped in dry-run mode to avoid interrupting preview
check_for_updates() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return
    fi
    echo "🔍 Checking for updates..."

    # Fetch latest script from GitHub with cache control
    LATEST_SCRIPT=$(curl -sSL -H "Cache-Control: no-cache" "$GITHUB_RAW_URL")
    
    # Extract version number from the downloaded script
    LATEST_VERSION=$(echo "$LATEST_SCRIPT" | grep -o 'VERSION="[^"]*"' | head -1 | cut -d'"' -f2)
    
    if [[ -z "$LATEST_VERSION" ]]; then
        echo "⚠️ Could not determine latest version. Skipping update check."
        return
    fi
    
    # Compare current version with latest available
    if [[ "$LATEST_VERSION" != "$VERSION" ]]; then
        echo "🔔 A new version of PRMate is available! (Current: v$VERSION, Latest: v$LATEST_VERSION)"
        read -rp "Do you want to update now? (y/n): " CONFIRM
        if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
            echo "⬇️ Installing new version..."
            reinstall_prmate
            exit 0
        else
            echo "⚠️ Skipping update. You can update manually later."
        fi
    else
        echo "✅ PRMate v$VERSION is up to date."
    fi
}

# Download and install the latest version of PRMate
reinstall_prmate() {
    echo "⬇️ Fetching the latest version of PRMate..."
    curl -sSL "$GITHUB_INSTALLER_URL" | bash
    exit 0
}

# Handle special flags that should be processed before normal argument parsing
for arg in "$@"; do
    if [[ "$arg" == "--reinstall" ]]; then
        reinstall_prmate
    elif [[ "$arg" == "--version" ]]; then
        echo "PRMate v$VERSION"
        exit 0
    fi
done

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -b) TARGET_BRANCH="$2"; shift ;;
        --dry-run) DRY_RUN=true ;;
        --draft) IS_DRAFT=true ;;
        *) usage ;;
    esac
    shift
done

# Check for updates at startup unless in dry-run mode
if [[ "$DRY_RUN" != "true" ]]; then
    check_for_updates
fi

echo "🤝 Running PRMate..."

# Collect PR information from user or use defaults for dry run
if [[ "$DRY_RUN" != "true" ]]; then
    read -rp "Enter PR Title: " TASK_TITLE
    read -rp "Enter Task Link: " TASK
else
    TASK_TITLE="Test PR"
    TASK="https://fibery.io/task"
fi


# Determine the target branch reference (remote or local)
if git show-ref --verify --quiet "refs/remotes/origin/$TARGET_BRANCH"; then
    TARGET_BRANCH_REF="origin/$TARGET_BRANCH"
elif git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    echo "⚠️ Warning: 'origin/$TARGET_BRANCH' not found. Using local '$TARGET_BRANCH' branch."
    TARGET_BRANCH_REF="$TARGET_BRANCH"
else
    echo "❌ Error: Target branch '$TARGET_BRANCH' does not exist remotely or locally."
    exit 1
fi

echo "🔍 Comparing changes between '$BASE_BRANCH' and '$TARGET_BRANCH_REF'"

# Retrieve commits unique to the current branch compared to target
YOUR_COMMITS=$(git log --pretty=format:"%h %s" "$TARGET_BRANCH_REF".."$BASE_BRANCH" 2>/dev/null || echo "")

# Ensure there are commits to include in the PR
if [ -z "$YOUR_COMMITS" ]; then
    echo "❌ No new commits to create a PR from branch '$BASE_BRANCH' to '$TARGET_BRANCH_REF'."
    exit 1
fi

# Count commits for user feedback
COMMIT_COUNT=$(echo "$YOUR_COMMITS" | wc -l)
echo "✅ Found $COMMIT_COUNT commit(s) to include in the PR"

# Get detailed commit information for processing
# Using a temp file to handle multi-line commit messages properly
COMMIT_FILE=$(mktemp)
git log --pretty=format:"%h %s%n%b" "$TARGET_BRANCH_REF".."$BASE_BRANCH" > "$COMMIT_FILE" 2>/dev/null

# Map commit type to corresponding emoji for PR formatting
get_emoji() {
    local type="$1"
    for i in "${!COMMIT_TYPES[@]}"; do
        if [[ "${COMMIT_TYPES[$i]}" == "$type" ]]; then
            echo "${EMOJIS[$i]}"
            return
        fi
    done
    echo "🧨 Uncategorized"  # Default for unrecognized commit types
}

# Add a commit to the appropriate scope group for organized PR display
add_to_grouped_scopes() {
    local key="$1"
    local value="$2"
    for i in "${!GROUPED_SCOPES_KEYS[@]}"; do
        if [[ "${GROUPED_SCOPES_KEYS[$i]}" == "$key" ]]; then
            GROUPED_SCOPES_VALUES[$i]+=$'\n'"$value"
            return
        fi
    done
    GROUPED_SCOPES_KEYS+=("$key")
    GROUPED_SCOPES_VALUES+=("$value")
}


# Process each commit to categorize by type and scope
while IFS= read -r commit || [ -n "$commit" ]; do
    # Skip empty lines in commit file
    if [ -z "$commit" ]; then
        continue
    fi
    
    # Extract commit hash and message
    COMMIT_HASH=$(echo "$commit" | awk '{print $1}')
    COMMIT_MESSAGE=$(echo "$commit" | cut -d' ' -f2-)
    
    # Skip invalid commit entries
    if [ -z "$COMMIT_HASH" ]; then
        continue
    fi
    
    # Get complete commit message including body for breaking change detection
    FULL_COMMIT_MESSAGE=$(git show --no-patch --format=%B "$COMMIT_HASH" 2>/dev/null || echo "")

    # Parse conventional commit format to extract type and scope
    if [[ $COMMIT_MESSAGE =~ ^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(([^\)]+)\))?(!)?: ]]; then
        commit_type="${BASH_REMATCH[1]}"
        commit_scope="${BASH_REMATCH[3]:-Uncategorized}"  # Default scope if not specified
    else
        commit_type="other"
        commit_scope="Uncategorized"
    fi

    # Clean the commit message by removing the conventional commit prefix
    clean_message=$(echo "$COMMIT_MESSAGE" | sed -E 's/^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([^\)]+\))?(!)?: //')

    # Create a GitHub link to the commit
    commit_link="[$clean_message]($GITHUB_REPO_URL/commit/$COMMIT_HASH)"

    # Categorize commits into breaking changes, uncategorized, or by type/scope
    if echo "$FULL_COMMIT_MESSAGE" | grep -q "BREAKING CHANGE:"; then
        BREAKING_CHANGES+="- ⚠️ $commit_link"$'\n'
    elif [[ "$commit_type" == "other" ]]; then
        UNCATEGORIZED_COMMITS+="- ⁉️ $commit_link"$'\n'
    else
        # Add to appropriate scope group with emoji
        emoji=$(get_emoji "$commit_type")
        add_to_grouped_scopes "$commit_scope" "- $emoji $commit_link"
    fi
done < "$COMMIT_FILE"

# Remove temporary file after processing
rm -f "$COMMIT_FILE"

# Construct the PR description with organized sections
PR_BODY="## Description"$'\n\n'

# Add breaking changes section if any exist
if [[ -n "$BREAKING_CHANGES" ]]; then
    PR_BODY+="### ⚠️ Breaking Changes"$'\n\n'"$BREAKING_CHANGES"$'\n'
fi

# Add each scope group as a separate section
for i in "${!GROUPED_SCOPES_KEYS[@]}"; do
    PR_BODY+="### ${GROUPED_SCOPES_KEYS[$i]}"$'\n\n'"${GROUPED_SCOPES_VALUES[$i]}"$'\n'
done

# Add uncategorized commits section if any exist
if [[ -n "$UNCATEGORIZED_COMMITS" ]]; then
    PR_BODY+="### ⁉️ Non-compliant"$'\n\n'"$UNCATEGORIZED_COMMITS"$'\n'
fi

# Add task reference and testing instructions
PR_BODY+=""$'\n'
PR_BODY+="## Task"$'\n'"$TASK"$'\n\n'
PR_BODY+="## Testing Instructions"$'\n\n'
PR_BODY+="\`\`\`sh"$'\n'
PR_BODY+="pnpm test"$'\n'
PR_BODY+="\`\`\`"$'\n'

# any other optional arguments
ADDITONAL_ARGS=""

REVIEWING_TEAM="conpagoaus/frontend-team"

if [[ $GITHUB_REPO_URL == *"backend"* ]]; then
  REVIEWING_TEAM="conpagoaus/backend-team"
fi

# In dry-run mode, just display the PR body without creating PR
if [[ "$DRY_RUN" == "true" ]]; then
    echo "## PR Body Preview"$'\n\n'
    echo "$PR_BODY"
    exit 0
fi

# create the PR in draft
if [[ "$IS_DRAFT" == "true" ]]; then
  ADDITONAL_ARGS+=" --draft"
fi

# Create the pull request using GitHub CLI
echo "🚀 Creating PR from branch '$BASE_BRANCH'..."
gh pr create --title "$TASK_TITLE" --body "$PR_BODY" --head "$BASE_BRANCH" --assignee "@me"	--reviewer $REVIEWING_TEAM $ADDITONAL_ARGS

# Provide feedback on PR creation success or failure
if [ $? -eq 0 ]; then
    echo "✅ Pull request created successfully from '$BASE_BRANCH'!"
else
    echo "❌ Failed to create pull request."
fi
