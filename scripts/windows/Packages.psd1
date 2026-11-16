@{
    InternalRootCAs    = @(
        @{
            Name       = 'BHPD Internal Root CA'
            Base64Cert = 'LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNCRENDQWF1Z0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQThNUXN3Q1FZRFZRUUdFd0pVVnpFTk1Bc0cKQTFVRUNnd0VRa2hRUkRFZU1Cd0dBMVVFQXd3VlFraFFSQ0JKYm5SbGNtNWhiQ0JTYjI5MElFTkJNQjRYRFRJMgpNRGt4T1RFMU1qRXdPVm9YRFRNMk1Ea3hOakUxTWpFd09Wb3dQREVMTUFrR0ExVUVCaE1DVkZjeERUQUxCZ05WCkJBb01CRUpJVUVReEhqQWNCZ05WQkFNTUZVSklVRVFnU1c1MFpYSnVZV3dnVW05dmRDQkRRVEJaTUJNR0J5cUcKU000OUFnRUdDQ3FHU000OUF3RUhBMElBQk95elJsUngvMGR6SjBScDlkYTFiQmdCSmxMbFpqU0NmcFN6ZjBMcQpaeWRjeFo0c1NmWENuTyt4MUhZU1JEa3Y0RGlnYVZwckhaUE1OYldjQ1FsRnBsK2pnWjB3Z1pvd053WUpZSVpJCkFZYjRRZ0VOQkNvV0tFOVFUbk5sYm5ObElFZGxibVZ5WVhSbFpDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnAKZEhrd0hRWURWUjBPQkJZRUZBZitMVWdDeTNKKzEwMEcwdUJHQ1JVWVMvQnRNQjhHQTFVZEl3UVlNQmFBRkFmKwpMVWdDeTNKKzEwMEcwdUJHQ1JVWVMvQnRNQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdEZ1lEVlIwUEFRSC9CQVFECkFnR0dNQW9HQ0NxR1NNNDlCQU1DQTBjQU1FUUNJRmxqSXZKenIyWHJ5Y0FvYzgybVpjU2J3QzRPa1h3NExkQ3IKcU13SlpDWkRBaUJub2xGWjdLRUhtZWlUOU5xYUpmSEtSeW5rMzAwUDhSaDd1eDl2cWZIemNRPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo='
        }
        @{
            Name       = 'BHGS Internal Root CA'
            Base64Cert = 'LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNCVENDQWF1Z0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQThNUXN3Q1FZRFZRUUdFd0pVVnpFTk1Bc0cKQTFVRUNnd0VRa2hIVXpFZU1Cd0dBMVVFQXd3VlFraEhVeUJKYm5SbGNtNWhiQ0JTYjI5MElFTkJNQjRYRFRJMgpNRGt4T1RFMU5UUTBNbG9YRFRNMk1Ea3hOakUxTlRRME1sb3dQREVMTUFrR0ExVUVCaE1DVkZjeERUQUxCZ05WCkJBb01CRUpJUjFNeEhqQWNCZ05WQkFNTUZVSklSMU1nU1c1MFpYSnVZV3dnVW05dmRDQkRRVEJaTUJNR0J5cUcKU000OUFnRUdDQ3FHU000OUF3RUhBMElBQkZGOVk0d0N5TVNnbzNJSjU2QnZOaE12Mnh2a2Y4MC9id2dCOGhILwpFZHhzUktYTS91YjhBWTlldmxaR0VzQlpUZzJaS0ZIT0dMajBpNngyWldUanA3T2pnWjB3Z1pvd053WUpZSVpJCkFZYjRRZ0VOQkNvV0tFOVFUbk5sYm5ObElFZGxibVZ5WVhSbFpDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnAKZEhrd0hRWURWUjBPQkJZRUZHMGU4VXdmZERWTlJ1N3RodXh1TmhmRVk0RG1NQjhHQTFVZEl3UVlNQmFBRkcwZQo4VXdmZERWTlJ1N3RodXh1TmhmRVk0RG1NQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdEZ1lEVlIwUEFRSC9CQVFECkFnR0dNQW9HQ0NxR1NNNDlCQU1DQTBnQU1FUUNJUUNmd0JISXNaTVdHWUZEbVNFNHVuQlNlUUZidkZLMzU0NHUKQ1hadVYwRlhTd0lnR0hwRDVWMGN4RmluS2VtenJVMU1ZQklpZXB0SnVEVmFQSnVhK2Qya3JHST0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo='
        }
    )
    CliPackages        = @(
        @{ Id = 'Microsoft.PowerShell'; Name = 'PowerShell 7' }
        @{ Id = 'BurntSushi.ripgrep.MSVC'; Name = 'ripgrep (rg)' }
        @{ Id = 'sharkdp.fd'; Name = 'fd' }
        @{ Id = 'ast-grep.ast-grep'; Name = 'ast-grep' }
        @{ Id = 'jqlang.jq'; Name = 'jq' }
        @{ Id = 'MikeFarah.yq'; Name = 'yq' }
        @{ Id = 'sharkdp.bat'; Name = 'bat' }
        @{ Id = 'chmln.sd'; Name = 'sd' }
        @{ Id = 'mvdan.shfmt'; Name = 'shfmt' }
        @{ Id = 'oschwartz10612.Poppler'; Name = 'Poppler (pdftotext)' }
        @{ Id = 'XAMPPRocky.Tokei'; Name = 'tokei' }
        @{ Id = 'BurntSushi.xsv.MSVC'; Name = 'xsv' }
        @{ Id = 'SQLite.SQLite'; Name = 'SQLite (sqlite3)' }
        @{ Id = 'ducaale.xh'; Name = 'xh' }
        @{ Id = 'bootandy.dust'; Name = 'dust' }
        @{ Id = 'DuckDB.cli'; Name = 'DuckDB CLI' }
        @{ Id = 'rhysd.actionlint'; Name = 'actionlint' }
        @{ Id = 'sharkdp.hyperfine'; Name = 'hyperfine' }
        @{ Id = 'Gyan.FFmpeg'; Name = 'FFmpeg' }
        @{ Id = 'yt-dlp.yt-dlp'; Name = 'yt-dlp' }
        @{ Id = 'AgileBits.1Password.CLI'; Name = '1Password CLI (op)' }
    )
    DesktopPackages    = @(
        @{ Id = 'Git.Git'; Name = 'Git for Windows' }
        @{ Id = 'Microsoft.VisualStudioCode'; Name = 'Visual Studio Code' }
        @{ Id = 'Microsoft.WindowsTerminal'; Name = 'Windows Terminal' }
        @{ Id = 'AgileBits.1Password'; Name = '1Password' }
        @{ Id = 'RevoUninstaller.RevoUninstaller'; Name = 'Revo Uninstaller' }
        @{ Id = 'M2Team.NanaZip'; Name = 'NanaZip' }
        @{ Id = 'ImageOptim.gifski'; Name = 'gifski' }
    )
    AntigravityPlugins = @(
        'common-modern-tools',
        'windows-modern-tools',
        'modern-web-stack'
    )
}
