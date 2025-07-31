要在**远程服务器**上运行**Docker容器**，并通过**X11转发**把图形界面（如 matplotlib 绘图、xeyes、xclock 等）显示到**本地电脑**，你需要同时处理好两个层面：

### ✅ 一、远程服务器 → 本地电脑的 X11 转发（SSH 层面）
确保你本地电脑可以接收来自远程服务器的图形界面：

1. **本地电脑**安装 X11 Server：
   - Linux：通常已自带。
   - macOS：安装 [XQuartz](https://www.xquartz.org/)，并设置为允许网络连接。
   - Windows：安装 [VcXsrv](https://sourceforge.net/projects/vcxsrv/) 或 Xming。

2. **SSH 连接时启用 X11 转发**：
   ```bash
   ssh -X user@remote-server-ip
   ```
   或 `.ssh/config` 中添加：
   ```
   Host myserver
     HostName remote-server-ip
     User user
     ForwardX11 yes
     ForwardX11Trusted yes
   ```

3. **远程服务器**配置 `/etc/ssh/sshd_config`：
   ```
   X11Forwarding yes
   X11UseLocalhost no
   ```
   修改后重启 SSH：
   ```bash
   sudo systemctl restart sshd
   ```

---

### ✅ 二、Docker 容器 → 远程服务器的 X11 连接（容器层面）

你需要让容器知道 X server 在哪，并授权访问：

#### ✅ 推荐做法：使用 `xauth` 和挂载 X11 socket

1. **在远程服务器上**生成 `.xauth` 文件供容器使用：
   ```bash
   XSOCK=/tmp/.X11-unix
   XAUTH=/tmp/.docker.xauth
   xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -
   chmod 777 $XAUTH
   ```

2. **运行容器**时挂载 X11 socket 和 `.xauth` 文件：
   ```bash
   docker run -it --rm \
     -e DISPLAY=$DISPLAY \
     -e XAUTHORITY=$XAUTH \
     -v $XSOCK:$XSOCK \
     -v $XAUTH:$XAUTH \
     --net host \
     ubuntu:latest
   ```

3. 在容器内安装并运行 GUI 应用：
   ```bash
   apt update && apt install -y x11-apps
   xeyes
   ```

此时，`xeyes` 应该出现在你**本地电脑**的屏幕上。

---

### ⚠️ 注意事项

- **不要使用 `DISPLAY=localhost:0`**，这会导致容器无法连接到 X server。应使用 `$DISPLAY`（通常是 `:0` 或 `:10.0` 等）。
- **防火墙**：确保服务器没有阻止 X11 端口（通常是 6000 + display number）。
- **安全性**：`xhost +` 可用于快速测试，但生产环境请用 `xhost +local:docker` 或基于 IP 的白名单。

---

### ✅ 一键脚本（远程服务器端）

你可以把下面的脚本保存为 `run-gui-docker.sh`：

```bash
#!/bin/bash
XSOCK=/tmp/.X11-unix
XAUTH=/tmp/.docker.xauth
xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -
chmod 777 $XAUTH

docker run -it --rm \
  -e DISPLAY=$DISPLAY \
  -e XAUTHORITY=$XAUTH \
  -v $XSOCK:$XSOCK \
  -v $XAUTH:$XAUTH \
  --net host \
  "$@"
```

使用方式：
```bash
./run-gui-docker.sh ubuntu:latest
```

---

如需进一步支持 CUDA/OpenGL 图形，可考虑使用 [dockerx](https://github.com/udkyo/dockerx) 工具，它封装了这些步骤。
