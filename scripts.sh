#!/bin/bash
# 微信公众号 AI 热点发布工具 - 脚本（直接使用 URL 生成封面）
# 使用方法: source scripts.sh

# ============ 配置 ============
# 推荐使用 .env + `set -a; source .env; set +a`

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: missing command: $1" >&2
        return 1
    }
}

require_env() {
    local name=$1
    if [[ -z "${!name:-}" ]]; then
        echo "ERROR: missing env var: ${name}" >&2
        return 1
    fi
}

# ============ 公众号 API ============

# 获取 access_token
get_wechat_token() {
    require_cmd curl || return 1
    require_cmd jq || return 1
    require_env WECHAT_APPID || return 1
    require_env WECHAT_SECRET || return 1
    curl -s "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=${WECHAT_APPID}&secret=${WECHAT_SECRET}" | jq -r '.access_token'
}

# 上传图片到公众号素材库（永久素材）
# 用法: upload_wechat_image <token> <image_path>
upload_wechat_image() {
    require_cmd curl || return 1
    local token=$1
    local image_path=$2
    curl -s -X POST "https://api.weixin.qq.com/cgi-bin/material/add_material?access_token=${token}&type=image" \
        -F "media=@${image_path}"
}

# 创建草稿
# 用法: create_draft <token> <json_file>
create_draft() {
    require_cmd curl || return 1
    local token=$1
    local json_file=$2
    curl -s -X POST "https://api.weixin.qq.com/cgi-bin/draft/add?access_token=${token}" \
        -H "Content-Type: application/json" \
        -d @"${json_file}"
}

# 发布草稿
# 用法: publish_draft <token> <media_id>
publish_draft() {
    require_cmd curl || return 1
    local token=$1
    local media_id=$2
    curl -s -X POST "https://api.weixin.qq.com/cgi-bin/freepublish/submit?access_token=${token}" \
        -H "Content-Type: application/json" \
        -d "{\"media_id\": \"${media_id}\"}"
}

# ============ 图片下载 ============

# 下载图片
# 用法: download_image <url> <output_path>
download_image() {
    require_cmd curl || return 1
    local url=$1
    local output_path=$2
    curl -fsSL -o "${output_path}" "${url}" || {
        echo "ERROR: download failed" >&2
        return 1
    }
}

# 生成封面图文件（直接用 URL）
# 用法: create_cover_file <image_url> <article_id>
create_cover_file() {
    require_cmd jq || return 1
    local image_url=$1
    local article_id=$2
    local tmp_file="/tmp/wechat_cover_${article_id}.png"

    echo "正在下载封面图: $image_url"
    if ! download_image "$image_url" "$tmp_file"; then
        if [[ -n "${DEFAULT_COVER_URL:-}" ]]; then
            echo "封面图下载失败，使用 DEFAULT_COVER_URL 兜底..."
            download_image "$DEFAULT_COVER_URL" "$tmp_file" || {
                echo "ERROR: 兜底封面下载失败" >&2
                return 1
            }
        else
            echo "ERROR: 封面图下载失败且无 DEFAULT_COVER_URL" >&2
            return 1
        fi
    fi

    echo "$tmp_file"
}

# ============ 完整发布流程 ============

# 用法: publish_article <title> <content_html> <cover_image_url> <digest>
publish_article() {
    require_cmd jq || return 1
    local title=$1
    local content_html=$2
    local cover_image_url=$3
    local digest=$4
    local article_id=$(date +%Y%m%d%H%M%S)
    local author=${WECHAT_AUTHOR:-"足球咨询速递"}

    echo "=== 开始发布流程 ==="

    # 1. 获取 token
    echo "1. 获取 access_token..."
    local token=$(get_wechat_token)
    if [[ -z "$token" || "$token" == "null" ]]; then
        echo "ERROR: 获取 token 失败"
        return 1
    fi

    # 2. 下载封面图
    echo "2. 下载封面图..."
    local cover_file
    if ! cover_file=$(create_cover_file "$cover_image_url" "$article_id"); then
        return 1
    fi
    echo "   封面图文件: $cover_file"

    # 3. 上传封面到公众号素材库
    echo "3. 上传封面到公众号素材库..."
    local media_response=$(upload_wechat_image "$token" "$cover_file")
    local thumb_media_id=$(echo "$media_response" | jq -r '.media_id')
    rm -f "$cover_file"

    if [[ -z "$thumb_media_id" || "$thumb_media_id" == "null" ]]; then
        echo "ERROR: 上传封面失败"
        echo "$media_response"
        return 1
    fi
    echo "   Media ID: $thumb_media_id"

    # 4. 创建草稿
    echo "4. 创建草稿..."
    local draft_json="/tmp/draft_${article_id}.json"
    jq -n \
        --arg title "$title" \
        --arg author "$author" \
        --arg digest "$digest" \
        --arg content "$content_html" \
        --arg thumb_media_id "$thumb_media_id" \
        '{
            articles: [{
                title: $title,
                author: $author,
                digest: $digest,
                content: $content,
                thumb_media_id: $thumb_media_id,
                need_open_comment: 1,
                only_fans_can_comment: 0
            }]
        }' > "$draft_json"

    local draft_response=$(create_draft "$token" "$draft_json")
    local draft_media_id=$(echo "$draft_response" | jq -r '.media_id')
    rm -f "$draft_json"

    if [[ -z "$draft_media_id" || "$draft_media_id" == "null" ]]; then
        echo "ERROR: 创建草稿失败"
        echo "$draft_response"
        return 1
    fi

    echo "=== 草稿创建成功 ==="
    echo "草稿 Media ID: $draft_media_id"
    echo "请在公众号后台查看并发布"
}

echo "脚本已加载。可用函数:"
echo "  get_wechat_token        - 获取公众号 access_token"
echo "  create_cover_file       - 下载封面图文件 (直接用 URL)"
echo "  publish_article         - 完整发布流程 (可传封面 URL)"
