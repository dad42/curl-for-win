#!/usr/bin/env bash

# Copyright (C) Viktor Szakats. See LICENSE.md
# SPDX-License-Identifier: MIT

# shellcheck disable=SC3040,SC2039
set -o xtrace -o errexit -o nounset; [ -n "${BASH:-}${ZSH_NAME:-}" ] && set -o pipefail

export _NAM _VER _OUT _BAS _DST

_NAM="$(basename "$0" | cut -f 1 -d '.')"
_VER="$1"

(
  cd "${_NAM}" || exit 0

  rm -r -f "${_PKGDIR:?}" "${_BLDDIR:?}"

  options="${_CONFIGURE_GLOBAL}"
  export CC="${_CC_GLOBAL}"
  export CFLAGS="${_CFLAGS_GLOBAL} ${_CFLAGS_GLOBAL_AUTOTOOLS}"
  export CPPFLAGS="${_CPPFLAGS_GLOBAL}"
  export LDFLAGS="${_LDFLAGS_GLOBAL} ${_LDFLAGS_GLOBAL_AUTOTOOLS}"
  export LIBS=''

  export PKG_CONFIG_LIBDIR=''  # Avoid picking up non-cross copies

  if [[ "${_DEPS}" = *'libidn2'* ]] && [ -d "../libidn2/${_PP}" ] && \
     [[ "${_DEPS}" = *'libiconv'* ]] && [ -d "../libiconv/${_PP}" ] && \
     [[ "${_DEPS}" = *'libunistring'* ]] && [ -d "../libunistring/${_PP}" ]; then
    CPPFLAGS+=" -I${_TOP}/libidn2/${_PP}/include"
    LDFLAGS+=" -L${_TOP}/libidn2/${_PP}/lib"
    if [ "${_OS}" = 'win' ]; then
      LIBS+=' -lws2_32'
    fi
    CPPFLAGS+=" -I${_TOP}/libiconv/${_PP}/include"
    LDFLAGS+=" -L${_TOP}/libiconv/${_PP}/lib"
    LIBS+=' -liconv -lcharset'
    CPPFLAGS+=" -I${_TOP}/libunistring/${_PP}/include"
    LDFLAGS+=" -L${_TOP}/libunistring/${_PP}/lib"
    LIBS+=' -lunistring'
    options+=' --enable-runtime=libidn2'
  else
    options+=' --disable-runtime --disable-builtin'
  fi

  (
    mkdir "${_BLDDIR}"; cd "${_BLDDIR}"
    # shellcheck disable=SC2086
    ../configure ${options} \
      --disable-rpath \
      --enable-static \
      --disable-shared \
      --disable-man --silent
  )

  make --directory="${_BLDDIR}" --jobs="${_JOBS}" install "DESTDIR=$(pwd)/${_PKGDIR}" # >/dev/null # V=1

  # Delete .pc and .la files
  rm -r -f "${_PP}"/lib/pkgconfig
  rm -f    "${_PP}"/lib/*.la

  # Make steps for determinism

  readonly _ref='NEWS'

  # shellcheck disable=SC2086
  "${_STRIP_LIB}" ${_STRIPFLAGS_LIB} "${_PP}"/lib/*.a

  touch -c -r "${_ref}" "${_PP}"/include/*.h
  touch -c -r "${_ref}" "${_PP}"/lib/*.a

  # Create package

  _OUT="${_NAM}-${_VER}${_REVSUFFIX}${_PKGSUFFIX}"
  _BAS="${_NAM}-${_VER}${_PKGSUFFIX}"
  _DST="$(pwd)/_pkg"; rm -r -f "${_DST}"

  mkdir -p "${_DST}/include"
  mkdir -p "${_DST}/lib"

  cp -f -p "${_PP}"/include/*.h "${_DST}/include/"
  cp -f -p "${_PP}"/lib/*.a     "${_DST}/lib/"
  cp -f -p NEWS                 "${_DST}/NEWS.txt"
  cp -f -p AUTHORS              "${_DST}/AUTHORS.txt"
  cp -f -p COPYING              "${_DST}/COPYING.txt"
  cp -f -p README               "${_DST}/README.txt"

  ../_pkg.sh "$(pwd)/${_ref}"
)
