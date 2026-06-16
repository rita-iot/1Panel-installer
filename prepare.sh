#!/bin/bash

set -ex

BASE_DIR=$(cd "$(dirname "$0")" || exit 1; pwd)

while [[ $# -gt 0 ]]; do
    lowerI="$(echo "$1" | awk '{print tolower($0)}')"
    case $lowerI in
        --app_version)    app_version=$2; shift ;;
        --docker_version) docker_version=$2; shift ;;
        --compose_version)compose_version=$2; shift ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
    shift
done

# 默认保底版本同步更新
APP_VERSION=${app_version:-v1.10.34-lts}
DOCKER_VERSION=${docker_version:-29.4.1}
COMPOSE_VERSION=${compose_version:-v5.1.4}

if [ -d "build" ]; then
    rm -rf build/*
fi

for ARCHITECTURE in aarch64 x86_64; do
    cd "${BASE_DIR}" || exit 1

    case "${ARCHITECTURE}" in
        "aarch64") ARCH="arm64" ;;
        "x86_64")  ARCH="amd64" ;;
    esac

    DOCKER_BIN_URL="https://download.docker.com/linux/static/stable/${ARCHITECTURE}/docker-${DOCKER_VERSION}.tgz"
    COMPOSE_BIN_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-${ARCH}"

    BUILD_NAME=1panel-${APP_VERSION}-linux-${ARCH}
    BUILD_DIR=build/${APP_VERSION}/${BUILD_NAME}
    mkdir -p "${BUILD_DIR}"

    BUILD_OFFLINE_NAME=1panel-${APP_VERSION}-offline-linux-${ARCH}
    BUILD_OFFLINE_DIR=build/${APP_VERSION}/${BUILD_OFFLINE_NAME}
    mkdir -p "${BUILD_OFFLINE_DIR}"

    if [ ! -d "compiled_bins/${ARCH}" ]; then
        echo "Error: compiled_bins/${ARCH}/1panel not found!"
        exit 1
    fi
    
    # 抓取现场交叉编译好的正版二进制文件
    cp -f "compiled_bins/${ARCH}/1panel" "${BUILD_DIR}/"
    cp -f "compiled_bins/${ARCH}/1panel" "${BUILD_OFFLINE_DIR}/"
    
    # 动态构建系统 service 文件
    cat << EOF > "${BUILD_DIR}/1panel.service"
[Unit]
Description=1Panel Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/bin
ExecStart=/usr/local/bin/1panel
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    cp -f "${BUILD_DIR}/1panel.service" "${BUILD_OFFLINE_DIR}/1panel.service"

    # 下载对应架构的离线 Docker
    if [ ! -f "${BUILD_OFFLINE_DIR}/docker.tgz" ]; then
        wget -q "${DOCKER_BIN_URL}" -O "${BUILD_OFFLINE_DIR}/docker.tgz"
    fi

    # 下载对应架构的离线 Docker Compose v5+ 插件
    if [ ! -f "${BUILD_DIR}/docker-compose" ]; then
        wget -q "${COMPOSE_BIN_URL}" -O "${BUILD_DIR}/docker-compose"
    fi

    if [ ! -f "${BUILD_OFFLINE_DIR}/docker-compose" ]; then
        cp -f "${BUILD_DIR}/docker-compose" "${BUILD_OFFLINE_DIR}/docker-compose"
    fi

    # 封入公共脚本组件
    cp -f docker.service "${BUILD_DIR}/"
    cp -f docker.service "${BUILD_OFFLINE_DIR}/"
    cp -f install.sh "${BUILD_DIR}/"
    cp -f install.sh "${BUILD_OFFLINE_DIR}/"
    
    if [ -d "lang" ]; then
        cp -rf lang "${BUILD_DIR}/"
        cp -rf lang "${OFFLINE_OFFLINE_DIR:-$BUILD_OFFLINE_DIR}/"
    fi

    chmod +x "${BUILD_OFFLINE_DIR}/docker-compose"
    chmod +x "${BUILD_DIR}/install.sh" "${BUILD_OFFLINE_DIR}/install.sh"
    chown -R root:root "${BUILD_DIR}" "${BUILD_OFFLINE_DIR}"

    cd "build/${APP_VERSION}" || exit 1
    tar -zcf "${BUILD_NAME}.tar.gz" "${BUILD_NAME}"
    tar -zcf "${BUILD_OFFLINE_NAME}.tar.gz" "${BUILD_OFFLINE_NAME}"
done

cd "${BASE_DIR}/build/${APP_VERSION}" || exit 1
sha256sum 1panel-*.tar.gz > checksums.txt
ls -al "${BASE_DIR}/build/${APP_VERSION}"
