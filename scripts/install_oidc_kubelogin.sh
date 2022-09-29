#!/bin/sh

case $(uname) in
  Linux)
    DL_FILE="kubelogin_linux_amd64.zip"
    ;;

  Darwin)
    case $(uname -m) in
      arm64)
        DL_FILE="kubelogin_darwin_arm64.zip"
        ;;
      x86_64)
        DL_FILE="kubelogin_darwin_amd64.zip"
        ;;
      *)
        echo "Unknown MacOS type"
        exit 1
        ;;
    esac
    ;;

  *)
    echo "Unknown OS type"
    exit 1
    ;;
esac

wget "https://github.com/int128/kubelogin/releases/latest/download/${DL_FILE}"
unzip "${DL_FILE}" kubelogin
chmod +x kubelogin
sudo mv kubelogin /usr/local/bin/oidc-kubelogin

rm "${DL_FILE}"