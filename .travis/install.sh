#!/usr/bin/env bash
# RelStorage: Taken from gevent.
# GEVENT: Taken from https://raw.githubusercontent.com/DRMacIver/hypothesis/master/scripts/install.sh

# Special license: Take literally anything you want out of this file. I don't
# care. Consider it WTFPL licensed if you like.
# Basically there's a lot of suffering encoded here that I don't want you to
# have to go through and you should feel free to use this to avoid some of
# that suffering in advance.

set -e
set -x

# This is to guard against multiple builds in parallel. The various installers will tend
# to stomp all over eachother if you do this and they haven't previously successfully
# succeeded. We use a lock file to block progress so only one install runs at a time.
# This script should be pretty fast once files are cached, so the lost of concurrency
# is not a major problem.
# This should be using the lockfile command, but that's not available on the
# containerized travis and we can't install it without sudo.
# Is is unclear if this is actually useful. I was seeing behaviour that suggested
# concurrent runs of the installer, but I can't seem to find any evidence of this lock
# ever not being acquired.

BASE=${BUILD_RUNTIMES-$PWD/.runtimes}
echo $BASE
mkdir -p $BASE

LOCKFILE="$BASE/.install-lockfile"
while true; do
  if mkdir $LOCKFILE 2>/dev/null; then
    echo "Successfully acquired installer."
    break
  else
    echo "Failed to acquire lock. Is another installer running? Waiting a bit."
  fi

  sleep $[ ( $RANDOM % 10)  + 1 ].$[ ( $RANDOM % 100) ]s

  if (( $(date '+%s') > 300 + $(stat --format=%X $LOCKFILE) )); then
    echo "We've waited long enough"
    rm -rf $LOCKFILE
  fi
done
trap "rm -rf $LOCKFILE" EXIT


PYENV=$BASE/pyenv


if [ ! -d "$PYENV/.git" ]; then
  rm -rf $PYENV
  git clone https://github.com/yyuu/pyenv.git $BASE/pyenv
else
  back=$PWD
  cd $PYENV
  git fetch || echo "Update failed to complete. Ignoring"
  git reset --hard origin/master
  cd $back
fi

SNAKEPIT=$BASE/snakepit

install () {

  VERSION="$1"
  ALIAS="$2"
  mkdir -p $BASE/versions
  SOURCE=$BASE/versions/$ALIAS

  if [ ! -e "$SOURCE" ]; then
    mkdir -p $SNAKEPIT
    mkdir -p $BASE/versions
    $BASE/pyenv/plugins/python-build/bin/python-build $VERSION $SOURCE
  fi
 rm -f $SNAKEPIT/$ALIAS
 mkdir -p $SNAKEPIT
 $SOURCE/bin/python -m pip.__main__ install --upgrade pip wheel virtualenv
 ln -s $SOURCE/bin/python $SNAKEPIT/$ALIAS
}


for var in "$@"; do
  case "${var}" in
    2.7)
      install 2.7.12 2.7
      ;;
    3.4)
      install 3.4.5 3.4
      ;;
    3.5)
      install 3.5.1 .5
      ;;
    pypy)
      install pypy2-5.4 pypy
      ;;
  esac
done
