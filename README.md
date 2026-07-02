# macOS Oh My Zsh 一键初始化脚本

这是一个用于 macOS 恢复出厂设置后快速初始化终端环境的菜单式脚本。它参考了 [xxx252525/OhMyZsh](https://github.com/xxx252525/OhMyZsh) 的手动安装思路，并针对 macOS 做了整理。

## 能做什么

- 安装 Homebrew
- 运行 macOS、curl、Homebrew、Git、zsh 预检
- 检查并修复 Homebrew `share` 目录权限
- 如果 Git 不可用，通过 Homebrew 自动安装 Git
- 通过 Homebrew 安装 Node.js 和 npm
- 通过 npm 全局安装 `@electron/asar`
- 通过 Homebrew 安装 `autojump`
- 安装或更新 Oh My Zsh
- 安装 Powerlevel10k 主题
- 安装常用插件：
  - `zsh-autosuggestions`
  - `zsh-syntax-highlighting`
  - `zsh-completions`
- 写入个性化 `.zshrc` 配置：
  - 关闭终端自动标题
  - 加载 Homebrew zsh 补全
  - 启用 `git`、`autojump` 和 zsh 常用插件
  - 添加常用快捷别名
  - 加载 autojump 初始化脚本
- 安装 Powerlevel10k 推荐字体 MesloLGS Nerd Font
- 自动备份并生成 `~/.zshrc`
- 引导进入 `p10k configure` 模板配置页面

## 一键运行

下载项目后执行：

```bash
chmod +x install-macos-ohmyzsh.sh
./install-macos-ohmyzsh.sh
```

如果你想直接跑完整安装：

```bash
./install-macos-ohmyzsh.sh full
```

## 菜单功能

```text
1) 完整安装
2) 安装 Homebrew + Node.js/npm + @electron/asar + autojump
3) 安装/更新 Oh My Zsh + Powerlevel10k + 插件
4) 安装 MesloLGS Nerd Fonts
5) 配置 ~/.zshrc
6) 运行 Powerlevel10k 配置向导
7) 查看安装状态
8) 修复 Homebrew share 权限
9) 运行预检
0) 退出
```

## 恢复出厂设置后的推荐流程

1. 打开 macOS 自带“终端”。
2. 克隆你的 GitHub 仓库。
3. 进入项目目录。
4. 执行完整安装：

```bash
./install-macos-ohmyzsh.sh full
```

脚本安装字体后，如果终端没有自动切换字体，请在终端设置里手动选择 `MesloLGS NF`。

## 注意事项

- 首次安装 Homebrew 时，macOS 可能会要求输入开机密码，或弹出 Command Line Tools 安装确认。
- 如果 Homebrew 已经安装但还没进入 PATH，脚本会自动加载 `/opt/homebrew/bin/brew` 或 `/usr/local/bin/brew`。
- 如果 Git 不可用，脚本会先确保 Homebrew 可用，再通过 Homebrew 安装 Git，然后继续克隆 Oh My Zsh 和插件仓库。
- 脚本会在安装 Homebrew 后、执行 `brew install node` 前检查 Homebrew 的 `share` 目录是否可写。如果遇到 `/opt/homebrew/share` 或 `/usr/local/share` 权限问题，会提示修复；如果没有完成修复，脚本会先停止，避免继续执行后遇到 brew 权限报错。
- 脚本会备份原来的 `~/.zshrc`，备份文件格式为 `~/.zshrc.backup.YYYYMMDDHHMMSS`。
- 修改默认 shell 时会询问确认，并可能要求输入 macOS 密码。
- 如果 Powerlevel10k 配置向导没有自动出现，可以打开新终端后执行：

```bash
p10k configure
```

## 单独修复 Homebrew share 权限

如果之后单独使用 Homebrew 时遇到类似 `share is not writable`、`/opt/homebrew/share` 或 `/usr/local/share` 权限错误，可以执行：

```bash
./install-macos-ohmyzsh.sh brew-permissions
```

## 参考来源

- [xxx252525/OhMyZsh](https://github.com/xxx252525/OhMyZsh)
- [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [zsh-completions](https://github.com/zsh-users/zsh-completions)
