# My macOS build

-   常用指令紀錄

    ```fish
    # 重置launchpad
    defaults write com.apple.dock ResetLaunchPad -bool true
    killall Dock

    # 防止AdobeCreativeCloud開機啟動
    sudo rm -f /Library/LaunchAgents/com.adobe.AdobeCreativeCloud.plist

    # SSD開啟trimforce
    sudo trimforce enable

    # 禁用Chrome本機快取
    defaults write com.google.Chrome DiskCacheDir -string /dev/null

    # 下載舊版macOS
    curl -O https://raw.githubusercontent.com/munki/macadmin-scripts/master/installinstallmacos.py
    sudo python installinstallmacos.py

    # 製作git.io縮網址
    curl -i https://git.io -F "url=<目標網址>" -F "code=<自訂縮網址>" | grep Location
    ```

-   [常用 Ubuntu 指令紀錄](ubuntu-1804-cmd.md)

-   [git commit rules](git-commit-rules.md)

-   hubmle tab config

    -   for light color

    ```text
    {"options.show_top":"0","options.show_closed":"0","column.0.0":"1","column.1.0":"apps","options.auto_close":"1","open.closed":"true","options.hide_options":"1","options.show_recent":"0","options.shadow_color":"transparent","options.highlight_font_color":"#000","options.show_root":"0","options.show_devices":"0","apps.order":"[\"webstore\",\"pjkljhegncpnkpknbcohdijeoejaedia\",\"apdfllckaahabafndbhieahigkjlhalf\",\"pnhechapfaindjhompbnflcldabbghjo\",\"blpcfgokakmgnkcojhhkbfbldkacnbeo\",\"aohghmighlieiainnegkcijnfilokake\",\"aapocclcgogkmnckokdopfmhonfmgoek\",\"felcaaldnbdncclmgdcncolpebgiejap\"]","options.show_weather":"0","options.highlight_color":"#f1f1f1","options.width":"0.656","options.background_color":"#fafafa","options.font_color":"#333","options.lock":"1","options.css":"#main a{border-radius:1em;}","options.font_size":"20","options.show_apps":"1","options.show_2":"0"}
    ```

    -   for dark color

    ```text
    {"apps.order":"[\"webstore\",\"pjkljhegncpnkpknbcohdijeoejaedia\",\"apdfllckaahabafndbhieahigkjlhalf\",\"pnhechapfaindjhompbnflcldabbghjo\",\"blpcfgokakmgnkcojhhkbfbldkacnbeo\",\"aohghmighlieiainnegkcijnfilokake\",\"aapocclcgogkmnckokdopfmhonfmgoek\",\"felcaaldnbdncclmgdcncolpebgiejap\"]","column.0.0":"1","column.1.0":"apps","open.closed":"true","options.auto_close":"1","options.background_color":"#202124","options.css":"#main a{border-radius:1em;}","options.font_color":"#bec1c5","options.font_size":"20","options.hide_options":"1","options.highlight_color":"#333639","options.highlight_font_color":"#eff1f2","options.lock":"1","options.shadow_color":"transparent","options.show_2":"0","options.show_apps":"1","options.show_closed":"0","options.show_devices":"0","options.show_recent":"0","options.show_root":"0","options.show_top":"0","options.show_weather":"0","options.width":"0.656"}
    ```

-   安裝環境自動安裝腳本

    ```bash
    curl -L https://git.io/florencea-macos-build-install -o tempsh;sh tempsh
    ```

    -   完整版

    ```bash
    curl -L https://git.io/florencea-macos-build-install-full -o tempsh;sh tempsh
    ```

    -   完整版腳本開頭會詢問輸入github使用者名稱、github信箱、git系統預設文字編輯器、fish shell的問候語

-   DNS-over-HTTPS自動安裝腳本(可以新建一個網路設定檔之後再執行)

    ```bash
    curl -L https://git.io/florencea-macos-build-doh | sh
    ```

    -   安裝完成後請將系統DNS改為`127.0.0.1`

-   取得ublock備份

    ```bash
    curl -L https://git.io/florencea-macos-build-ublock -o ublock.txt
    ```

-   取得ublock-adv備份

    ```bash
    curl -L https://git.io/florencea-macos-build-ublock-adv -o ublock-adv.txt
    ```

-   設置gpg (詳見 [gpg.md](gpg.md))

    -   安裝 [GPG Suite](https://gpgtools.org/)

        ```fish
        ~> brew cask install gpg-suite
        ```

    -   建立 GPG key

        ```fish
        ~> gpg --full-generate-key

        # 請選擇你要使用的金鑰種類:
        #   (1) RSA 和 RSA (預設)
        #   (2) DSA 和 Elgamal
        #   (3) DSA (僅能用於簽署)
        #   (4) RSA (僅能用於簽署)
        你要選哪一個? 1

        # RSA 金鑰的長度可能介於 1024 位元和 4096 位元之間.
        你想要用多大的金鑰尺寸? (2048) 4096

        # 請指定這把金鑰的有效期限是多久.
        #         0 = 金鑰不會過期
        #      <n>  = 金鑰在 n 天後會到期
        #      <n>w = 金鑰在 n 週後會到期
        #      <n>m = 金鑰在 n 月後會到期
        #      <n>y = 金鑰在 n 年後會到期
        金鑰的有效期限是多久? (0) 0

        以上正確嗎? (y/N) y

        # GnuPG 需要建構使用者 ID 以識別你的金鑰.

        真實姓名: <your_name>

        電子郵件地址: <your_github_email>

        註釋:

        變更姓名(N), 註釋(C), 電子郵件地址(E)或確定(O)/退出(Q)? o
        ```

    -   設定 GPG key 的密碼

    -   輸出 GPG key

        ```fish
        ~> gpg -a --export (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s")
        ```

    -   複製完整 public key 至 github 或 gitlab

    -   在 git 中使用 GPG key

        ```fish
        ~> git config --global user.signingkey (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s")
        ~> git config --global commit.gpgsign true
        ~> git config --global gpg.program gpg
        ```
