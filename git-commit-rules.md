## 結構

```text
<type>(<scope>): <subject>
```

### type

-   用於說明commit的類別，只允許使用下面7個標識。

```text
feat：新功能（feature）
fix：修補bug
docs：文檔（documentation）
style： 格式（不影響代碼運行的變動）
refactor：重構（即不是新增功能，也不是修改bug的代碼變動）
test：增加測試
chore：構建過程或輔助工具的變動
```

### scope

-   用於說明commit影響的範圍，比如數據層、控制層、視圖層等等，視項目不同而不同。

### subject

-   是commit目的的簡短描述，不超過50個字符。
-   以動詞開頭，使用第一人稱現在時，比如change，而不是changed或changes
-   第一個字母小寫
-   結尾不加句號（.）

## 範例

-   更新翻譯專案的進度

```text
docs(translation): update translations to p013
```

-   增加上傳api

```text
feat(api): add uploading api
```

-   修正資料庫崩潰的bug

```text
fix(database): fix app crash while initialysing user data
```
