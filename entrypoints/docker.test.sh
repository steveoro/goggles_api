#!/bin/sh

# Fail fast in case of errors:
set -euo

# Don't block server start in case a previous PID file is left:
if [ -f tmp/pids/server.pid ]; then
  rm tmp/pids/server.pid
fi

RAILS_ENV=test bundle exec rails s -b 0.0.0.0 -p 8080

# echo "\r\n==============\r\n=  Brakeman  =\r\n=============="
# bundle exec brakeman -A6q

# echo "\r\n=============\r\n=  Rubocop  =\r\n============="
# bundle exec rubocop -f fu

# echo "\r\n=============\r\n=   RSpec   =\r\n============="
# bundle exec rspec --fail-fast --color --profile 10 -f progress --order rand --t type:command

# echo "\r\nDone."
