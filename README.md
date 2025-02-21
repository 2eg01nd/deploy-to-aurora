# Deploy application to Aurora OS

A script that simplifies the installation of applications on Aurora OS. To build applications you need to have the
[Platform SDK](https://developer.auroraos.ru/doc/5.1.1/sdk/psdk) installed.
Also make sure you have a Keys folder in your home directory with the right profile to sign the package
Available features:
- Building the application under different targeting profiles
- Signing a package using the desired profile
- Selecting a package manager

# Requirements
- Linux family operating system
- Platform SDK

# Usage
```
Usage: $0 [-t] TARGET_NAME [-s] SIGN_TYPE [-d] DEVICE [-b] BUILD PATH [-p] PACKAGE MANAGER\n
			-t Target name from sdk-assistant list.\n
			-s Type sign key.pem and cert.pem.\n
			-p Root path where build project.\n
			-m Choose package manager(APM, pkcon, rpm).\n
			-d device name ip and username or name from .ssh/config.\n'
```
