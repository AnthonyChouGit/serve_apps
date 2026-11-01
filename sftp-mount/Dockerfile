# 使用极轻量的 Alpine Linux（基础镜像仅 ~7MB，远小于 Ubuntu）
FROM alpine:latest

# 安装 OpenSSH 服务端与 SFTP 模块，并清理缓存
RUN apk add --no-cache openssh-server openssh-sftp-server \
    # 生成 SSH 服务端密钥
    && ssh-keygen -A \
    # 允许 root 密码登录
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    # 设置 root 密码（请修改为你自己的密码）
    && echo "root:your_password" | chpasswd \
    # 创建硬盘挂载点目录
    && mkdir -p /data

EXPOSE 22

# -D 前台运行容器不退出，-e 将日志直接输出到标准错误方便 docker logs 查看
CMD ["/usr/sbin/sshd", "-D", "-e"]
