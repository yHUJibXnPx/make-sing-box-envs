#!/bin/bash
IFS_BAK=$IFS
IFS=$'\n'
set -e

echo "检查操作系统..."

if [[ "$(uname)" != "Darwin" ]]; then
  echo "本脚本仅支持 macOS。"
  exit 1
fi

echo "操作系统是 macOS"

# 检查 brew 是否已安装
if ! command -v brew >/dev/null 2>&1; then
  echo "未检测到 Homebrew，正在安装..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # 配置环境变量（适配 arm64）
  echo '正在设置环境变量...'
  arch_name="$(uname -m)"

  if [[ "$SHELL" == */zsh ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.bash_profile
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  echo "已安装 Homebrew"
fi

# 强制更新 Homebrew 本体和软件包信息
echo "正在更新 brew..."
brew update

# 安装 grep (GNU 版本)
echo "安装/升级 grep (GNU)..."
brew install grep || brew upgrade grep

# 安装 jq（后面提取节点、按国家分组全靠它，macOS 不自带）
echo "安装/升级 jq..."
brew install jq || brew upgrade jq

# 安装 unar（解压 .rar/.zip）
echo "安装/升级 unar..."
brew install unar || brew upgrade unar

# 将 ggrep 设置为默认 grep（添加到 shell 配置）
if ! grep -q 'alias grep=' ~/.zshrc 2>/dev/null; then
  echo "alias grep='ggrep'" >> ~/.zshrc
  echo "添加 alias grep='ggrep' 到 ~/.zshrc"
fi

echo "所有工具安装完成，请重新打开终端或执行 'source ~/.zshrc'"

alias grep='ggrep'
command -v grep

USER_HOME="$HOME"
SING_BOX_DIR_PATH="${USER_HOME}/Desktop/sing-boxs"
if [[ ! -d ${SING_BOX_DIR_PATH} && ! -f ${SING_BOX_DIR_PATH} ]]; then
  SING_BOX_DIR=${SING_BOX_DIR_PATH}'/sing-box_config'
else
  SING_BOX_DIR_PATH=${SING_BOX_DIR_PATH}-$(uuidgen)
  SING_BOX_DIR=${SING_BOX_DIR_PATH}'/sing-box_config'
fi

# =========================
# 订阅输入（URL / 本地文件）
# =========================
echo "请输入订阅来源（https 链接 / Sub-Store 下载链 / 本地文件路径）"
echo "直接回车则使用默认（不保证有效）:"
echo "默认: https://github.com/Au1rxx/free-vpn-subscriptions/raw/main/output/singbox.json"
read -r SUBS
SUBS=${SUBS:-'https://github.com/Au1rxx/free-vpn-subscriptions/raw/main/output/singbox.json'}

# 本地文件：不走 URL 编码、不强制进转换 API
if [[ -f "$SUBS" ]]; then
  SUBS_KIND="file"
  SUBS_SRC="$SUBS"
elif [[ "$SUBS" == file://* ]]; then
  SUBS_KIND="file"
  SUBS_SRC="${SUBS#file://}"
  if [[ ! -f "$SUBS_SRC" ]]; then
    echo "本地文件不存在: $SUBS_SRC"
    exit 1
  fi
else
  SUBS_KIND="url"
  SUBS_SRC="$SUBS"
fi

# =========================
# 转换 API（可选）
# 仅当「原文不是 sing-box JSON」时使用
# 输入 none / off / disable 表示禁用
# =========================
echo "请输入在线订阅转换 API（仅订阅来源非 sing-box JSON 时使用）"
echo "输入 none 禁用转换；直接回车使用默认:"
echo "默认: https://sub.d1.mk/sub"
read -r SUBS_API
SUBS_API=${SUBS_API:-'https://sub.d1.mk/sub'}
if [[ "$(echo "$SUBS_API" | tr 'A-Z' 'a-z')" =~ ^(none|off|disable|disabled)$ ]]; then
  SUBS_API="none"
fi

# 供启动脚本使用的变量（不再拼死 SUB_URL）
# SUBS_KIND / SUBS_SRC / SUBS_API 会写入 sing-box-start.sh
SING_BOX_PATH='/SagerNet/sing-box/releases/download/v1.15.0-alpha.4'
VERSION=sing-box-$(basename ${SING_BOX_PATH} | tr 'A-Z' 'a-z' | sed 's;v;;g')-darwin-arm64.tar.gz
echo "https://github.com${SING_BOX_PATH}/${VERSION}"
SING_BOX_BIN_FILE_URL="https://github.com${SING_BOX_PATH}/${VERSION}"
SING_BOX_BIN_FILE_GZ="${SING_BOX_DIR_PATH}/${VERSION}"
SING_BOX_BIN_FILE="$(echo ${SING_BOX_BIN_FILE_GZ} | sed 's;.tar.gz;;g')"
SING_BOX_BIN_FILE_RENAME="${SING_BOX_DIR_PATH}/sing-box"
UI_PATH=$(curl -SL --connect-timeout 30 -m 60 --speed-time 30 --speed-limit 1 --retry 2 -H "Connection: keep-alive" -k 'https://github.com/Zephyruso/zashboard/releases' | sed 's;";\n;g;s;tag;download;g' | grep '/download/' | head -n 1)
UI_URL="https://github.com${UI_PATH}/dist.zip"
UI_FILE=${SING_BOX_DIR}'/ui.zip'
SING_BOX_CONFIG_TEMPLATES_URL="https://github.com/yHUJibXnPx/make-sing-box-envs/raw/refs/heads/master/1.15.0-alpha.4.json"
SING_BOX_CONFIG_TEMPLATES_FILE=${SING_BOX_DIR_PATH}'/1.15.0-alpha.4.json'
TMP_FILE=${SING_BOX_DIR_PATH}'/temp_config.json'
OUT_FILE=${SING_BOX_DIR_PATH}'/out_config.json'
BASE_FILE=${SING_BOX_DIR_PATH}'/base_config.json'
SING_BOX_FILE=${SING_BOX_DIR_PATH}'/config.json'
NODES=${SING_BOX_DIR_PATH}'/filtered_nodes.json'
NODES_CONFIG=${SING_BOX_DIR_PATH}'/config_with_nodes.json'
# other
#游戏_469138946ba5fa|游戏|Game|加速|Steam|Origin|🎮
#流媒体_469138946ba5fa|Netflix|奈飞|Media|NF|Disney|YouTube|流媒体|🎥
#省流_469138946ba5fa|省流|低倍率|大流量|0.1x|0.2x|📺
#高级_469138946ba5fa|专线|高级|IEPL|IPLC|AIA|CTM|CC|Premium|👍
#智能_469138946ba5fa|AI|GPT|ChatGPT|OpenAI|Claude|Anthropic|Gemini|Google AI|Copilot|Microsoft AI|Perplexity|🤖
GROUPS_PATTERNS=$(cat <<'469138946ba5fa'
德国_469138946ba5fa|德国|德|\bDE\b|Germany|Frankfurt|Frankfurt am Main|Berlin|Munich|München|Hamburg|Dusseldorf|Düsseldorf|Cologne|Köln|Stuttgart|法兰克福|柏林|慕尼黑|汉堡|杜塞尔多夫|科隆|斯图加特|🇩🇪
日本_469138946ba5fa|日本|日|\bJP\b|Japan|Tokyo|Osaka|Nagoya|Yokohama|Sapporo|Fukuoka|东京|大阪|名古屋|横滨|札幌|福冈|🇯🇵
新加坡_469138946ba5fa|新加坡|坡|\bSG\b|Singapore|Singapore City|Lion City|狮城|🇸🇬
香港_469138946ba5fa|香港|港|\bHK\b|Hong Kong|HongKong|HKG|🇭🇰
台湾_469138946ba5fa|台湾|台|\bTW\b|Taiwan|Taipei|Taichung|Kaohsiung|Tainan|Hsinchu|Changhua|New Taipei|台北|台中|高雄|台南|新竹|彰化|新北|🇹🇼
韩国_469138946ba5fa|韩国|韩|\bKR\b|Korea|South Korea|Seoul|Busan|Incheon|首尔|釜山|仁川|🇰🇷
英国_469138946ba5fa|英国|英|\bUK\b|GB|United Kingdom|England|London|Manchester|伦敦|曼彻斯特|🇬🇧
加拿大_469138946ba5fa|加拿大|加|\bCA\b|Canada|Toronto|Vancouver|Montreal|多伦多|温哥华|蒙特利尔|🇨🇦
澳大利亚_469138946ba5fa|澳大利亚|澳|\bAU\b|Australia|Sydney|Melbourne|Brisbane|Perth|悉尼|墨尔本|布里斯班|珀斯|🇦🇺
法国_469138946ba5fa|法国|法|\bFR\b|France|Paris|Marseille|巴黎|马赛|🇫🇷
荷兰_469138946ba5fa|荷兰|荷|\bNL\b|Netherlands|Amsterdam|阿姆斯特丹|🇳🇱
美国_469138946ba5fa|美国|美|\bUS\b|USA|United States|America|Los Angeles|LA|San Francisco|SF|Silicon Valley|San Jose|Seattle|Chicago|Dallas|New York|NY|Miami|Atlanta|Ashburn|Phoenix|Las Vegas|Denver|洛杉矶|旧金山|硅谷|圣何塞|西雅图|芝加哥|达拉斯|纽约|迈阿密|亚特兰大|阿什本|凤凰城|拉斯维加斯|丹佛|🇺🇸
469138946ba5fa
)
BASE_SING_BOX_CONFIG_FIXSCRIPT=$(cat <<'469138946ba5fa'
# 需要用 Python 或 JSON 专用工具转换
#command -v python
import json
import sys

def ensure_tls_insecure(node):
    """
    为支持 TLS 的 outbound 节点插入 tls.insecure = true
    """
    if not isinstance(node, dict):
        return node

    tls_supported = {"http", "vmess", "trojan", "hysteria", "vless", 
                     "shadowtls", "tuic", "hysteria2", "anytls"}

    if node.get("type") in tls_supported:
        tls = node.get("tls")
        if isinstance(tls, dict):
            # 只在 TLS 实际启用时才处理
            if tls.get("enabled", True):
                if "insecure" not in tls:
                    tls["insecure"] = True
        else:
            # 没有 tls 字段，补全
            #node["tls"] = {"enabled": True, "insecure": True}
            # 没有 tls 字段 = 不启用 TLS，不需要补全
            pass  # 替换掉原来的 else 分支

    return node

input_path = sys.argv[1]
output_path = sys.argv[2]

with open(input_path, "r", encoding="utf-8") as f:
    data = json.load(f)

#if isinstance(data, dict) and isinstance(data.get("outbounds"), list):
#    data["outbounds"] = [ensure_tls_insecure(node) for node in data["outbounds"]]

with open(output_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"修复完成，所有 outbounds 节点已确保包含 tls.insecure: true → {output_path}")
469138946ba5fa
)
GROUPS_FILE=${SING_BOX_DIR_PATH}'/group_patterns.txt'
BASE_CONFIG_FIXSCRIPT_FILE=${SING_BOX_DIR_PATH}'/subs-fix.py'
SING_BOX_START=${SING_BOX_DIR_PATH}'/sing-box-start.sh'

mkdir -pv ${SING_BOX_DIR}

curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o ${SING_BOX_BIN_FILE_GZ} ${SING_BOX_BIN_FILE_URL}
[ ! -f "$SING_BOX_BIN_FILE_GZ" ] && echo "sing-box压缩文件不存在：$SING_BOX_BIN_FILE_GZ" && exit 1
curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o ${UI_FILE} ${UI_URL}
[ ! -f "$UI_FILE" ] && echo "UI压缩文件不存在：$UI_FILE" && exit 1
curl -L -C - --retry 3 --retry-delay 5 --progress-bar -o ${SING_BOX_CONFIG_TEMPLATES_FILE} ${SING_BOX_CONFIG_TEMPLATES_URL}
[ ! -f "$SING_BOX_CONFIG_TEMPLATES_FILE" ] && echo "模板配置文件不存在：$SING_BOX_CONFIG_TEMPLATES_FILE" && exit 1

unar -f ${SING_BOX_BIN_FILE_GZ} -o ${SING_BOX_DIR_PATH}
mv -fv ${SING_BOX_BIN_FILE}/sing-box ${SING_BOX_BIN_FILE_RENAME}
rm -frv ${SING_BOX_BIN_FILE}
chmod -v a+x ${SING_BOX_BIN_FILE_RENAME}
if [[ -d ${SING_BOX_DIR}/ui ]]; then
  rm -frv ${SING_BOX_DIR}/ui
fi
unzip -o ${SING_BOX_DIR}'/ui.zip' -d ${SING_BOX_DIR}
mv -fv ${SING_BOX_DIR}/dist ${SING_BOX_DIR}/ui

# 合并自定义头部 + 提取部分
echo "${GROUPS_PATTERNS}" > "${GROUPS_FILE}"
[ ! -f "$GROUPS_FILE" ] && echo "分组定义文件不存在：$GROUPS_FILE" && exit 1
echo "${BASE_SING_BOX_CONFIG_FIXSCRIPT}" > "${BASE_CONFIG_FIXSCRIPT_FILE}"
[ ! -f "$BASE_CONFIG_FIXSCRIPT_FILE" ] && echo "修复脚本文件不存在：$BASE_CONFIG_FIXSCRIPT_FILE" && exit 1

chmod -Rv u+rwX,go-rwx ${SING_BOX_DIR_PATH}
chown -Rv $USER ${SING_BOX_DIR_PATH}

cat << 469138946ba5fa | tee ${SING_BOX_START}
#!/bin/bash
IFS_BAK=\$IFS
IFS=\$'\n'
set -e

echo "start sing-box..."
if [ -f '${TMP_FILE}' ]; then
  rm -fv '${TMP_FILE}'
fi

# -L --retry 3 --retry-delay 5 --progress-bar 
# =========================
# 订阅拉取 + 分支转换 → 得到 TMP_FILE（sing-box JSON）
# =========================
TMP_RAW='${SING_BOX_DIR_PATH}/tmp_raw_sub'
TMP_FILE='${TMP_FILE}'
SUBS_KIND='${SUBS_KIND}'
SUBS_SRC='${SUBS_SRC}'
SUBS_API='${SUBS_API}'

rm -f "\$TMP_RAW" "\$TMP_FILE"

urlencode() {
  # 优先 python3，避免依赖外部工具
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=""))' "\$1"
  else
    local LANG=C
    local length="\${#1}"
    local i c
    for (( i = 0; i < length; i++ )); do
      c="\${1:i:1}"
      case \$c in
        [a-zA-Z0-9.~_-]) printf '%s' "\$c" ;;
        *) printf '%%%02X' "'\$c" ;;
      esac
    done
  fi
}

fetch_raw() {
  local dest="\$1"
  if [[ "\$SUBS_KIND" == "file" ]]; then
    if [[ ! -f "\$SUBS_SRC" ]]; then
      echo "Error: local subscription file not found: \$SUBS_SRC"
      exit 1
    fi
    cp -f "\$SUBS_SRC" "\$dest"
    echo "Loaded local subscription: \$SUBS_SRC"
  else
    if ! curl -fsSL -k --retry 3 --retry-delay 5 --progress-bar -o "\$dest" "\$SUBS_SRC"; then
      echo "Error: failed to download subscription: \$SUBS_SRC"
      exit 2
    fi
    echo "Downloaded subscription: \$SUBS_SRC"
  fi
  if [[ ! -s "\$dest" ]]; then
    echo "Error: subscription content is empty: \$dest"
    exit 1
  fi
}

is_singbox_json() {
  command -v jq >/dev/null 2>&1 || return 1
  jq -e 'type == "object" and (.outbounds | type == "array")' "\$1" >/dev/null 2>&1
}

# 有的转换器会返回「纯 outbounds 数组」，包一层便于后续 jq
normalize_to_singbox_file() {
  local src="\$1" dest="\$2"
  if jq -e 'type == "array"' "\$src" >/dev/null 2>&1; then
    jq '{ "outbounds": . }' "\$src" > "\$dest"
  else
    cp -f "\$src" "\$dest"
  fi
}

convert_via_api() {
  local api="\$1" src_ref="\$2" dest="\$3"
  local enc tmp_conv
  tmp_conv='${SING_BOX_DIR_PATH}/tmp_converted.json'

  if [[ "\$api" == "none" ]]; then
    echo "Error: content is not sing-box JSON, and conversion API is disabled (SUBS_API=none)."
    exit 1
  fi

  # 本地文件：很多在线 API 无法读你的磁盘，提示改用 URL 或先转成 sing-box
  if [[ "\$SUBS_KIND" == "file" ]]; then
    echo "Error: online conversion API cannot read local files."
    echo "请改用: 1) 已是 sing-box 的 JSON 文件  2) 可公网/局域网访问的订阅 URL  3) Sub-Store 的 sing-box 下载链"
    exit 1
  fi

  enc=\$(urlencode "\$src_ref")
  echo "Converting via API: \$api"
  if ! curl -fsSL -k --retry 3 --retry-delay 5 --progress-bar -o "\$tmp_conv" \\
    "\${api}?target=singbox&insert=false&new_name=true&scv=true&udp=true&exclude=&include=&url=\${enc}"; then
    echo "Error: conversion API request failed."
    exit 2
  fi
  if [[ ! -s "\$tmp_conv" ]]; then
    echo "Error: conversion API returned empty body."
    exit 1
  fi
  if ! is_singbox_json "\$tmp_conv"; then
    # 尝试数组形式
    if jq -e 'type == "array"' "\$tmp_conv" >/dev/null 2>&1; then
      normalize_to_singbox_file "\$tmp_conv" "\$dest"
      return 0
    fi
    echo "Error: conversion API did not return sing-box JSON."
    head -c 400 "\$tmp_conv" || true
    echo
    exit 1
  fi
  cp -f "\$tmp_conv" "\$dest"
}

# ---- 主流程：原文 → TMP_FILE ----
fetch_raw "\$TMP_RAW"

if is_singbox_json "\$TMP_RAW"; then
  echo "Detected sing-box JSON — skip conversion API (preserves Reality fields better)."
  normalize_to_singbox_file "\$TMP_RAW" "\$TMP_FILE"
elif jq -e 'type == "array" and (.[0] | type == "object")' "\$TMP_RAW" >/dev/null 2>&1; then
  echo "Detected JSON array — wrap as outbounds."
  normalize_to_singbox_file "\$TMP_RAW" "\$TMP_FILE"
else
  echo "Not sing-box JSON — try conversion API..."
  convert_via_api "\$SUBS_API" "\$SUBS_SRC" "\$TMP_FILE"
fi

if [[ ! -s "\$TMP_FILE" ]]; then
  echo "Error: ${TMP_FILE} is empty or missing after fetch/convert."
  exit 1
fi
if ! is_singbox_json "\$TMP_FILE"; then
  echo "Error: final ${TMP_FILE} is not valid sing-box JSON with outbounds[]."
  exit 1
fi

echo "Temporary config ready: \$TMP_FILE"

[ ! -f '${TMP_FILE}' ] && echo "原始节点文件不存在：${TMP_FILE}" && exit 1

# 提取节点→合并模板→按分组分类这一段，任何一步失败都只影响分类效果本身，
# 不该导致整个启动脚本在最后一步拉起 sing-box 之前就退出
set +e

# 从订阅中提取节点
jq '[.outbounds[] | select(.server != null and .server != "")]' '$TMP_FILE' > '$NODES'
[ ! -f "$NODES" ] && echo "全节点文件不存在：$NODES" && exit 1

# 将节点全部插入到 \`.outbounds\`
jq --slurpfile new_nodes '$NODES' '
  .outbounds += \$new_nodes[0]
' '$SING_BOX_CONFIG_TEMPLATES_FILE' > '${SING_BOX_DIR_PATH}/config_tmp.json' && mv '${SING_BOX_DIR_PATH}/config_tmp.json' '${NODES_CONFIG}'
[ ! -f "$NODES_CONFIG" ] && echo "节点配置文件不存在：$NODES_CONFIG" && exit 1

# 将节点名全部插入到 自动_469138946ba5fa
jq --slurpfile new_nodes '$NODES' '
  .outbounds |= map(
    if .tag == "自动_469138946ba5fa" and .type == "urltest" then
      .outbounds = (\$new_nodes[0] | map(.tag))
    else
      .
    end
  )
' '$NODES_CONFIG' > '${SING_BOX_DIR_PATH}/config_tmp.json' && mv '${SING_BOX_DIR_PATH}/config_tmp.json' '${NODES_CONFIG}'

# 将节点名全部插入到 手动_469138946ba5fa
jq --slurpfile new_nodes '$NODES' '
  .outbounds |= map(
    if .tag == "手动_469138946ba5fa" and .type == "selector" then
      .outbounds = (\$new_nodes[0] | map(.tag))
    else
      .
    end
  )
' '$NODES_CONFIG' > '${SING_BOX_DIR_PATH}/config_tmp.json' && mv '${SING_BOX_DIR_PATH}/config_tmp.json' '${NODES_CONFIG}'

# 遍历分组定义文件，每行格式：tag|pattern
# 已匹配过的节点集合（互斥用）
matched_all='[]'
while IFS='|' read -r tag pattern; do
  echo "处理分组：\$tag"

  # 只匹配「还没有被任何分组抢走」的节点
  matched=\$(jq --arg pattern "\$pattern" --argjson already "\$matched_all" '
    [.[]
     | select(.tag | test(\$pattern; "i"))
     | select(.tag as \$t | (\$already | index(\$t) | not))
     | .tag]
  ' '$NODES')

  if [ \$? -ne 0 ]; then
    echo "  ⚠ 正则匹配出错，跳过该分组（检查 pattern 里是否有特殊字符没转义）"
    continue
  fi

  # 如果没有匹配结果，跳过
  if [ "\$(echo "\$matched" | jq 'length')" -eq 0 ]; then
    echo "  ➤ 无匹配节点，跳过"
    continue
  fi

  # 把本轮匹配到的节点加入总集合
  matched_all=\$(jq -n --argjson new "\$matched" --argjson old "\$matched_all" '
    \$old + \$new | unique
  ')

  # 判断分组是否存在
  exists=\$(jq --arg tag "\$tag" '.outbounds[] | select(.tag == \$tag)' '$NODES_CONFIG')

  if [ -z "\$exists" ]; then
    echo "  ➤ 分组不存在，创建新 selector"
    jq --arg tag "\$tag" --argjson outbounds "\$matched" '
      .outbounds += [{
        type: "selector",
        tag: \$tag,
        outbounds: \$outbounds
      }]
    ' '$NODES_CONFIG' > '${SING_BOX_DIR_PATH}/config_tmp.json' && mv '${SING_BOX_DIR_PATH}/config_tmp.json' '${NODES_CONFIG}'
  else
    echo "  ➤ 分组已存在，更新节点列表"
    jq --arg tag "\$tag" --argjson outbounds "\$matched" '
      .outbounds |= map(
        if .tag == \$tag and (.type == "selector" or .type == "urltest") then
          . + {outbounds: \$outbounds}
        else
          .
        end
      )
    ' '$NODES_CONFIG' > '${SING_BOX_DIR_PATH}/config_tmp.json' && mv '${SING_BOX_DIR_PATH}/config_tmp.json' '${NODES_CONFIG}'
  fi
done < '$GROUPS_FILE'

set -e

cp -fv '${NODES_CONFIG}' '${SING_BOX_FILE}'
[ ! -f "$SING_BOX_FILE" ] && echo "新节点配置文件不存在：$SING_BOX_FILE" && exit 1

# 修复 sing-box config.json 中自动选择策略的 url-test 设置
if [ -f '${SING_BOX_FILE}' ]; then
    echo "正在增强自动选择策略组配置..."

    # 替换测试 URL 为更稳定的 Cloudflare
    # 修复 sing-box config.json 中自动选择策略的 url-test 设置
    jq '
      # 1. 修改 mixed 的 listen_port
      .inbounds |= map(
        if .type == "mixed" then
          .listen_port = 7890
        else
          .
        end
      )
      # 2. 修改所有 urltest 对象的测速频率（镇压订阅自带的高频测速）
      | (.outbounds[] | select(.type=="urltest")) |=
          (.url = "http://cp.cloudflare.com/generate_204"
           | .interval = "10m0s"
           | .tolerance = 100)
      # 3. 修复 WS 传输的 ALPN 冲突
      # 逻辑：如果底层传输 type 是 "ws"，且开启了 TLS，强制将其 ALPN 约束为 ["http/1.1"]
      | .outbounds |= map(
          if .transport?.type == "ws" and .tls? then
            .tls.alpn = ["http/1.1"]
          else
            .
          end
        )
      # 4. 修改 experimental.clash_api 的 external_controller / external_ui（如果存在）
      | if .experimental? and .experimental.clash_api? then
          .experimental.clash_api.external_controller = ":9999"
          | .experimental.clash_api.external_ui = "ui"
        else
          .
        end
      ## 5. 处理 Trojan 的 Multiplex
      #| (.outbounds[] | select(.type == "trojan" and .server != null and .server != "")) += {
      #    "multiplex": {
      #      "enabled": true,
      #      "protocol": "h2mux",
      #      "max_connections": 1,
      #      "min_streams": 4,
      #      "max_streams": 0,
      #      "padding": true
      #    }
      #  }
      ## 6. 插入或修改 DNS UDP 53 inbound(macOS mDNSRespo 会抢占 53 故注释)
      #| if any(.inbounds[]; .type=="direct" and .network=="udp") then
      #    .inbounds |= map(
      #      if .type=="direct" and .network=="udp" then
      #        .listen_port = 53
      #      else
      #        .
      #      end
      #    )
      #  else
      #    .inbounds += [{
      #      "type": "direct",
      #      "tag": "DNS入站_469138946ba5fa",
      #      "listen": "0.0.0.0",
      #      "listen_port": 53,
      #      "network": "udp"
      #    }]
      #  end
      ## 7. 在 route.rules 里，凡是有 inbound 数组的，就追加 "DNS入站_469138946ba5fa"
      #| .route.rules |= map(
      #    if .inbound? and (.inbound | type == "array") then
      #      if any(.inbound[]; . == "DNS入站_469138946ba5fa") then
      #        .
      #      else
      #        .inbound += ["DNS入站_469138946ba5fa"]
      #      end
      #    else
      #      .
      #    end
      #  )
      # 8. 去掉 transport.path 里的 ? 之后部分
      | (.outbounds |= map(
          if .transport?.path? then
            .transport.path |= split("?")[0]
          else
            .
          end
        ))
      ## 9. 删除 TUN入站_469138946ba5fa inbound，并同步清理 route.rules 里的引用
      #| .inbounds |= map(select(.tag != "TUN入站_469138946ba5fa"))
      #| .route.rules |= map(
      #    if .inbound? and (.inbound | type == "array") then
      #      .inbound |= map(select(. != "TUN入站_469138946ba5fa"))
      #    else
      #      .
      #    end
      #)
      # 10. 修复 tuic 节点
      | .outbounds |= map(
          if .type == "tuic" then
            .uuid |= sub("(%3A|:).*"; "")
            | .uuid |= sub("@\\\\[.*\$"; "")
            | .server_port |= (if type=="string" then tonumber else . end)
          else
            .
          end
        )
      ' '${SING_BOX_FILE}' > '${SING_BOX_FILE}.tmp' && mv '${SING_BOX_FILE}.tmp' '${SING_BOX_FILE}'
else
  echo "Error: ${SING_BOX_FILE} is not exist. Exiting."
  exit 3
fi

cp -fv '${SING_BOX_FILE}' '${SING_BOX_FILE}.bak'

# 每个人的系统环境如此的不同
# 假如你原本就有python环境，而我如果写了一个脚本安装python环境，那一定会破坏你原本的python环境
# 所以python环境这块，你自己搭建好吗？
if python '${BASE_CONFIG_FIXSCRIPT_FILE}' '${SING_BOX_FILE}.bak' '${SING_BOX_FILE}'; then
  echo ok
else
  cp -fv '${SING_BOX_FILE}.bak' '${SING_BOX_FILE}'
fi

echo "配置已生成: ${SING_BOX_FILE}"

# 配置 NAT 转发并做好标记方便删除
pf_nat_udp_tcp() {
  # 获取默认网卡和网段
  # 获取默认网卡
  IFACE=\$(route get default | awk '/interface: / {print \$2}')
  # 获取 IP 地址
  IP=\$(ipconfig getifaddr "\$IFACE")
  # 获取十六进制子网掩码
  NETMASK_HEX=\$(ifconfig "\$IFACE" | awk '/netmask/ {print \$4}' | sed 's/^0x//')
  # 转换为十进制
  NETMASK_DEC=\$((16#\$NETMASK_HEX))
  # 计算 CIDR 位数
  CIDR_BITS=\$(echo "obase=2; \$NETMASK_DEC" | bc | grep -o "1" | wc -l | tr -d '[:space:]')
  # 构造 CIDR 网段
  IFS=. read -r o1 o2 o3 o4 <<< "\$IP"
  CIDR="\${o1}.\${o2}.\${o3}.0/\${CIDR_BITS}"
  echo "网卡: \$IFACE"
  echo "IP: \$IP"
  echo "子网掩码: \$NETMASK_HEX"
  echo "CIDR 位数: \$CIDR_BITS"
  echo "CIDR 网段: \$CIDR"
  MARKER="# inserted-by-nat-script"
  #NAT_RULE='nat on en0 from 192.168.255.0/24 to any -> (en0)'
  #NAT_RULE="nat on \$IFACE from \$CIDR to any -> (\$IFACE) \$MARKER"
  #NAT_RULE="nat on \$IFACE from any to any -> (\$IFACE) \$MARKER"
  NAT_RULE='nat-anchor "singbox/*" '\$MARKER
  #RDR_RULE='rdr pass on en0 proto udp from any to any -> 172.19.0.1'
  #RDR_RULE="rdr pass on \$IFACE proto udp from any to any -> 172.19.0.1 \$MARKER"
  RDR_RULE='rdr-anchor "singbox/*" '\$MARKER
  ANCHOR_FILE="/etc/pf.anchors/singbox"
  NAT_RDR_RULE='load anchor "singbox" from "'\$ANCHOR_FILE'" '\$MARKER
  PF_CONF="/etc/pf.conf"

  # 删除旧规则（带标记的）
  sudo sed -i '' "/\$MARKER/d" "\$PF_CONF"
  sudo rm -fv \$ANCHOR_FILE

  # 定义需要排除的私有地址（不走重定向）
  PRIVATE_IPS="{ 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4 }"

  # 写入 anchor 规则
  cat <<469138946ba5fa_1 | sudo tee \$ANCHOR_FILE
# 排除本地回环和 Docker 默认网桥网段，对私有网段不进行重定向
#no rdr on \$IFACE proto {tcp udp} from any to $PRIVATE_IPS

# NAT 出口伪装，保证 Mac 自身流量出外网正常
#nat on \$IFACE from any to any -> (\$IFACE)

# DNS 劫持（如果设备没手动设置 DNS）
#rdr pass on \$IFACE proto {tcp udp} from any to any port 53 -> 172.19.0.1 port 53
#rdr pass on \$IFACE proto udp from any to any port 53 -> 172.19.0.1 port 53

# 阻断 DoT
#block out on \$IFACE proto tcp from any to any port 853

# （可选）阻断常见 DoH IP
#table <doh> persist { 1.1.1.1, 1.0.0.1, 8.8.8.8, 8.8.4.4 }
#block out on \$IFACE from any to <doh> proto tcp to port 443
#block out on \$IFACE from any to <doh> proto udp to port 443

# TCP/UDP 流量转发到 sing-box 7890
#rdr pass on \$IFACE proto {tcp udp} from any to any -> 172.19.0.1 port 7890
# TCP 流量转发到 sing-box 7890
#rdr pass on \$IFACE proto tcp from any to any -> 172.19.0.1 port 7890
# TCP/UDP 流量转发到 sing-box TUN
#rdr pass on \$IFACE proto {tcp udp} from any to any -> 172.19.0.1
# TCP 流量转发到 sing-box TUN
#rdr pass on \$IFACE proto tcp from any to any -> 172.19.0.1
469138946ba5fa_1

  # 查找插入位置
  START_LINE=\$(grep -nE 'scrub-anchor|dummynet-anchor' "\$PF_CONF" | tail -1 | cut -d: -f1)
  END_LINE=\$(grep -n 'anchor "com.apple/\*"' "\$PF_CONF" | head -1 | cut -d: -f1)

  if [[ -n "\$START_LINE" && "\$END_LINE" -gt 0 ]]; then
      # 插入在 START_LINE 后一行，保证顺序
      INSERT_LINE=\$((START_LINE + 1))
      sudo sed -i '' "\${INSERT_LINE}i\\\\
\$NAT_RULE\\\\
\$RDR_RULE\\\\
\$NAT_RDR_RULE
" "\$PF_CONF"
      echo "自定义 anchor 插入完成"
  else
      # 没找到参考位置，直接追加到文件末尾
      printf '%s\n' \\
      "\$NAT_RULE" \\
      "\$RDR_RULE" \\
      "\$NAT_RDR_RULE" \\
      | sudo tee -a "\$PF_CONF" >/dev/null
      echo "自定义 anchor 追加到文件末尾"
  fi

  # 重载 PF 加载并启用 PF
  sudo pfctl -d 2>/dev/null || true
  sudo pfctl -f "\$PF_CONF" || true
  sudo pfctl -e || true
  # 应该能看到 singbox 的 NAT/RDR
  sudo pfctl -s nat
  sudo pfctl -s rules
  sudo pfctl -a singbox -s nat
  sudo pfctl -a singbox -s all
}

pf_nat_udp_tcp

# 开启 IP 转发避免反复写入
# IPv4 
NAT_IP='net.inet.ip.forwarding=1'
SYS_CONF='/etc/sysctl.conf'
if ! grep -qF "\$NAT_IP" "\$SYS_CONF"; then
  echo "\$NAT_IP" | sudo tee -a "\$SYS_CONF"
fi
# IPv6
NAT_IP='net.inet6.ip6.forwarding=1'
if ! grep -qF "\$NAT_IP" "\$SYS_CONF"; then
  echo "\$NAT_IP" | sudo tee -a "\$SYS_CONF"
fi

# IPv4 关闭则 sudo sysctl -w net.inet.ip.forwarding=0
sudo sysctl -w net.inet.ip.forwarding=1
# IPv6 关闭则 sudo sysctl -w net.inet6.ip6.forwarding=0
sudo sysctl -w net.inet6.ip6.forwarding=1

# 刷新 DNS 缓存
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder

sudo '${SING_BOX_BIN_FILE_RENAME}' -c '${SING_BOX_FILE}' format > '${SING_BOX_FILE}.tmp' && mv '${SING_BOX_FILE}.tmp' '${SING_BOX_FILE}'
sudo pkill -f 'sing-box -D' || true
sudo '${SING_BOX_BIN_FILE_RENAME}' -D '${SING_BOX_DIR}' -c '${SING_BOX_FILE}' run
IFS=\$IFS_BAK
469138946ba5fa

chmod -v u+x,go-rwx ${SING_BOX_START}
echo "已生成启动脚本: ${SING_BOX_START}"

echo "如果想要全局路由你需要配置路由器 DHCP 下发的 Gateway 和 DNS 改为公共dns 比如 1.1.1.1 8.8.8.8，不要将 DNS 设置为 172.19.0.1 或 fake-ip 地址"
echo "如果想要旁路由，你需要为单个联网设备配置 Gateway 和 DNS 改为公共dns 比如 1.1.1.1 8.8.8.8，不要将 DNS 设置为 172.19.0.1 或 fake-ip 地址"
echo "如果想要端口代理，你需要将联网代理设置为本机 IP:7890"
echo "如果想要本机，那就什么都没什么可说的了"
echo "执行脚本 ${SING_BOX_START} 启动测试看看吧"

IFS=$IFS_BAK