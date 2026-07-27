# Sing-box VLESS Reality 部署指南

本指南介绍如何使用 Docker 部署基于 Sing-box 的 VLESS Reality 协议。

## 5. 生成凭证

在配置 Sing-box Reality 之前，我们需要生成一套必要的凭证信息，包括 UUID 和 Reality 的密钥对（Public Key 和 Private Key）以及 Short ID。

1. **生成 UUID**
   可以使用命令行工具或在线生成器生成一个标准的 UUID：
   ```bash
   sing-box generate uuid
   ```
2. **生成 Reality 密钥对**
   使用 Sing-box 生成公钥和私钥：
   ```bash
   sing-box generate reality-keypair
   ```
   记下输出的 `PrivateKey` 和 `PublicKey`。
3. **生成 Short ID**
   生成一个 8 字节（16个字符）的十六进制字符串：
   ```bash
   sing-box generate rand --hex 8
   ```

## 7. 编写配置文件

在 `data/config.json` 中填入你的配置。我们将使用 `www.cloudflare.com` 作为伪装域名（SNI），并配置 VLESS Reality 入站。

```json
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {"tag": "google", "type": "tls", "server": "8.8.8.8"}
    ]
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "reality-in",
      "listen": "::",
      "listen_port": 50000,
      "users": [
        {
          "name": "main",
          "uuid": "你的_UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "www.cloudflare.com",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "www.cloudflare.com",
            "server_port": 443
          },
          "private_key": "你的_PRIVATE_KEY",
          "short_id": ["你的_SHORT_ID"]
        }
      }
    }
  ],
  "outbounds": [
    {"type": "direct", "tag": "direct-out"}
  ]
}
```
*请将 `uuid`、`private_key` 和 `short_id` 替换为你刚刚生成的值。*

## 8. Docker Compose 部署

配置完成后，可以直接使用 Docker Compose 启动服务：

```bash
docker compose up -d
```
此时 Sing-box 已经运行，可以使用支持 VLESS Reality 的客户端连接你的服务器。
