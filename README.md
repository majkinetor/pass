# pass

Pass for windows using Powershell

#https://git.zx2c4.com/password-store/about/


- pass insert Business/cheese-whiz-factory  
Add-Password Business/cheese-whiz-factory
- pass generate Email/jasondonenfeld.com 15  
New-Password 15 | Add-Password Email/jasondonenfeld.com
- pass Email/zx2c4.com  
Show-Password Email/zx2c4.com  
- pass -c Email/zx2c4.com
Show-Password Email/zx2c4.com -Clipboard