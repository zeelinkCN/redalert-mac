# 开发下载缓存

此目录中的安装包与资源是开发过程的临时缓存，均不提交到 Git。默认游戏、MOD、汉化与音乐的正式缓存由客户端保存在 `~/Library/Application Support/RedAlertMac/Downloads/`。

从源码构建所需的 cnc-ddraw DLL 和 7-Zip 工具由 `scripts/bootstrap-resources.sh` 从固定的上游版本下载并校验。游戏本体不是编译依赖。
