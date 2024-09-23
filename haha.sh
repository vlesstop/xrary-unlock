#!/bin/bash

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以root权限运行此脚本"
  exit 1
fi

# 安装必要的软件包
echo "安装必要的软件包..."
apt update && apt install -y curl jq

# 检查 jq 是否安装成功
if ! command -v jq &> /dev/null; then
  echo "jq 安装失败，请手动执行 sudo apt-get install -y jq  安装jq。"
  exit 1
fi

# 检查是否已安装 XrayR
if ! command -v XrayR &> /dev/null; then
  echo "XrayR 未安装，正在下载并安装 XrayR..."
  wget -N https://raw.githubusercontent.com/wyx2685/XrayR-release/master/install.sh && bash install.sh
else
  echo "XrayR 已安装，跳过安装步骤。"
fi

# 检查传递的参数数量
if [ "$#" -eq 9 ];then
  node_id="$1"
  node_type="$2"
  api_host="$3"
  api_key=“$4”
  device_online_min_traffic="$5"
  enable_audit="$6"
  optimize_connection_config="$7"
  unlock_method="$8"
  unlock_options="$9"

  # 执行对接节点配置
  if [ -n "$node_id" ] && [ -n "$node_type" ] && [ -n "$device_online_min_traffic" ] && [ -n "$api_host" ] && [ -n "$api_key" ]; then
    # 根据是否开启审计设置配置项
    if [ "$enable_audit" == "yes" ]; then
      route_config_path="/etc/XrayR/route.json"
      outbound_config_path="/etc/XrayR/custom_outbound.json"
    else
      route_config_path=""
      outbound_config_path=""
    fi

    # 修改配置文件
    echo "修改配置文件..."
    config_file="/etc/XrayR/config.yml"

    # 使用sed命令修改相应的配置项
    sed -i "s/NodeID: .*/NodeID: $node_id/" $config_file
    sed -i "s/NodeType: .*/NodeType: $node_type/" $config_file
    sed -i "s/DeviceOnlineMinTraffic: .*/DeviceOnlineMinTraffic: $device_online_min_traffic/" $config_file
    sed -i "s|RouteConfigPath: .*|RouteConfigPath: $route_config_path|" $config_file
    sed -i "s|OutboundConfigPath: .*|OutboundConfigPath: $outbound_config_path|" $config_file
    sed -i "s|ApiHost: .*|ApiHost: \"$api_host\"|" $config_file
    sed -i "s|Apikey: .*|Apikey: \"$api_key\"|" $config_file

    # 根据用户选择优化 ConnectionConfig 配置
    if [ "$optimize_connection_config" == "yes" ]; then
      sed -i "s/Handshake: .*/Handshake: 8/" $config_file
      sed -i "s/ConnIdle: .*/ConnIdle: 10/" $config_file
      sed -i "s/UplinkOnly: .*/UplinkOnly: 4/" $config_file
      sed -i "s/DownlinkOnly: .*/DownlinkOnly: 4/" $config_file
      sed -i "s/BufferSize: .*/BufferSize: 64/" $config_file
    fi

    # 启动XrayR
    echo "重启XrayR..."
    systemctl restart XrayR

    echo "XrayR配置修改完成！"
  fi

  # 执行解锁配置
  if [ "$unlock_method" == "1" ]; then
    # 分流解锁
    echo "配置分流解锁..."
    config_file="./config.yml"

    # 修改 RouteConfigPath 和 OutboundConfigPath 配置项
    sed -i "s|RouteConfigPath: .*|RouteConfigPath: /etc/XrayR/route.json|" $config_file
    sed -i "s|OutboundConfigPath: .*|OutboundConfigPath: /etc/XrayR/custom_outbound.json|" $config_file

    # 提示用户去修改当前脚本所在目录中的 config 文件
    echo "请修改当前脚本所在目录中的 config.yml 文件，配置项目需要包含一个uuid，以及各个国家的分流节点域名和端口。"
    echo "例如："
    echo "  - name: US"
    echo "    uuid: <解锁项目的uuid>"
    echo "    domain: us.example.com"
    echo "    port: 443"
    echo "  - name: JP"
    echo "    uuid: <解锁项目的uuid>"
    echo "    domain: jp.example.com"
    echo "    port: 443"

    # 等待用户确认
    read -p "修改完成后按任意键继续..."

    # 定义解锁项目和对应的国家
    declare -A unlock_map
    unlock_map=(
      [1]="US"
      [2]="US"
      [3]="US"
      [4]="HK"
      [5]="US"
      [6]="JP"
      [7]="JP"
      [8]="TW"
      [9]="US"
      [10]="US"
      [11]="US"
    )

    # 选择解锁项目
    if [ -z "$unlock_options" ]; then
      echo "请选择要解锁的项目 (用空格分隔多个选项):"
      echo "1) YouTube"
      echo "2) Netflix"
      echo "3) Disney+"
      echo "4) Bilibili"
      echo "5) TikTok"
      echo "6) DAZN"
      echo "7) Abema"
      echo "8) Bahamut"
      echo "9) HBO Max"
      echo "10) ChatGPT"
      echo "11) Steam"
      read -p "请输入解锁选项 (例如: 2 4 9): " unlock_options
    fi

    # 修改 custom_outbound.json 文件的内容
    echo "修改 /etc/XrayR/custom_outbound.json 文件..."
    cat <<EOF > /etc/XrayR/custom_outbound.json
[
  {
    "tag": "IPv4_out",
    "sendThrough": "0.0.0.0",
    "protocol": "freedom"
  }
EOF

    for option in $unlock_options; do
      country=${unlock_map[$option]}
      uuid=$(grep -A 3 "name: $country" $config_file | grep "uuid" | awk '{print $2}')
      domain=$(grep -A 3 "name: $country" $config_file | grep "domain" | awk '{print $2}')
      port=$(grep -A 3 "name: $country" $config_file | grep "port" | awk '{print $2}')
      country_lower=$(echo "$country" | tr '[:upper:]' '[:lower:]')
      echo '  ,' >> /etc/XrayR/custom_outbound.json
      echo '  {' >> /etc/XrayR/custom_outbound.json
      echo '    "protocol": "Shadowsocks",' >> /etc/XrayR/custom_outbound.json
      echo '    "settings": {' >> /etc/XrayR/custom_outbound.json
      echo '      "servers": [' >> /etc/XrayR/custom_outbound.json
      echo '        {' >> /etc/XrayR/custom_outbound.json
      echo '          "address": "'$domain'",' >> /etc/XrayR/custom_outbound.json
      echo '          "port": '$port',' >> /etc/XrayR/custom_outbound.json
      echo '          "method": "chacha20-ietf-poly1305",' >> /etc/XrayR/custom_outbound.json
      echo '          "password": "'$uuid'"' >> /etc/XrayR/custom_outbound.json
      echo '        }' >> /etc/XrayR/custom_outbound.json
      echo '      ]' >> /etc/XrayR/custom_outbound.json
      echo '    },' >> /etc/XrayR/custom_outbound.json
      echo '    "tag": "unlock-'$country_lower'"' >> /etc/XrayR/custom_outbound.json
      echo '  }' >> /etc/XrayR/custom_outbound.json
    done

    # 结束 custom_outbound.json 文件
    echo ']' >> /etc/XrayR/custom_outbound.json

    echo "解锁配置完成！"
    echo "开始配置路由！"

    # 修改 route.json 文件的内容
    echo "修改 /etc/XrayR/route.json 文件..."
    echo '{
  "domainStrategy": "IPOnDemand",
  "rules": [' > /etc/XrayR/route.json

    # 添加阻止 bittorrent 的规则
    echo '    {
    "type": "field",
    "outboundTag": "block",
    "protocol": [
      "bittorrent"
    ]
  }' >> /etc/XrayR/route.json

    for option in $unlock_options; do
      country=${unlock_map[$option]}
      country_lower=$(echo "$country" | tr '[:upper:]' '[:lower:]')
      project=$(case $option in
        1) echo "YouTube" ;;
        2) echo "Netflix" ;;
        3) echo "Disney+" ;;
        4) echo "Bilibili" ;;
        5) echo "TikTok" ;;
        6) echo "DAZN" ;;
        7) echo "Abema" ;;
        8) echo "Bahamut" ;;
        9) echo "HBO Max" ;;
        10) echo "ChatGPT" ;;
        11) echo "Steam" ;;
      esac)
      domains=$(jq -r --arg country "$country" --arg project "$project" '.[$country].domain[$project][]' route_templates.json)
      echo '    ,{
    "type": "field",
    "outboundTag": "unlock-'$country_lower'",
    "domain": [' >> /etc/XrayR/route.json
      for domain in $domains; do
        echo '      "'$domain'",' >> /etc/XrayR/route.json
      done
      # 移除最后一个逗号
      sed -i '$ s/,$//' /etc/XrayR/route.json
      echo '    ]
  }' >> /etc/XrayR/route.json
    done

    # 移除最后一个逗号并结束 route.json 文件
    echo '  ]
}' >> /etc/XrayR/route.json

    echo "路由配置完成！"
  elif [ "$unlock_method" == "2" ]; then
    # 自有分流解锁
    echo "配置自有分流解锁..."
    config_file="./config.yml"

    # 修改 RouteConfigPath 和 OutboundConfigPath 配置项
    sed -i "s|RouteConfigPath: .*|RouteConfigPath: /etc/XrayR/route.json|" $config_file
    sed -i "s|OutboundConfigPath: .*|OutboundConfigPath: /etc/XrayR/custom_outbound.json|" $config_file

    # 获取 dns 配置
    dns_uuid=$(grep -A 3 "name: dns" $config_file | grep "uuid" | awk '{print $2}')
    dns_domain=$(grep -A 3 "name: dns" $config_file | grep "domain" | awk '{print $2}')
    dns_port=$(grep -A 3 "name: dns" $config_file | grep "port" | awk '{print $2}')

    # 修改 custom_outbound.json 文件的内容
    echo "修改 /etc/XrayR/custom_outbound.json 文件..."
    cat <<EOF > /etc/XrayR/custom_outbound.json
[
  {
    "tag": "IPv4_out",
    "sendThrough": "0.0.0.0",
    "protocol": "freedom"
  },
  {
    "protocol": "Shadowsocks",
    "settings": {
      "servers": [
        {
          "address": "$dns_domain",
          "port": $dns_port,
          "method": "chacha20-ietf-poly1305",
          "password": "$dns_uuid"
        }
      ]
    },
    "tag": "selfunlock"
  }
]
EOF

    echo "解锁配置完成！"
    echo "开始配置路由！"

    # 修改 route.json 文件的内容
    echo "修改 /etc/XrayR/route.json 文件..."
    echo '{
  "domainStrategy": "IPOnDemand",
  "rules": [' > /etc/XrayR/route.json

    # 添加阻止 bittorrent 的规则
    echo '    {
    "type": "field",
    "outboundTag": "block",
    "protocol": [
      "bittorrent"
    ]
  }' >> /etc/XrayR/route.json

    for option in $unlock_options; do
      project=$(case $option in
        1) echo "YouTube" ;;
        2) echo "Netflix" ;;
        3) echo "Disney+" ;;
        4) echo "Bilibili" ;;
        5) echo "TikTok" ;;
        6) echo "DAZN" ;;
        7) echo "Abema" ;;
        8) echo "Bahamut" ;;
        9) echo "HBO Max" ;;
        10) echo "ChatGPT" ;;
        11) echo "Steam" ;;
      esac)
      domains=$(jq -r --arg project "$project" '.[$project].domain[]' route_templates.json)
      echo '    ,{
    "type": "field",
    "outboundTag": "selfunlock",
    "domain": [' >> /etc/XrayR/route.json
      for domain in $domains; do
        echo '      "'$domain'",' >> /etc/XrayR/route.json
      done
      # 移除最后一个逗号
      sed -i '$ s/,$//' /etc/XrayR/route.json
      echo '    ]
  }' >> /etc/XrayR/route.json
    done

    # 移除最后一个逗号并结束 route.json 文件
    echo '  ]
}' >> /etc/XrayR/route.json

    echo "路由配置完成！"
  else
    echo "无效选项，请重新选择"
  fi

else
  # 显示菜单
  while true; do
    echo "请选择操作："
    echo "1) 对接节点"
    echo "2) 配置解锁"
    echo "0) 退出脚本"
    read -p "请输入选项: " option

    case $option in
      1)
        # 解析命令行参数
        node_id="$1"
        node_type="$2"
        api_host="$3"
        api_key="$4"
        device_online_min_traffic="$5"
        enable_audit="$6"
        optimize_connection_config="$7"
        unlock_method="$8"
        unlock_options="$9"

        # 如果没有传递参数，则提示用户输入
        if [ -z "$node_id" ]; then
          read -p "请输入节点ID: " node_id
        fi

        if [ -z "$node_type" ]; then
          read -p "请输入节点类型 (V2ray, Vmess, Vless, Shadowsocks, Trojan, Shadowsocks-Plugin): " node_type
        fi

        if [ -z "$api_host" ]; then
          read -p "请输入对接域名 (例如: https://baidu.com): " api_host
        fi

        if [ -z "$api_key" ]; then
          read -p "请输入对接域名对接密钥: " api_key
        fi

        if [ -z "$device_online_min_traffic" ]; then
          read -p "请输入设备在线上报阈值 (单位: kB): " device_online_min_traffic
        fi

        if [ -z "$enable_audit" ]; then
          read -p "是否开启审计 (yes/no): " enable_audit
        fi

        if [ -z "$optimize_connection_config" ]; then
          read -p "是否优化 ConnectionConfig 配置 (yes/no): " optimize_connection_config
        fi

        # 对接节点配置
        if [ -n "$node_id" ] && [ -n "$node_type" ] && [ -n "$device_online_min_traffic" ] && [ -n "$api_host" ]; then
          # 根据是否开启审计设置配置项
          if [ "$enable_audit" == "yes" ]; then
            route_config_path="/etc/XrayR/route.json"
            outbound_config_path="/etc/XrayR/custom_outbound.json"
          else
            route_config_path=""
            outbound_config_path=""
          fi

          # 修改配置文件
          echo "修改配置文件..."
          config_file="/etc/XrayR/config.yml"

          # 使用sed命令修改相应的配置项
          sed -i "s/NodeID: .*/NodeID: $node_id/" $config_file
          sed -i "s/NodeType: .*/NodeType: $node_type/" $config_file
          sed -i "s/DeviceOnlineMinTraffic: .*/DeviceOnlineMinTraffic: $device_online_min_traffic/" $config_file
          sed -i "s|RouteConfigPath: .*|RouteConfigPath: $route_config_path|" $config_file
          sed -i "s|OutboundConfigPath: .*|OutboundConfigPath: $outbound_config_path|" $config_file
          sed -i "s|ApiHost: .*|ApiHost: \"$api_host\"|" $config_file
          sed -i "s|Apikey: .*|Apikey: \"$api_key\"|" $config_file

          # 根据用户选择优化 ConnectionConfig 配置
          if [ "$optimize_connection_config" == "yes" ]; then
            sed -i "s/Handshake: .*/Handshake: 8/" $config_file
            sed -i "s/ConnIdle: .*/ConnIdle: 10/" $config_file
            sed -i "s/UplinkOnly: .*/UplinkOnly: 4/" $config_file
            sed -i "s/DownlinkOnly: .*/DownlinkOnly: 4/" $config_file
            sed -i "s/BufferSize: .*/BufferSize: 64/" $config_file
          fi

          # 启动XrayR
          echo "重启XrayR..."
          systemctl restart XrayR

          echo "XrayR配置修改完成！"
        fi
        ;;
      2)
        # 配置解锁
        if [ -z "$unlock_method" ]; then
          echo "请选择解锁方式："
          echo "1) 分流解锁"
          echo "2) 自有分流解锁"
          read -p "请输入选项: " unlock_method
        fi

        if [ "$unlock_method" == "1" ]; then
          # 分流解锁
          echo "配置分流解锁..."
          config_file="./config.yml"

        # 修改 RouteConfigPath 和 OutboundConfigPath 配置项
        sed -i "s|RouteConfigPath: .*|RouteConfigPath: /etc/XrayR/route.json|" $config_file
        sed -i "s|OutboundConfigPath: .*|OutboundConfigPath: /etc/XrayR/custom_outbound.json|" $config_file

        # 提示用户去修改当前脚本所在目录中的 config 文件
        echo "请修改当前脚本所在目录中的 config.yml 文件，配置项目需要包含一个uuid，以及各个国家的分流节点域名和端口。"
        echo "例如："
        echo "  - name: US"
        echo "    uuid: <解锁项目的uuid>"
        echo "    domain: us.example.com"
        echo "    port: 443"
        echo "  - name: JP"
        echo "    uuid: <解锁项目的uuid>"
        echo "    domain: jp.example.com"
        echo "    port: 443"

        # 等待用户确认
        read -p "修改完成后按任意键继续..."

        # 定义解锁项目和对应的国家
        declare -A unlock_map
        unlock_map=(
          [1]="US"
          [2]="US"
          [3]="US"
          [4]="HK"
          [5]="US"
          [6]="JP"
          [7]="JP"
          [8]="TW"
          [9]="US"
          [10]="US"
          [11]="US"
        )

        # 选择解锁项目
        if [ -z "$unlock_options" ]; then
          echo "请选择要解锁的项目 (用空格分隔多个选项):"
          echo "1) YouTube"
          echo "2) Netflix"
          echo "3) Disney+"
          echo "4) Bilibili"
          echo "5) TikTok"
          echo "6) DAZN"
          echo "7) Abema"
          echo "8) Bahamut"
          echo "9) HBO Max"
          echo "10) ChatGPT"
          echo "11) Steam"
          read -p "请输入解锁选项 (例如: 2 4 9): " unlock_options
        fi

        # 修改 custom_outbound.json 文件的内容
        echo "修改 /etc/XrayR/custom_outbound.json 文件..."
        cat <<EOF > /etc/XrayR/custom_outbound.json
[
  {
    "tag": "IPv4_out",
    "sendThrough": "0.0.0.0",
    "protocol": "freedom"
  }
EOF

        for option in $unlock_options; do
          country=${unlock_map[$option]}
          uuid=$(grep -A 3 "name: $country" $config_file | grep "uuid" | awk '{print $2}')
          domain=$(grep -A 3 "name: $country" $config_file | grep "domain" | awk '{print $2}')
          port=$(grep -A 3 "name: $country" $config_file | grep "port" | awk '{print $2}')
          country_lower=$(echo "$country" | tr '[:upper:]' '[:lower:]')
          echo '  ,' >> /etc/XrayR/custom_outbound.json
          echo '  {' >> /etc/XrayR/custom_outbound.json
          echo '    "protocol": "Shadowsocks",' >> /etc/XrayR/custom_outbound.json
          echo '    "settings": {' >> /etc/XrayR/custom_outbound.json
          echo '      "servers": [' >> /etc/XrayR/custom_outbound.json
          echo '        {' >> /etc/XrayR/custom_outbound.json
          echo '          "address": "'$domain'",' >> /etc/XrayR/custom_outbound.json
          echo '          "port": '$port',' >> /etc/XrayR/custom_outbound.json
          echo '          "method": "chacha20-ietf-poly1305",' >> /etc/XrayR/custom_outbound.json
          echo '          "password": "'$uuid'"' >> /etc/XrayR/custom_outbound.json
          echo '        }' >> /etc/XrayR/custom_outbound.json
          echo '      ]' >> /etc/XrayR/custom_outbound.json
          echo '    },' >> /etc/XrayR/custom_outbound.json
          echo '    "tag": "unlock-'$country_lower'"' >> /etc/XrayR/custom_outbound.json
          echo '  }' >> /etc/XrayR/custom_outbound.json
        done

        # 结束 custom_outbound.json 文件
        echo ']' >> /etc/XrayR/custom_outbound.json

        echo "解锁配置完成！"
        echo "开始配置路由！"

        # 修改 route.json 文件的内容
        echo "修改 /etc/XrayR/route.json 文件..."
        echo '{
  "domainStrategy": "IPOnDemand",
  "rules": [' > /etc/XrayR/route.json

        # 添加阻止 bittorrent 的规则
        echo '    {
    "type": "field",
    "outboundTag": "block",
    "protocol": [
      "bittorrent"
    ]
  }' >> /etc/XrayR/route.json

        for option in $unlock_options; do
          country=${unlock_map[$option]}
          country_lower=$(echo "$country" | tr '[:upper:]' '[:lower:]')
          project=$(case $option in
            1) echo "YouTube" ;;
            2) echo "Netflix" ;;
            3) echo "Disney+" ;;
            4) echo "Bilibili" ;;
            5) echo "TikTok" ;;
            6) echo "DAZN" ;;
            7) echo "Abema" ;;
            8) echo "Bahamut" ;;
            9) echo "HBO Max" ;;
            10) echo "ChatGPT" ;;
            11) echo "Steam" ;;
          esac)
          domains=$(jq -r --arg country "$country" --arg project "$project" '.[$country].domain[$project][]' route_templates.json)
          echo '    ,{
    "type": "field",
    "outboundTag": "unlock-'$country_lower'",
    "domain": [' >> /etc/XrayR/route.json
          for domain in $domains; do
            echo '      "'$domain'",' >> /etc/XrayR/route.json
          done
          # 移除最后一个逗号
          sed -i '$ s/,$//' /etc/XrayR/route.json
          echo '    ]
  }' >> /etc/XrayR/route.json
        done

        # 移除最后一个逗号并结束 route.json 文件
        echo '  ]
}' >> /etc/XrayR/route.json

        echo "路由配置完成！"

      elif [ "$unlock_method" == "2" ]; then
        # 自有分流解锁
        echo "配置自有分流解锁..."
        config_file="./config.yml"

        # 修改 RouteConfigPath 和 OutboundConfigPath 配置项
        sed -i "s|RouteConfigPath: .*|RouteConfigPath: /etc/XrayR/route.json|" $config_file
        sed -i "s|OutboundConfigPath: .*|OutboundConfigPath: /etc/XrayR/custom_outbound.json|" $config_file

        # 获取 dns 配置
        dns_uuid=$(grep -A 3 "name: dns" $config_file | grep "uuid" | awk '{print $2}')
        dns_domain=$(grep -A 3 "name: dns" $config_file | grep "domain" | awk '{print $2}')
        dns_port=$(grep -A 3 "name: dns" $config_file | grep "port" | awk '{print $2}')

        # 修改 custom_outbound.json 文件的内容
        echo "修改 /etc/XrayR/custom_outbound.json 文件..."
        cat <<EOF > /etc/XrayR/custom_outbound.json
[
  {
    "tag": "IPv4_out",
    "sendThrough": "0.0.0.0",
    "protocol": "freedom"
  },
  {
    "protocol": "Shadowsocks",
    "settings": {
      "servers": [
        {
          "address": "$dns_domain",
          "port": $dns_port,
          "method": "chacha20-ietf-poly1305",
          "password": "$dns_uuid"
        }
      ]
    },
    "tag": "selfunlock"
  }
]
EOF

        echo "解锁配置完成！"
        echo "开始配置路由！"

        # 修改 route.json 文件的内容
        echo "修改 /etc/XrayR/route.json 文件..."
        echo '{
  "domainStrategy": "IPOnDemand",
  "rules": [' > /etc/XrayR/route.json

        # 添加阻止 bittorrent 的规则
        echo '    {
    "type": "field",
    "outboundTag": "block",
    "protocol": [
      "bittorrent"
    ]
  }' >> /etc/XrayR/route.json

        # 选择解锁项目
        if [ -z "$unlock_options" ]; then
          echo "请选择要解锁的项目 (用空格分隔多个选项):"
          echo "1) YouTube"
          echo "2) Netflix"
          echo "3) Disney+"
          echo "4) Bilibili"
          echo "5) TikTok"
          echo "6) DAZN"
          echo "7) Abema"
          echo "8) Bahamut"
          echo "9) HBO Max"
          echo "10) ChatGPT"
          echo "11) Steam"
          read -p "请输入解锁选项 (例如: 2 4 9): " unlock_options
        fi

        for option in $unlock_options; do
          project=$(case $option in
            1) echo "YouTube" ;;
            2) echo "Netflix" ;;
            3) echo "Disney+" ;;
            4) echo "Bilibili" ;;
            5) echo "TikTok" ;;
            6) echo "DAZN" ;;
            7) echo "Abema" ;;
            8) echo "Bahamut" ;;
            9) echo "HBO Max" ;;
            10) echo "ChatGPT" ;;
            11) echo "Steam" ;;
          esac)
          domains=$(jq -r --arg project "$project" '.[$project].domain[]' route_templates.json)
          echo '    ,{
    "type": "field",
    "outboundTag": "selfunlock",
    "domain": [' >> /etc/XrayR/route.json
          for domain in $domains; do
            echo '      "'$domain'",' >> /etc/XrayR/route.json
          done
          # 移除最后一个逗号
          sed -i '$ s/,$//' /etc/XrayR/route.json
          echo '    ]
  }' >> /etc/XrayR/route.json
        done

        # 移除最后一个逗号并结束 route.json 文件
        echo '  ]
}' >> /etc/XrayR/route.json

        echo "路由配置完成！"
      else
        echo "无效选项，请重新选择"
      fi
      ;;
    0)
      echo "退出脚本"
      exit 0
      ;;
    *)
      echo "无效选项，请重新选择"
      ;;
  esac
done
fi
echo "重启XrayR..."
systemctl restart XrayR
# 检查 XrayR 是否运行
if systemctl is-active --quiet XrayR; then
  echo "XrayR已运行"
else
  echo "XrayR运行失败 请检查配置"
fi

echo "脚本执行完成！"
