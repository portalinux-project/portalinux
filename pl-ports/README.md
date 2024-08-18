# PortaLinux Ports System Beta

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
install packages properly, unless it's a PortaLinux-specific package

```yaml
name: "package" # Name of package (Required)
version: "1.0.0" # Version of package (Required)
url: "https://example.com/package/package-1.0.0-src.tar.gz" # Source Download URL (Required)
configure-flags: "--prefix=/opt --enable-experimental-features" # Configuration Flags (Technically optional, but required for most packages, since no package installs to /opt by default)
compile-flags: "-O3 -march=native" # Compilation Flags (Completely optional)
```

***WARNING: DO NOT CHANGE ANY PREFIXES OR INSTALL DIRS TO ANYTHING OUTSIDE OF `/opt`, YOU WILL BREAK STUFF AND I'M NOT RESPONSIBLE FOR ANY DAMAGE YOU DO BY MISUSE***

## build.rb

```ruby
class Package
	extend PLPorts::BasePackage

	def self.configure()
end
```
