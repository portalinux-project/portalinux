# PortaLinux Ports System Alpha

The PortaLinux Ports System is the main way to install PortaLinux packages. It
remotely fetches packages from a package repository, just like any other
package manager, but it compiles the packages from scratch, just like Arch's
AUR, Gentoo's Portage and FreeBSD ports (which is what pl-ports is named after).

PortaLinux's implementation of the ports system works very similarly to macOS's
Homebrew package manager.

# Package Creation

PortaLinux Ports packages require two files for installation:

- `properties.yaml`: Defines metadata used in package creation, such as name, version and download URL.
- `build.rb`: Basically the build script.

To create a valid ports package, you will need these two files. The files must
also be in the following arrangement:

## properties.yaml

You will need `name`, `version`, and `url` fields for pl-ports.rb to consider
your package valid. The `compile-flags` field will most likely be required to
install packages properly, unless it's a PortaLinux-specific package. There's
an example of `properties.yaml` below:

```yaml
name: "package" # Name of package (Required)
version: "1.0.0" # Version of package (Required)
author: "CinnamonWolfy" # (Optional, but it won't remain that way)
url: "https://example.com/package/package-1.0.0-src.tar.gz" # Source Download URL (Required)
configure-flags: "--prefix=/opt --enable-experimental-features" # Configuration Flags (Technically optional, but required for most packages, since no package installs to /opt by default)
compile-flags: "-O3 -march=native" # Compilation Flags (Completely optional)
```

***WARNING: DO NOT CHANGE ANY PREFIXES OR INSTALL DIRS TO ANYTHING OUTSIDE OF `/opt`, YOU WILL BREAK STUFF AND I'M NOT RESPONSIBLE FOR ANY DAMAGE YOU DO BY MISUSE***

## build.rb

For a valid `build.rb` script. you must have a class called `Package` with two
public methods: `build()` and `install()`. There's also class variables that
are generated from `properties.yaml` that you, the reader, will probably need:

- `@pkgName`: Package name. Generated from the `name` field in `properties.yaml`
- `@pkgVersion`: Package version. Generated from the `version` field in `properties.yaml`
- `@pkgUrl`: Source Download URL. Generated from the `url` field in `properties.yaml`
- `@pkgConfigFlags`: Configure flags. Generated from the `configure-flags` field in `properties.yaml`
- `@pgkCompileFlags`: Compilation flags. Generated from the `compile-flags` field in `properties.yaml`
- `@pkgRootDir`: Directory where `properties.yaml` and `build.rb` are stored at. Generated at initialization
- `@pkgBuildDir`: Directory where the sources are extracted to. Inferred from function parameter `buildDir` (defaults to `@pkgRootDir/src`)
- `@pkgPatchDir`: Directory where patches are stored at. Inferred from function parameter `patchDir` (defaults to `@pkgRootDir/src`)
- `@pkgOverlayDir`: Directory where extra files that should be copied to `@pkgBuildDir`. Inferred from function parameter `overlayDir` (defaults to `@pkgRootDir/overlay`)
