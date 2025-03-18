#!/bin/bash

# 安装和更新软件包
UPDATE_PACKAGE() {
    local PKG_NAME=$1
    local PKG_REPO=$2
    local PKG_BRANCH=$3
    local PKG_SPECIAL=$4
    local CUSTOM_NAMES=($5)  # 第5个参数为自定义名称列表
    local REPO_NAME=$(echo $PKG_REPO | cut -d '/' -f 2)

    echo " "

    # 将 PKG_NAME 加入到需要查找的名称列表中
    if [ ${#CUSTOM_NAMES[@]} -gt 0 ]; then
        CUSTOM_NAMES=("$PKG_NAME" "${CUSTOM_NAMES[@]}")  # 将 PKG_NAME 添加到自定义名称列表的开头
    else
        CUSTOM_NAMES=("$PKG_NAME")  # 如果没有自定义名称，则只使用 PKG_NAME
    fi

    # 删除本地可能存在的不同名称的软件包
    for NAME in "${CUSTOM_NAMES[@]}"; do
        # 查找匹配的目录
        echo "Searching directory: $NAME"
        local FOUND_DIRS=$(find ../feeds/luci/ ../feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

        # 删除找到的目录
        if [ -n "$FOUND_DIRS" ]; then
            echo "$FOUND_DIRS" | while read -r DIR; do
                rm -rf "$DIR"
                echo "Deleted directory: $DIR"
            done
        else
            echo "No directories found matching name: $NAME"
        fi
    done

    # 克隆 GitHub 仓库
    git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git"

    # 处理克隆的仓库
    if [[ $PKG_SPECIAL == "pkg" ]]; then
        find ./$REPO_NAME/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./ \;
        rm -rf ./$REPO_NAME/
    elif [[ $PKG_SPECIAL == "name" ]]; then
        mv -f $REPO_NAME $PKG_NAME
    fi
}

# 更新软件包版本
UPDATE_VERSION() {
    local PKG_NAME=$1
    local PKG_MARK=${2:-false}
    local PKG_FILES=$(find ./ ../feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

    if [ -z "$PKG_FILES" ]; then
        echo "$PKG_NAME not found!"
        return
    fi

    echo -e "\n$PKG_NAME version update has started!"

    for PKG_FILE in $PKG_FILES; do
        # 特殊处理 sing-box 版本
        if [ "$PKG_NAME" = "sing-box" ]; then
            local PKG_REPO="SagerNet/sing-box"
            local PKG_TAG="v1.10.0-beta.3"
        else
            local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
            local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")
        fi

        local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
        local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
        local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
        local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

        local PKG_URL=$([[ $OLD_URL == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

        # 处理 sing-box 的特殊版本格式
        if [ "$PKG_NAME" = "sing-box" ]; then
            local NEW_VER=$(echo $PKG_TAG | sed 's/^v//')  # 移除v前缀
            local NEW_URL="https://github.com/${PKG_REPO}/releases/download/${PKG_TAG}/sing-box-${NEW_VER}.tar.gz"
        else
            local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
            local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
        fi

        local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

        echo "old version: $OLD_VER $OLD_HASH"
        echo "new version: $NEW_VER $NEW_HASH"

        # 强制更新 sing-box 版本
        if [ "$PKG_NAME" = "sing-box" ]; then
            sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
            sed -i "s|PKG_SOURCE_URL:=.*|PKG_SOURCE_URL:=$NEW_URL|g" "$PKG_FILE"
            sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
            echo "$PKG_FILE version has been forced to $NEW_VER!"
        elif [[ $NEW_VER =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
            sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
            sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
            echo "$PKG_FILE version has been updated!"
        else
            echo "$PKG_FILE version is already the latest!"
        fi
    done
}

# 调用示例
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-24.10"
#UPDATE_PACKAGE "homeproxy" "VIKINGYFY/homeproxy" "main"
UPDATE_PACKAGE "homeproxy" "muink/homeproxy" "master"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "xiaorouji/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "ssr-plus" "fw876/helloworld" "master"

UPDATE_PACKAGE "luci-app-tailscale" "asvow/luci-app-tailscale" "main"
UPDATE_PACKAGE "luci-app-wol" "VIKINGYFY/packages" "main" "pkg"

UPDATE_PACKAGE "alist" "sbwml/luci-app-alist" "main"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "gecoosac" "lwb1978/openwrt-gecoosac" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "qmodem" "FUjr/modem_feeds" "main"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

if [[ $WRT_REPO != *"immortalwrt"* ]]; then
    UPDATE_PACKAGE "qmi-wwan" "immortalwrt/wwan-packages" "master" "pkg"
fi

# 强制更新 sing-box 到指定版本
UPDATE_VERSION "sing-box" true

# 更新其他软件包
UPDATE_VERSION "tailscale"
