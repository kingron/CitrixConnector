#!/bin/bash

echo "Citrix Gateway VM 连接工具 v1.0"
echo "Copyright© Kingron, 2024"
echo "本工具不驻留内存，不消耗任何额外的资源。"

highlight() {
    echo -e "\033[$1m$2\033[0m"
}

function input() {
	local buf=""
    while true; do
        read -p $2 "$1" buf
        if [ -z "$buf" ]; then
            highlight 41 "输入不能为空，请重新输入。" >&2
        else
            break
        fi
    done
	echo $buf
}

check() {
    if [ $? -ne 0 ]; then
        highlight 41 "失败"
        read -n 1 -s -r -p "按任意键继续..."
        exit 1
    fi
}

if [[ "$1" == "-h" || "$1" == "/?" || "$1" == "--help" ]]; then
    echo "用法:	$0 [-h]"
	echo "例如："
	echo "	$0	初始化或一键连接"
	echo "	$0 -h	显示帮助"
	echo "初始化只会运行一次，请勿中断初始化过程"
	highlight 41 "若有问题可删除 config.dat, headers.txt 重新初始化"
	echo "可自定义headers.txt，以适配特殊情况"
	exit 0
fi

cd "$(dirname "$(readlink -f "$0")")"
# 初始化或读取配置
if [ -f config.dat ]; then
	# 加载配置
    source config.dat
    password=$(echo "$key" | openssl enc -d -aes-256-cbc -pbkdf2 -base64 -k "$COMPUTERNAME$salt")
else
	highlight 41 "开始初始化配置，若有问题可删除 config.dat 重新初始化"
    read -p "请输入Citrix网关地址(默认: https://www.gateway_server.com): " server
	server=${server:-https://www.gateway_server.com}
	user=$(input "用户名(corp id): ")
	password=$(input -s "请输入密码: ")
#	password=$(curl -Gso /dev/null -w %{url_effective} --data-urlencode "data=$password" "" | cut -d'=' -f2)
	echo
    read -p "目标VM IP地址(若有多个VM必输，否则可选): " ip
    read -p "多显示器支持，多个用逗号分隔(例如0,1表示在第1、2个显示器显示，不输表示单显示器模式): " monitors

    salt=$(openssl rand -hex 10)
    key=$(echo "$password" | openssl enc -aes-256-cbc -pbkdf2 -base64 -k "$COMPUTERNAME$salt")

	# 保存配置
    echo "server=$server" > config.dat
    echo "user=$user" >> config.dat
    echo "ip=$ip" >> config.dat
    echo "salt=$salt" >> config.dat
    echo "key=$key" >> config.dat
    echo "monitors=$monitors" >> config.dat
fi

# echo $server - $user - $password - $ip
if [ -f desktop.rdp ]; then
	rm desktop.rdp
fi
if [ ! -f headers.txt ]; then
	cat <<EOF >headers.txt
Accept: application/xml, text/xml, */*; q=0.01
Accept-Encoding: gzip, deflate, br, zstd
Accept-Language: zh-CN,zh;q=0.9
Cache-Control: no-cache
Connection: keep-alive
Origin: $server
Pragma: no-cache
Referer: $server
Sec-Fetch-Dest: empty
Sec-Fetch-Mode: cors
Sec-Fetch-Site: same-origin
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36 Edg/123.0.0.0
X-Citrix-AM-CredentialTypes: none, username, domain, password, newpassword, passcode, savecredentials, textcredential, webview, nsg-epa, nsg-x1, nsg-setclient, nsg-eula, nsg-tlogin, nsg-fullvpn, nsg-hidden, nsg-auth-failure, nsg-auth-success, nsg-epa-success, nsg-l20n, GoBack, nf-recaptcha, ns-dialogue, nf-gw-test, nf-poll, nsg_qrcode, nsg_manageotp, negotiate, nsg_push, nsg_push_otp, nf_sspr_rem
X-Citrix-AM-LabelTypes: none, plain, heading, information, warning, error, confirmation, image, nsg-epa, nsg-epa-failure, nsg-login-label, tlogin-failure-msg, nsg-tlogin-heading, nsg-tlogin-single-res, nsg-tlogin-multi-res, nsg-tlogin, nsg-login-heading, nsg-fullvpn, nsg-l20n, nsg-l20n-error, certauth-failure-msg, dialogue-label, nsg-change-pass-assistive-text, nsg_confirmation, nsg_kba_registration_heading, nsg_email_registration_heading, nsg_kba_validation_question, nsg_sspr_success, nf-manage-otp
X-Citrix-IsUsingHTTPS: Yes
X-Requested-With: XMLHttpRequest
sec-ch-ua: "Microsoft Edge";v="123", "Not:A-Brand";v="8", "Chromium";v="123"
sec-ch-ua-mobile: ?0
sec-ch-ua-platform: "Windows"
EOF
fi

opts="-s -H @headers.txt --insecure --cert XXXX.pfx:XXXX --cert-type P12"
echo 获取鉴权环境...
curl $opts -i -o response.txt -X 'POST' "$server/nf/auth/getAuthenticationRequirements.do"
check
url=$(grep -o '<PostBack>[^<]*</PostBack>' response.txt | sed 's/<\/\?PostBack>//g')
context=$(echo "$url" | sed 's/\/nf\/auth\/doCert\.do?//')
echo url=$url
echo

echo 获取令牌 NSC_TMAS...
curl $opts -i -o response.txt -X 'POST' "$server$url" --data-raw \"$context\"
check
NSC_TMAS=$(grep -o 'NSC_TMAS=[^;]*' response.txt | sed 's/NSC_TMAS=//')
cookie="NSC_TMAS=$NSC_TMAS"
echo $cookie
echo

echo 开始鉴权...
curl $opts -i -o response.txt -X 'POST' "$server/nf/auth/doAuthentication.do" -b "$cookie" --data-raw "login=$user&passwd=$password&domain=ss_corp&loginBtn=Log+On&StateContext="
check
NSC_AAAC=$(grep -o 'NSC_AAAC=[^;]*' response.txt | sed 's/NSC_AAAC=//')
cookie="NSC_SAMS=Strict;NSC_AAAC=$NSC_AAAC"
StateContext=$(grep -o '<StateContext>[^<]*</StateContext>' response.txt | sed 's/<\/\?StateContext>//g')
echo $cookie
echo Context: $StateContext
echo

echo 配置客户端...
curl $opts -i -o response.txt -X 'POST' "$server/p/u/setClient.do" -b "$cookie" --data-raw "nsg-setclient=cvpn&StateContext=$StateContext"
check
NSC_TEMP=$(grep -o 'NSC_TEMP=[^;]*' response.txt | sed 's/NSC_TEMP=//')
cookie="NSC_SAMS=Strict; NSC_AAAC=$NSC_AAAC; NSC_TEMP=$NSC_TEMP"
echo $cookie
echo

echo 获取远程VM地址清单...
curl $opts -i -o response.txt -X 'GET' "$server/cgi/resources/list" -b "$cookie"
content=$(grep -o '"content":"[^"]*"' response.txt | awk -F '"' '{print $4}')
check
echo $content
echo
if [ -z "$ip" ]; then
	rdpUrl="$content"
else
	echo 抽取 $ip 对应的地址...
	rdpUrl=$(echo "$content" | awk -v ip="$ip" '{for(i=1;i<=NF;i++) if($i ~ ip) print $i}')
fi

echo 下载RDP配置文件: $rdpUrl
curl $opts -o desktop.rdp -X 'GET' "$rdpUrl" -b "$cookie"
check

echo 更改为单个桌面连接...
echo >>desktop.rdp
if [ ! -z "$monitors" ]; then
	echo "selectedmonitors:s:$monitors">>desktop.rdp
fi
echo "compression:i:1">>desktop.rdp
echo "username:s:$user">>desktop.rdp
sed -i 's/redirectclipboard:i:0/redirectclipboard:i:1/g' desktop.rdp
# sed -i 's/redirectdrives:i:0/redirectdrives:i:1/g' desktop.rdp
if [ -z "$monitors" ]; then
	sed -i 's/use multimon:i:1/use multimon:i:0/g' desktop.rdp
fi
echo 等待远程服务器配置就绪...
highlight 44\;97 "若失败请手动打开 desktop.rdp 或重试..."
highlight 44\;97 "请勿勾选记住密码，因为连接每次都不一样"
sleep 10
echo 启动远程桌面
cmd //c start mstsc //admin desktop.rdp &
sleep 1
rm response.txt
