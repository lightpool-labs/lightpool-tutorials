```text
第1步
请在需要时创建 lightpool-labs 目录，然后将以下 5 个仓库从 GitHub 组织 lightpool-labs 下载到该目录中。已存在的仓库请跳过：

1. lightpool-node
2. lightpool-clob-indexer
3. lightpool-bridge
4. event-contract-app
5. lightpool-bot

使用 SSH 地址：git@github.com:lightpool-labs/<repo>.git
```

```text
第2步
请帮我安装运行 LightPool event-contract 本地全栈所需的开发环境（若已安装请跳过并检查版本）：

1. Rust（rustup + cargo，稳定版）
2. Node.js（含 npm，建议 LTS）
3. Foundry（forge / cast / anvil）
4. Python 3（用于 bridge bootstrap 脚本）
5. 基础构建工具（如 git、curl、build-essential 等当前系统缺的依赖）

安装完成后请打印各工具版本，确认可用。
```

```text
第3步
请在 lightpool-labs 下编译运行 event-contract 本地全栈所需的全部二进制（release）：

1. lightpool-node（编译后 lightpool bin 在 lightpool-node/bin/lightpool，可用 source lightpool-node/env.sh 加入 PATH）
2. lightpool-clob-indexer
3. lightpool-bridge
4. event-contract-app backend
5. lightpool-bot（liquidity-maker）
6. Reth（运行 lightpool-node/tools/reth/download.sh 下载，二进制在 lightpool-node/tools/reth/bin/reth）

完成后确认各二进制可用。
```

```text
第4步
请运行本目录脚本启动无 bridge 的本地 event-contract 演示（不启动 Reth / bridge）：

./run-local.sh start

脚本会：创建统一数据目录、启动 lightpool / clob-indexer / backend / frontend / liquidity-maker、create-token 得到 USDT、给演示用户转入 1000 USDT、bootstrap 最多 4 个市场。

固定演示用户：
私钥 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
地址 0x70997970C51812dc3A010C7d01b50e0d17dc79C8

验收：打开 http://127.0.0.1:3000 应看到约 4 个 event；演示用户链上约有 1000 USDT，可下单。
停止：./run-local.sh stop
清空数据：./run-local.sh wipe
```
