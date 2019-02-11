# My macOS build

-   安裝環境自動安裝腳本

    ```bash
    curl -L https://git.io/florencea-macos-build-install -o tempsh;sh tempsh
    ```

    -   腳本開頭會詢問輸入github使用者名稱、github信箱、git系統預設文字編輯器、fish shell的問候語

-   DNS-over-HTTPS自動安裝腳本(可以新建一個網路設定檔之後再執行)

    ```bash
    curl -L https://git.io/florencea-macos-build-doh | sh
    ```

    -   安裝完成後會自動將Wi-Fi介面的DNS變為`127.0.0.1`

-   取得ublock備份

    ```bash
    curl -L https://git.io/florencea-macos-build-ublock -o ublock.txt
    ```
