#!/bin/sh

# Jump to repository root
cd "$(git rev-parse --show-toplevel)"

# Install Ruby
rbenv init
export LDFLAGS="-L$(brew --prefix openssl)/lib"
export CPPFLAGS="-I$(brew --prefix openssl)/include"
CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl)" RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl)" rbenv install `cat .ruby-version`

# Install bundler dependencies
gem install bundler
bundle install

# Install Envman
curl -fL https://github.com/bitrise-io/envman/releases/download/2.3.2/envman-$(uname -s)-$(uname -m) > /usr/local/bin/envman
chmod +x /usr/local/bin/envman

# Post setup info
echo "Run make run"
