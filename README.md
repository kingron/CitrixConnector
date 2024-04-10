史上最强的Citrix Gateway VM一键连接工具

# 功能特性

- 支持 Citrix Gateway 2016 版本
- 支持自配置，首次运行自动启动自配置
- 数据按加密保存且绑定机器
- 无任何内存驻留，不消耗任何资源
- 减轻 Citrix 网关压力
- 除Bash环境外，无需其他第三方工具、软件支持（不需要Citrix Receiver！）
- 多显示器配置支持
  
# 如何使用

- 用Git for Windows自带的Bash运行，你也可以使用 MingGW 等其他Bash环境运行
- 可以把 vm.sh 锁定到任务栏，之后可以右击直接运行一键连接
- 若自签名证书使用 openssl 1.x 生成，则必须使用 git v2.12.0 ~ v2.39 之间的版本，若证书使用 openssl 3.x ，则需要使用 Git for 2.41.0 及以上版本运行。低版本无法支持 pbkdf2 加密，高版本暂不支持 openssl 3.x 
  
