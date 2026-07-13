#!/usr/bin/env bash
# =============================================================================
# publish_release.sh — build, zip, tag, and publish a pgAdmin3 macOS release
# to GitHub, plus update the Homebrew tap.
#
# Run via `make release`. This project doesn't track a real semantic
# version, so releases are versioned by date (YYYY.MM.DD), with a numeric
# suffix (.2, .3, ...) if more than one release happens on the same day.
#
# What it does, in order:
#   1. Refuses to run with a dirty working tree or without `gh` installed.
#   2. Computes today's date-based version (with collision-avoidance).
#   3. Promotes the CHANGELOG.md "## [Unreleased]" section to
#      "## [<version>]" (leaving a fresh empty Unreleased above it) and
#      commits that change.
#   4. Builds the app (`make build`) and re-stamps Info.plist with the
#      release version.
#   5. Zips the .app, computes its checksum.
#   6. Tags v<version>, pushes the tag + the changelog commit to `origin`
#      (never `upstream` -- see AGENTS.md's branching strategy: this repo
#      pulls from upstream but only ever pushes to the user's own fork).
#   7. Creates the GitHub release with the extracted changelog notes and the
#      zip/checksum as assets.
#   8. Generates and pushes an updated Homebrew Cask to the heptau/homebrew-tap
#      repo, via the GitHub API (no local clone needed).
#
# Environment variables:
#   HOMEBREW_TAP_REPO   GitHub repo of the Homebrew tap (default:
#                        heptau/homebrew-tap -- "brew install
#                        heptau/tap/pgadmin3" expands to this repo name per
#                        Homebrew's tap-naming convention).
#   RELEASE_REMOTE       Git remote to push the tag/commit to and to read
#                        the GitHub repo slug from (default: origin).
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

BUILD_DIR="build-macos"
DIST_DIR="${BUILD_DIR}/dist"
HOMEBREW_TAP_REPO="${HOMEBREW_TAP_REPO:-heptau/homebrew-tap}"
HOMEBREW_CASK_PATH="Casks/pgadmin3.rb"
RELEASE_REMOTE="${RELEASE_REMOTE:-origin}"

command -v gh >/dev/null 2>&1 || { echo "Error: 'gh' (GitHub CLI) is required. Install with 'brew install gh', then 'gh auth login'."; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Error: 'gh' is not authenticated. Run 'gh auth login' first."; exit 1; }

# ── Guard: working tree must be clean ────────────────────────────────────────
if ! git diff --quiet || ! git diff --cached --quiet; then
	echo "Error: uncommitted changes present. Commit or stash before releasing."
	exit 1
fi

REPO_SLUG="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
if [ -z "$REPO_SLUG" ]; then
	# Fall back to parsing it out of the remote URL if `gh repo view` can't
	# tell (e.g. it default-resolved to the wrong remote in a fork setup).
	REMOTE_URL="$(git remote get-url "$RELEASE_REMOTE")"
	REPO_SLUG="$(echo "$REMOTE_URL" | sed -E 's#.*github.com[:/]([^/]+/[^/.]+)(\.git)?#\1#')"
fi
echo "Releasing to: ${REPO_SLUG} (remote: ${RELEASE_REMOTE})"

CHANGELOG="CHANGELOG.md"

# ── Resume detection ──────────────────────────────────────────────────────────
# If CHANGELOG.md's [Unreleased] section is already empty, a previous run
# already promoted it to some [<version>] section (e.g. it tagged + pushed
# that commit but then failed on a later step, like `gh release create`
# hitting an auth-scope error). Reuse that exact version -- identified as the
# heading right after [Unreleased] -- instead of computing a fresh one.
#
# NB: this deliberately does NOT look at HEAD's commit message (a previous
# version of this check did, and broke the moment any other commit -- e.g. a
# script bugfix -- landed on top of the "Release vX.Y.Z" commit before the
# retry). Looking at CHANGELOG.md's actual structure instead is robust to
# that.
#
# Only resume if that version doesn't have a GitHub release yet (if it does,
# whatever's pending must be a genuinely new, not-yet-promoted change, so
# fall through to minting a fresh version below).
RESUMING=0
if [ -z "$(./macos/changelog_notes.sh Unreleased 2>/dev/null || true)" ]; then
	CANDIDATE_VERSION="$(awk '
		/^## \[/ {
			if (seen) {
				label = $0
				sub(/^## \[/, "", label)
				sub(/\].*/, "", label)
				print label
				exit
			}
			if ($0 ~ /^## \[Unreleased\]/) seen = 1
		}
	' "$CHANGELOG")"
	if [ -n "$CANDIDATE_VERSION" ] && git rev-parse "v${CANDIDATE_VERSION}" >/dev/null 2>&1; then
		if ! gh release view "v${CANDIDATE_VERSION}" --repo "$REPO_SLUG" >/dev/null 2>&1; then
			VERSION="$CANDIDATE_VERSION"
			TAG="v${VERSION}"
			RESUMING=1
			echo "Resuming release ${TAG} ([Unreleased] is empty, and [${VERSION}] has no GitHub release yet)."
			echo ""
		fi
	fi
fi

if [ "$RESUMING" = 1 ]; then
	:
else
	# ── Compute version (date-based, with same-day collision avoidance) ──────
	BASE_VERSION="$(date +%Y.%m.%d)"
	VERSION="$BASE_VERSION"
	N=2
	while git rev-parse "v$VERSION" >/dev/null 2>&1 || git ls-remote --exit-code --tags "$RELEASE_REMOTE" "v$VERSION" >/dev/null 2>&1; do
		VERSION="${BASE_VERSION}.${N}"
		N=$((N + 1))
	done
	TAG="v${VERSION}"
	echo "Version: ${VERSION} (tag ${TAG})"
	echo ""

	# ── Promote CHANGELOG.md's Unreleased section to this version ───────────
	if ! grep -q '^## \[Unreleased\]' "$CHANGELOG"; then
		echo "Error: $CHANGELOG has no '## [Unreleased]' heading -- nothing to release."
		exit 1
	fi
	echo "==> Promoting [Unreleased] to [${VERSION}] in $CHANGELOG..."
	awk -v ver="$VERSION" '
		/^## \[Unreleased\]/ {
			print
			getline blank
			print blank
			print "## [" ver "]"
			print ""
			next
		}
		{ print }
	' "$CHANGELOG" > "${CHANGELOG}.tmp"
	mv "${CHANGELOG}.tmp" "$CHANGELOG"
	git add "$CHANGELOG"
	git commit -q -m "Release ${TAG}"
	echo ""
fi

NOTES_FILE="${DIST_DIR}/RELEASE_NOTES.md"
mkdir -p "$DIST_DIR"
if ! ./macos/changelog_notes.sh "$VERSION" > "$NOTES_FILE" 2>/dev/null || [ ! -s "$NOTES_FILE" ]; then
	echo "No changelog entries recorded for this release." > "$NOTES_FILE"
fi

# ── Build & bundle, stamped with the release version ────────────────────────
echo "==> Building (this may take a while)..."
make build
echo "==> Re-stamping Info.plist with version ${VERSION}..."
PGADMIN3_VERSION="$VERSION" ./macos/build_app.sh "$BUILD_DIR"
echo ""

# ── Zip + checksum ────────────────────────────────────────────────────────────
ZIP_NAME="pgAdmin3-${VERSION}-macos-arm64.zip"
ZIP_PATH="${DIST_DIR}/${ZIP_NAME}"
echo "==> Zipping ${ZIP_NAME}..."
rm -f "$ZIP_PATH"
(cd "$BUILD_DIR" && zip -rq "dist/${ZIP_NAME}" "pgAdmin III.app")
(cd "$DIST_DIR" && shasum -a 256 "$ZIP_NAME" > checksums.txt)
echo ""

# ── Homebrew Cask ────────────────────────────────────────────────────────────
echo "==> Generating Homebrew cask..."
./macos/generate_homebrew_cask.sh "$VERSION" "$ZIP_PATH" "${DIST_DIR}/Casks"
LOCAL_CASK="${DIST_DIR}/Casks/pgadmin3.rb"
echo ""

# ── Tag & push (to $RELEASE_REMOTE only -- never `upstream`) ────────────────
echo "==> Tagging ${TAG}..."
if git tag -l "$TAG" | grep -q .; then
	echo "    Tag ${TAG} already exists locally -- skipping tag creation."
else
	git tag -a "$TAG" -m "pgAdmin3 ${TAG}"
fi
git push "$RELEASE_REMOTE" HEAD
git push "$RELEASE_REMOTE" "$TAG"
echo ""

# ── GitHub release ────────────────────────────────────────────────────────────
# Idempotent: a previous run may have created the tag/release already (e.g.
# this script failed on a later step, like the Homebrew tap update below) --
# re-running must not blow up on "release already exists".
if gh release view "$TAG" --repo "$REPO_SLUG" >/dev/null 2>&1; then
	echo "==> GitHub release ${TAG} already exists -- skipping creation."
else
	echo "==> Creating GitHub release ${TAG}..."
	gh release create "$TAG" \
		--repo "$REPO_SLUG" \
		--title "pgAdmin3 ${TAG}" \
		--notes-file "$NOTES_FILE" \
		"$ZIP_PATH" "${DIST_DIR}/checksums.txt"
fi
echo ""

# ── Homebrew tap update via GitHub API (no local clone needed) ──────────────
if ! gh api "repos/${HOMEBREW_TAP_REPO}" >/dev/null 2>&1; then
	echo "Error: repo '${HOMEBREW_TAP_REPO}' not found or inaccessible to 'gh'."
	echo "The GitHub release above was created successfully; only the Homebrew"
	echo "tap update is affected. Set HOMEBREW_TAP_REPO to the correct name and"
	echo "re-run 'make release' (it will skip the already-created tag/release"
	echo "and retry only this step)."
	exit 1
fi

echo "==> Updating ${HOMEBREW_TAP_REPO}/${HOMEBREW_CASK_PATH}..."
CURRENT_SHA="$(gh api "repos/${HOMEBREW_TAP_REPO}/contents/${HOMEBREW_CASK_PATH}" --jq '.sha' 2>/dev/null || true)"
CONTENT="$(base64 <"$LOCAL_CASK" | tr -d '\n')"
if [ -n "$CURRENT_SHA" ]; then
	gh api "repos/${HOMEBREW_TAP_REPO}/contents/${HOMEBREW_CASK_PATH}" \
		--method PUT \
		-f message="pgAdmin3 ${TAG}" \
		-f content="${CONTENT}" \
		-f sha="${CURRENT_SHA}" >/dev/null
else
	gh api "repos/${HOMEBREW_TAP_REPO}/contents/${HOMEBREW_CASK_PATH}" \
		--method PUT \
		-f message="pgAdmin3 ${TAG}" \
		-f content="${CONTENT}" >/dev/null
fi
echo ""

echo "======================================================================"
echo "  Released : pgAdmin3 ${TAG}"
echo "  GitHub   : https://github.com/${REPO_SLUG}/releases/tag/${TAG}"
echo "  Homebrew : brew install heptau/tap/pgadmin3"
echo "======================================================================"
