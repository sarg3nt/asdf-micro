#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/zyedidia/micro"
TOOL_NAME="micro"
TOOL_TEST="micro --version"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if micro is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
	list_github_tags
}

get_platform() {
	platform=''
	machine=$(uname -m)
	case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
		"linux")
		case "$machine" in
			"arm64"* | "aarch64"* ) platform='linux-arm64' ;;
			"arm"* | "aarch"*) platform='linux-arm' ;;
			*"86") platform='linux32' ;;
			*"64") platform='linux64' ;;
		esac
		;;
		"darwin") platform='osx' ;;
		*"freebsd"*)
		case "$machine" in
			*"86") platform='freebsd32' ;;
			*"64") platform='freebsd64' ;;
		esac
		;;
		"openbsd")
		case "$machine" in
			*"86") platform='openbsd32' ;;
			*"64") platform='openbsd64' ;;
		esac
		;;
		"netbsd")
		case "$machine" in
			*"86") platform='netbsd32' ;;
			*"64") platform='netbsd64' ;;
		esac
		;;
		"msys"*|"cygwin"*|"mingw"*|*"_nt"*|"win"*)
		case "$machine" in
			*"86") platform='win32' ;;
			*"64") platform='win64' ;;
		esac
		;;
	esac

	if [ "${platform:-x}" = "linux64" ]; then
		# Detect musl libc (source: https://stackoverflow.com/a/60471114)
		libc=$(ldd /bin/ls | grep 'musl' | head -1 | cut -d ' ' -f1)
		if [ -n "$libc" ]; then
			# Musl libc; use the staticly-compiled versioon
			platform='linux64-static'
		fi
	fi

	echo "$platform"
}

download_release() {
	local version filename url platform extension
	version="$1"
	filename="$2"
	platform=$(get_platform)
	if [ "${platform:-x}" = "win64" ] || [ "${platform:-x}" = "win32" ]; then
  		extension='zip'
	else
  		extension='tar.gz'
	fi

	echo "Platform: $platform"
	echo "Extension: $extension"
	local download_file="$ASDF_DOWNLOAD_PATH/micro.$extension"

	#'https://github.com/zyedidia/micro/releases/download/v$version/micro-$version-$platform.$extension'
	url="$GH_REPO/releases/download/v${version}/micro-${version}-${platform}.${extension}"

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$download_file" -C - "$url" || fail "Could not download $url"

	case "$extension" in
 	"zip") unzip -j "$download_file" -d "$ASDF_DOWNLOAD_PATH/" ;;
	"tar.gz") tar -xvzf "$download_file" -C "$ASDF_DOWNLOAD_PATH/" "micro-$version/micro" ;;
	esac

	# tar: /tmp/asdf.bhqi/downloads/micro/2.0.13/micro-2.0.13: Cannot open: No such file or directory



	#mv "$ASDF_DOWNLOAD_PATH/micro-$version/micro" "$filename"

	#echo "*** Destination file ***"
	
	#ls -alh "$filename"

	rm "$download_file"
	#rm -rf "$ASDF_DOWNLOAD_PATH/micro-$version"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"
	
		echo "*** ls install path $install_path *** "
		ls -alh "$install_path"
		ls -alh "$install_path/${TOOL_NAME}-${version}"

		mv "$install_path/${TOOL_NAME}-${version}" "$install_path/${TOOL_NAME}"

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
