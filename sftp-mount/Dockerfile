# 使用极轻量的 Alpine Linux（基础镜像仅 ~7MB，远小于 Ubuntu）
FROM alpine:latest

# 安装 OpenSSH 服务端与 SFTP 模块，并清理缓存
RUN apk add --no-cache openssh-server openssh-sftp-server \
    # 生成 SSH 服务端密钥
    && ssh-keygen -A \
    # 允许 root 密码登录
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    # 禁用 OpenSSH 9.8+ 的来源惩罚机制（避免休眠唤醒重连触发防暴力破解封禁）
    && echo "PerSourcePenalties no" >> /etc/ssh/sshd_config \
    # 配置保活与死连接清理（15秒探测一次，3次无响应自动释放僵尸会话）
    && echo "ClientAliveInterval 15" >> /etc/ssh/sshd_config \
    && echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config \
    && echo "TCPKeepAlive yes" >> /etc/ssh/sshd_config \
    # 防止未认证连接占满导致拒绝服务（将握手超时压缩至 15s 快速回收，并将并发连接池扩大到 50）
    && echo "LoginGraceTime 15" >> /etc/ssh/sshd_config \
    && echo "MaxStartups 50:30:100" >> /etc/ssh/sshd_config \
    # 设置 root 密码（请修改为你自己的密码）
    && echo "root:your_password" | chpasswd \
    # 创建硬盘挂载点目录并将 root 用户家目录（默认工作目录）设为 /data
    && mkdir -p /data \
    && sed -i 's|^root:.*:/root:|root:x:0:0:root:/data:|' /etc/passwd

EXPOSE 22

# -D 前台运行容器不退出，-e 将日志直接输出到标准错误方便 docker logs 查看
CMD ["/usr/sbin/sshd", "-D", "-e"]
