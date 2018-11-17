#!/usr/bin/env bash

set -e

SCRIPT=`pwd`/$0
FILENAME=`basename $SCRIPT`
PATHNAME=`dirname $SCRIPT`
ROOT=$PATHNAME/..
BUILD_DIR=$ROOT/build
DEPS_PACKAGE_DIR=$ROOT/depspackage
CURRENT_DIR=`pwd`
NVM_CHECK="$PATHNAME"/checkNvm.sh

LIB_DIR=$BUILD_DIR/libdeps
PREFIX_DIR=$LIB_DIR/build/
FAST_MAKE=''


parse_arguments(){
  while [ "$1" != "" ]; do
    case $1 in
      "--enable-gpl")
        ENABLE_GPL=true
        ;;
      "--cleanup")
        CLEANUP=true
        ;;
      "--fast")
        FAST_MAKE='-j4'
        ;;
    esac
    shift
  done
}

check_proxy(){
  if [ -z "$http_proxy" ]; then
    echo "No http proxy set, doing nothing"
  else
    echo "http proxy configured, configuring npm"
    npm config set proxy $http_proxy
  fi

  if [ -z "$https_proxy" ]; then
    echo "No https proxy set, doing nothing"
  else
    echo "https proxy configured, configuring npm"
    npm config set https-proxy $https_proxy
  fi
}

install_nvm_node() {
  if [ -d $LIB_DIR ]; then
    export NVM_DIR=$(readlink -f "$LIB_DIR/nvm")
    if [ ! -s "$NVM_DIR/nvm.sh" ]; then
      cp "$DEPS_PACKAGE_DIR/nvm-0.33.11.zip" "$LIB_DIR"
      cd "$LIB_DIR"
      unzip nvm-0.33.11.zip
      mv nvm-0.33.11 nvm
      rm -f nvm-0.33.11.zip
      cd "$CURRENT_DIR"
    fi
    . $NVM_CHECK
    nvm install
  else
    mkdir -p $LIB_DIR
    install_nvm_node
  fi
}

install_apt_deps(){
  install_nvm_node
  install_gcc
  nvm use
  npm install
  npm install -g node-gyp
  npm install gulp@3.9.1 gulp-eslint@3 run-sequence@2.2.1 webpack-stream@4.0.0 google-closure-compiler-js@20170521.0.0 del@3.0.0 gulp-sourcemaps@2.6.4 script-loader@0.7.2 expose-loader@0.7.5
wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo
ln -s /opt/rh/devtoolset-2/root/usr/bin/gcc /usr/bin/gcc
ln -s /opt/rh/devtoolset-2/root/usr/bin/c++ /usr/bin/c++
ln -s /opt/rh/devtoolset-2/root/usr/bin/g++ /usr/bin/g++
yum install -y devtoolset-2-gcc devtoolset-2-binutils
yum install -y devtoolset-2-gcc-c++
yum install -y openssl-devel
yum install -y boost-devel
yum install -y cmake

  sudo chown -R `whoami` ~/.npm ~/tmp/ || true
}
install_gcc(){
  cd $LIB_DIR
  wget http://ftp.tsukuba.wide.ad.jp/software/gcc/releases/gcc-5.4.0/gcc-5.4.0.tar.gz
  tar -zxvf gcc-5.4.0.tar.gz
  cd gcc-5.4.0
  ./contrib/download_prerequisites
  ./configure --prefix=/usr/local/gcc5.4 --enable-checking=release --enable-languages=c,c++ --disable-multilib
  make -j4
  make install
  cd $CURRENT_DIR

}
download_openssl() {
  OPENSSL_VERSION=$1
  OPENSSL_MAJOR="${OPENSSL_VERSION%?}"
  echo "Downloading OpenSSL from https://www.openssl.org/source/$OPENSSL_MAJOR/openssl-$OPENSSL_VERSION.tar.gz"
  curl -OL https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz
  tar -zxvf openssl-$OPENSSL_VERSION.tar.gz || DOWNLOAD_SUCCESS=$?
  if [ "$DOWNLOAD_SUCCESS" -eq 1 ]
  then
    echo "Downloading OpenSSL from https://www.openssl.org/source/old/$OPENSSL_MAJOR/openssl-$OPENSSL_VERSION.tar.gz"
    curl -OL https://www.openssl.org/source/old/$OPENSSL_MAJOR/openssl-$OPENSSL_VERSION.tar.gz
    tar -zxvf openssl-$OPENSSL_VERSION.tar.gz
  fi
}

install_openssl(){
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    OPENSSL_VERSION=`node -pe process.versions.openssl`
    if [ ! -f ./openssl-$OPENSSL_VERSION.tar.gz ]; then
      download_openssl $OPENSSL_VERSION
      cd openssl-$OPENSSL_VERSION
      ./config --prefix=$PREFIX_DIR --openssldir=$PREFIX_DIR -fPIC
      make $FAST_MAKE -s V=0
      make install_sw
    else
      echo "openssl already installed"
    fi
    cd $CURRENT_DIR
  else
    mkdir -p $LIB_DIR
    install_openssl
  fi
}

install_libnice(){
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    if [ ! -f ./libnice-0.1.4.tar.gz ]; then
      curl -OL https://nice.freedesktop.org/releases/libnice-0.1.4.tar.gz
      tar -zxvf libnice-0.1.4.tar.gz
      cd libnice-0.1.4
      patch -R ./agent/conncheck.c < $PATHNAME/libnice-014.patch0
      ./configure --prefix=$PREFIX_DIR
      make $FAST_MAKE -s V=0
      make install
    else
      echo "libnice already installed"
    fi
    cd $CURRENT_DIR
  else
    mkdir -p $LIB_DIR
    install_libnice
  fi
}

install_opus(){
  [ -d $LIB_DIR ] || mkdir -p $LIB_DIR
  cd $LIB_DIR
  if [ ! -f ./opus-1.1.tar.gz ]; then
    curl -OL http://downloads.xiph.org/releases/opus/opus-1.1.tar.gz
    tar -zxvf opus-1.1.tar.gz
    cd opus-1.1
    ./configure --prefix=$PREFIX_DIR
    make $FAST_MAKE -s V=0
    make install
  else
    echo "opus already installed"
  fi
  cd $CURRENT_DIR
}

install_mediadeps(){
  install_opus
sudo rpm --import http://li.nux.ro/download/nux/RPM-GPG-KEY-nux.ro
sudo rpm -Uvh http://li.nux.ro/download/nux/dextop/el6/x86_64/nux-dextop-release-0-2.el6.nux.noarch.rpm
sudo yum install ffmpeg ffmpeg-devel -y
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    if [ ! -f ./v11.1.tar.gz ]; then
      curl -O -L https://github.com/libav/libav/archive/v11.1.tar.gz
      tar -zxvf v11.1.tar.gz
      cd libav-11.1
      PKG_CONFIG_PATH=${PREFIX_DIR}/lib/pkgconfig ./configure --prefix=$PREFIX_DIR --enable-shared --enable-gpl --enable-libvpx --enable-libx264 --enable-libopus --disable-doc
      make $FAST_MAKE -s V=0
      make install
    else
      echo "libav already installed"
    fi
    cd $CURRENT_DIR
  else
    mkdir -p $LIB_DIR
    install_mediadeps
  fi

}

install_mediadeps_nogpl(){
  install_opus
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    if [ ! -f ./v11.1.tar.gz ]; then
      curl -O -L https://github.com/libav/libav/archive/v11.1.tar.gz
      tar -zxvf v11.1.tar.gz
      cd libav-11.1
      PKG_CONFIG_PATH=${PREFIX_DIR}/lib/pkgconfig ./configure --prefix=$PREFIX_DIR --enable-shared --enable-gpl --enable-libvpx --enable-libopus --disable-doc
      make $FAST_MAKE -s V=0
      make install
    else
      echo "libav already installed"
    fi
    cd $CURRENT_DIR
  else
    mkdir -p $LIB_DIR
    install_mediadeps_nogpl
  fi
}

install_libsrtp(){
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    curl -o libsrtp-2.1.0.tar.gz https://codeload.github.com/cisco/libsrtp/tar.gz/v2.1.0
    tar -zxvf libsrtp-2.1.0.tar.gz
    cd libsrtp-2.1.0
    CFLAGS="-fPIC" ./configure --enable-openssl --prefix=$PREFIX_DIR --with-openssl-dir=$PREFIX_DIR
    make $FAST_MAKE -s V=0 && make uninstall && make install
    cd $CURRENT_DIR
  else
    mkdir -p $LIB_DIR
    install_libsrtp
  fi
}

cleanup(){
  if [ -d $LIB_DIR ]; then
    cd $LIB_DIR
    rm -r libnice*
    rm -r libsrtp*
    rm -r libav*
    rm -r v11*
    rm -r openssl*
    rm -r opus*
    cd $CURRENT_DIR
  fi
}

parse_arguments $*

mkdir -p $PREFIX_DIR

install_apt_deps
read name
check_proxy
read name
install_openssl
read name
install_libnice
read name
install_libsrtp
read name

install_opus
read name
if [ "$ENABLE_GPL" = "true" ]; then
  install_mediadeps
else
  install_mediadeps_nogpl
fi

if [ "$CLEANUP" = "true" ]; then
  echo "Cleaning up..."
  cleanup
fi
