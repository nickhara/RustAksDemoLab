FROM mcr.microsoft.com/devcontainers/universal:6

# Fix: Remove the broken Yarn repository from the apt sources.
# This prevents 'apt-get update' from failing due to the missing GPG key.
# (Yarn is already provided by the dev container features/nvm, so this system repo is unnecessary)
# See issue #3487
#
# Local Devcontainer build error:
# Err:2 https://dl.yarnpkg.com/debian stable InRelease
# The following signatures couldn't be verified because the public key is not available: NO_PUBKEY 62D54FD4003F6525
RUN rm -f /etc/apt/sources.list.d/yarn.list