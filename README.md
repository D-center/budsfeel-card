# budsfeel-card

LSPosed 模块：把 **弱水时砂 BudsFeel Mk2（蓝牙名 ROSE BudsFeel MK2）** 接入 ColorOS 原生耳机组件——控制中心设备卡片 + 无线耳机 OneSpace 降噪面板，不用再打开 RoseLink 切降噪。

本项目基于 [Cznorth/rose-card](https://github.com/Cznorth/rose-card)（适配 Rose EarFeel i5）改造，沿用同一套 RoseLink 平台 BLE 协议。

> 关于应用名：ColorOS 系统内置的耳机应用在本机显示为「**无线耳机**」，包名 `com.oplus.melody`（应用商店/部分机型与文档里又称「欢律」HeyMelody，为同一应用）。本模块作用域即该应用，LSPosed 里勾选「无线耳机」即可。

## 功能

- 控制中心出现 BudsFeel 设备卡片，带左右耳电量环；耳机断开时卡片自动消失，连上后自动出现
- 卡片/面板里点降噪模式直接生效：普通、通透、降噪、透风（防风降噪）
- OneSpace 面板显示左右耳电量（充电仓电量需开盒时才有）
- 面板「耳机设置」跳转 RoseLink，「断开连接」真正断开耳机

## 环境要求

- ColorOS 17（Android 17，测试机一加 PLK110 `17.0.0.105`），已 root + LSPosed
- 无线耳机（欢律）`com.oplus.melody` **17.6.3**（混淆名绑定该版本，其他版本大概率失效）
- 耳机已在系统蓝牙中配对（按蓝牙名 `ROSE BudsFeel MK2` 识别，匹配规则为 ROSE 开头且包含 BUDSFEEL/EARFREE/EARFEEL）

## 安装

1. 从 Releases 下载 `budsfeel-card.apk` 安装
2. LSPosed 中启用模块，作用域勾选 **无线耳机（com.oplus.melody）**
3. 强行停止无线耳机（或重启手机），连上耳机，约 5 秒后控制中心出现卡片
4. 首次点「耳机设置」时系统会询问是否允许无线耳机打开 RoseLink，选「30 天内允许」即可不再弹

## 已知问题

- 无线耳机（com.oplus.melody）更新后需要重新适配
- BudsFeel Mk2 为自适应降噪，降噪深度由耳机算法自动调节；卡片上的弱/中/强三档都会进入降噪模式，若耳机不支持手动档位命令则三档等效（模块已做容错，不会报错）

## 实现说明

- 作用域：`com.oplus.melody`（主进程写卡片、处理点击；`:fg` 进程给 OneSpace 面板喂数据）
- 卡片：用无线耳机内置 mydevices SDK `DeviceInfoManager.h(DeviceInfo)` 写入，宿主 `com.heytap.mydevices` 只信任该应用
- 点击：宿主/面板发 `com.oplus.melody.setgate` → hook `NoiseReductionCommand.onReceive` → BLE 写耳机
- 面板：hook `com.oplus.melody.onespace.b.onViewCreated`，构造 `WhitelistConfigDTO`/`Ba.z`/`l9.b` 喂给三个观察者
- 电量：BLE 帧 `01 01`（读回包与主动通知同格式），payload 7 字节 `?? ?? 左 右 ?? ?? 盒`，盒 `ff` = 未知（未开盒）。卡片只填 `batteryInfoList`（填 `mBatteryList` 宿主解析失败）；面板喂 `OneSpaceHeaderPreference$initObserver$4`（`P9.a`）
- 连接：面板底部「立即连接」由 `ContentFragment.z(fragment, 2)` 隐藏；主进程监听 ACL，断开时 `DeviceInfoManager.g` 删卡、连上时重读并插入；每 10 分钟轮询一次
- 「耳机设置」→ 显式组件启动 RoseLink（无线耳机无 `<queries>`；ColorOS 会弹关联启动确认）
- 「断开连接」→ 同无线耳机做法，HFP/A2DP profile 代理反射 `disconnect(device)`；失败则打开蓝牙设置
- 模式映射：1 关闭→普通，2 通透，3/5/4 弱/中/强→降噪（BudsFeel Mk2 自适应，档位命令可选），10 自适应→透风（防风降噪；hook `OneSpaceNoisePreference.i` 把面板文案「自适应」换成「透风」）

### BLE 协议（RoseLink 平台协议）

- 帧格式：请求 `08 ee 00 00 00 GRP CMD LEN_LO LEN_HI PAYLOAD... SUM`，响应 `09 ff 00 00 ST GRP CMD ... SUM`；`LEN` 为整帧长度，`SUM` 为前面所有字节之和 & 0xff，`ST=01` 表示成功；设置命令 = 读取命令 | 0x80
- `06 02 / 06 82`：降噪模式，4 字节 one-hot `[降噪, 普通, 风噪, 通透]`
- `06 07 / 06 87`：ANC 等级，1 字节 `00 轻度 / 01 中度 / 02 深度`（自适应机型可能拒绝该命令，调用方按可选处理）
- 控制特征按 GATT instanceId 识别（写 `0x000e`、通知 `0x0010`），不依赖固定 UUID；双模设备 BLE 走与经典蓝牙相同的公共地址

## 构建

无 Gradle，Windows 下直接运行：

```powershell
./build.ps1
```

需要 JDK 17、Android SDK（build-tools 36.1.0、platform android-35），脚本顶部可改工具链路径；Xposed API 用 `stubs/` 桩类编译、不打包。产物为 `build/budsfeel-card.apk`。原仓库的 `build.sh` 为 WSL 环境保留。

## 免责声明

非官方项目，与弱水时砂（ROSESELSA）、OPPO/一加无关。修改系统应用有风险，使用后果自负。

## License

MIT
