#!/bin/sh

# 定义颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

ARCH=""


# 日志函数
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $*${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $*${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*${NC}"
}

# 检查root权限
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "此脚本需要root权限运行"
        exit 1
    fi
}

check_vision() {
# 获取版本号并检测
    version_info=$(opkg list-installed | grep -E "(passwall|pw)" | head -1 | awk '{print $3}')

    if [ -z "$version_info" ]; then
        error "未找到PassWall包"
        log "执行安装命令..."
        download_ipk #下载ipk升级文件
        install_ipk #安装ipk升级文件
    fi
    sleep 1
    version_info=$(opkg list-installed | grep -E "(passwall|pw)" | head -1 | awk '{print $3}')
    # 提取主版本号
    if echo "$version_info" | grep -q "git-"; then
        main_version=$(echo "$version_info" | sed 's/git-//' | cut -d'.' -f1 | tr -cd '0-9')
    else
        main_version=$(echo "$version_info" | cut -d'.' -f1 | tr -cd '0-9')
    fi

    log "检测到版本: $version_info"
    log "主版本号: $main_version"
    sleep 1
    # 执行相应命令
    if [ -n "$main_version" ] && [ "$main_version" -ge 20 ] && [ "$main_version" -le 29 ]; then
        log "执行安装依赖命令..."
        # 这里放置2.x版本的命令
        download_sf #下载依赖软件
        setup_binary #设置二进制文件
    else
        log "执行升级以及安装依赖命令..."
        # 这里放置其他版本的命令
        download_ipk #下载ipk升级文件
        install_ipk #安装ipk升级文件
        download_sf #下载依赖软件
        setup_binary #设置二进制文件
    fi
}


# 检测系统架构
detect_arch() {
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        "x86_64")
            ARCH="amd64"
            ;;
        "i686"|"i386")
            ARCH="386"
            ;;
        "aarch64"|"arm64")
            ARCH="arm64"
            ;;
        "armv7l"|"armv6l")
            ARCH="armv7"
            ;;
        "mips")
            ARCH="mips"
            ;;
        "mipsel")
            ARCH="mipsel"
            ;;
        *)
            error "不支持的架构: $arch"
            exit 1
            ;;
    esac
    
    log "检测到系统架构: $ARCH"
}

# 定义下载URL
BASE_URL="http://199.7.140.77/pw"
IPK_FILES="luci-19.07_luci-app-passwall_25.9.23-1_all.ipk luci-19.07_luci-i18n-passwall-zh-cn_25.9.23-1_all.ipk"

# 创建临时目录
create_temp_dir() {
    TEMP_DIR=$(mktemp -d)
    log "创建临时目录: $TEMP_DIR"
}

# 清理函数
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        log "清理临时目录: $TEMP_DIR"
        rm -rf "$TEMP_DIR"
    fi
}

# 设置退出时自动清理
trap cleanup EXIT

# 下载依赖文件
download_sf() {
    log "开始下载依赖软件..."

  
    # 下载二进制文件
    local binary_url="$BASE_URL/$ARCH.zip"
    local binary_dest="$TEMP_DIR/$ARCH.zip"
    
    log "下载二进制文件"

    if wget -O "$binary_dest" "$binary_url"; then
        log "下载成功: $BINARY_FILE"
    else
        error "下载失败: $BINARY_FILE"
        exit 1
    fi
}
#下载ipk升级文件
download_ipk(){
    log "开始下载IPK包..."
    
    for ipk in $IPK_FILES; do
        local url="$BASE_URL/$ipk"
        local dest="$TEMP_DIR/$ipk"
        
        log "下载IPK: $url"
        if wget -q -O "$dest" "$url"; then
            chmod +x "$dest"
            log "下载成功: $ipk"
        else
            error "下载失败: $ipk"
            exit 1
        fi
    done
}

# 安装IPK包
install_ipk() {
    log "开始安装IPK包..."
    
    for ipk in $IPK_FILES; do
        local ipk_path="$TEMP_DIR/$ipk"
        
        if [ -f "$ipk_path" ]; then
            log "安装包: $ipk"
            if opkg install "$ipk_path"; then
                log "安装成功: $ipk"
            else
                warn "安装可能有问题: $ipk"
            fi
        else
            error "文件不存在: $ipk_path"
            exit 1
        fi
    done
}

# 处理二进制文件
setup_binary() {
    log "设置二进制文件..."
    
    local binary_src="$TEMP_DIR/$ARCH.zip"
    local binary_dest="/usr/bin/"
    
    if [ -f "$binary_src" ]; then
        #创建新的临时目录用于解压
        log "创建解压临时目录"
        mkdir -p "$TEMP_DIR/unzip"
        # 解压二进制文件
        log "解压二进制文件"
        unzip -o "$binary_src" -d "$TEMP_DIR/unzip"
        binary_src="$TEMP_DIR/unzip/"  #更新二进制文件路径
        # 给二进制文件添加执行权限
        log "添加执行权限:"
        chmod +x "$binary_src"/*
        
        # 移动到系统目录
        log "移动文件到系统目录"
        mv "$binary_src"/* "$binary_dest"
        
        # 验证安装
        if [ -x "$binary_dest" ]; then
            log "二进制文件设置成功"
        else
            error "二进制文件设置失败"
            exit 1
        fi
    else
        error "二进制文件不存在: $binary_src"
        exit 1
    fi
}


# 主函数
main() {
    log "开始流程..."
    
    check_root
    detect_arch
    create_temp_dir
    check_vision
    log "安装完成"
}

# 运行主函数
main "$@"