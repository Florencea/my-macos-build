# Use GPG in Github

## Commends(Using CLI)

```fish
gpg --full-generate-key
gpg -a --export (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s") | pbcopy
# gpg key is already in clipboard, directly paste to GitHub
git config --global user.signingkey (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s")
git config --global commit.gpgsign true
git config --global gpg.program gpg
printf "pinentry-program /usr/local/bin/pinentry-mac\n" >> .gnupg/gpg-agent.conf
printf "no-tty\n" >> ~/.gnupg/gpg.conf
killall gpg-agent
```

## Details(Using GPG Suite)

- Install [GPG Suite](https://gpgtools.org/).

  ```fish
  brew cask install gpg-suite
  ```

- Create GPG Key

  ```fish
  gpg --full-generate-key

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

- Enter password for your key

- Export key

  ```fish
  gpg -a --export (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s")
  ```

- Copy full public key to github or gitlab

- Use GPG key in git

  ```fish
  git config --global user.signingkey (gpg -K --keyid-format LONG | grep sec | grep -o -E "\S{16}\s")
  git config --global commit.gpgsign true
  git config --global gpg.program gpg
  ```
