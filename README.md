# ChatGPT Linux Installer

一支用來下載並安裝最新版 **ChatGPT for Linux** 的 Bash 腳本，支援 Debian／Ubuntu 與 Fedora／RHEL 系列發行版，以及 x86-64、ARM64 架構。

> [!IMPORTANT]
> 這是社群維護的安裝腳本，並非 OpenAI 官方專案。預設套件會直接從 OpenAI 的 `persistent.oaistatic.com` 下載。

## 功能

- 自動辨識 Linux 發行版、套件格式與 CPU 架構
- 安裝官方最新版 `.deb` 或 `.rpm` 套件
- 安裝前檢查套件格式、名稱、架構及發行者資訊
- 可用 SHA-256 驗證下載檔
- 支援安裝本機套件或自訂 HTTPS 下載網址
- 預設安裝並設定 IBus 新酷音，改善中文輸入與 WSLg 相容性
- 可選擇安裝後立即啟動 ChatGPT

## 支援環境

| 發行版系列 | 套件格式 | 支援架構 |
| --- | --- | --- |
| Debian、Ubuntu | `.deb` | x86-64 (`amd64`)、ARM64 (`arm64`) |
| Fedora、RHEL | `.rpm` | x86-64 (`x86_64`)、ARM64 (`aarch64`) |

系統需提供 `bash`、`sudo` 與圖形桌面環境。腳本會按需透過 `apt-get` 或 `dnf` 安裝其他相依套件。請以一般使用者執行，勿直接使用 `sudo` 執行整支腳本。

## 安裝

```bash
git clone https://github.com/wengct/chatgpt-linux-installer.git
cd chatgpt-linux-installer
chmod +x install-chatgpt-linux.sh
./install-chatgpt-linux.sh
```

安裝完成後執行：

```bash
chatgpt
```

預設會將下載的安裝檔保留在 `~/Downloads`。若啟用預設的中文輸入設定，可按 `Ctrl+Space` 啟用新酷音，並以單按 `Shift` 切換中英文。

## 常用範例

只顯示目前系統對應的官方下載網址：

```bash
./install-chatgpt-linux.sh --print-url
```

安裝後立即啟動：

```bash
./install-chatgpt-linux.sh --launch
```

略過 IBus／新酷音設定：

```bash
./install-chatgpt-linux.sh --no-ime
```

安裝本機既有套件：

```bash
./install-chatgpt-linux.sh --file /path/to/chatgpt.deb
```

以已知 SHA-256 驗證套件：

```bash
./install-chatgpt-linux.sh --sha256 <64-character-sha256>
```

## 選項

```text
--url URL          改用指定的 HTTPS 套件網址
--file PATH        安裝本機既有的 .deb 或 .rpm
--sha256 HASH      驗證套件 SHA-256
--download-dir DIR 保留下載檔的位置（預設：~/Downloads）
--no-keep          安裝後不保留本次下載的套件
--no-ime           不安裝／設定 IBus 新酷音與應用程式啟動包裝
--launch           安裝完成後啟動 ChatGPT
--print-url        只顯示目前系統對應的官方下載網址
-h, --help         顯示說明
```

也可使用以下環境變數：

- `CHATGPT_PACKAGE_URL`：自訂套件下載網址
- `CHATGPT_PACKAGE_SHA256`：預期的 SHA-256
- `CHATGPT_DOWNLOAD_DIR`：下載檔保留目錄

命令列選項會覆蓋對應的環境變數。

## 中文輸入與 WSLg

除非指定 `--no-ime`，腳本會安裝 IBus、新酷音及 Noto CJK 字型，並進行以下設定：

- 將 `Ctrl+Space` 設為輸入法切換鍵
- 將新酷音設為預設中文輸入引擎
- 在 `/usr/local/bin/chatgpt` 建立 IBus／X11 相容啟動器
- 若偵測到 Google Chrome，建立相容啟動器並更新其桌面項目

這些操作會修改目前使用者的 IBus 設定與系統啟動器。若不希望變更輸入法或 Chrome 設定，請使用 `--no-ime`。

## 安全性說明

腳本只接受 HTTPS 自訂下載網址，並會驗證套件的基本中繼資料。官方下載若未提供固定雜湊，腳本會顯示實際 SHA-256，但無法據此確認檔案是否符合預期；在需要可重現驗證的環境中，請自行取得可信雜湊並透過 `--sha256` 傳入。

建議執行前先閱讀腳本內容：

```bash
less install-chatgpt-linux.sh
```

## 授權

本專案採用 [MIT License](LICENSE)。
