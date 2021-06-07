#!/bin/bash

export LC_ALL=C
#export LANG=C
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
  sudoCmd="sudo"
else
  sudoCmd=""
fi

uninstall() {
  ${sudoCmd} $(which rm) -rf $1
  printf "File or Folder Deleted: %s\n" $1
}


# fonts color
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
bold(){
    echo -e "\033[1m\033[01m$1\033[0m"
}


osCPU="intel"
osArchitecture="arm"
osInfo=""
osRelease=""
osReleaseVersion=""
osReleaseVersionNo=""
osReleaseVersionCodeName="CodeName"
osSystemPackage=""
osSystemMdPath=""
osSystemShell="bash"


function checkArchitecture(){
	# https://stackoverflow.com/questions/48678152/how-to-detect-386-amd64-arm-or-arm64-os-architecture-via-shell-bash

	case $(uname -m) in
		i386)   osArchitecture="386" ;;
		i686)   osArchitecture="386" ;;
		x86_64) osArchitecture="amd64" ;;
		arm)    dpkg --print-architecture | grep -q "arm64" && osArchitecture="arm64" || osArchitecture="arm" ;;
		* )     osArchitecture="arm" ;;
	esac
}

function checkCPU(){
	osCPUText=$(cat /proc/cpuinfo | grep vendor_id | uniq)
	if [[ $osCPUText =~ "GenuineIntel" ]]; then
		osCPU="intel"
    else
        osCPU="amd"
    fi

	# green " Status 状态显示--当前CPU是: $osCPU"
}

# 检测系统发行版代号
function getLinuxOSRelease(){
    if [[ -f /etc/redhat-release ]]; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemMdPath="/usr/lib/systemd/system/"
        osReleaseVersionCodeName=""
    elif cat /etc/issue | grep -Eqi "debian|raspbian"; then
        osRelease="debian"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="buster"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        osRelease="ubuntu"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="bionic"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemMdPath="/usr/lib/systemd/system/"
        osReleaseVersionCodeName=""
    elif cat /proc/version | grep -Eqi "debian|raspbian"; then
        osRelease="debian"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="buster"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        osRelease="ubuntu"
        osSystemPackage="apt-get"
        osSystemMdPath="/lib/systemd/system/"
        osReleaseVersionCodeName="bionic"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        osRelease="centos"
        osSystemPackage="yum"
        osSystemMdPath="/usr/lib/systemd/system/"
        osReleaseVersionCodeName=""
    fi

    getLinuxOSVersion
    checkArchitecture
	checkCPU

    [[ -z $(echo $SHELL|grep zsh) ]] && osSystemShell="bash" || osSystemShell="zsh"

    green " 系统信息: ${osInfo}, ${osRelease}, ${osReleaseVersion}, ${osReleaseVersionNo}, ${osReleaseVersionCodeName}, ${osCPU} CPU ${osArchitecture}, ${osSystemShell}, ${osSystemPackage}, ${osSystemMdPath}"
}

# 检测系统版本号
getLinuxOSVersion(){
    if [[ -s /etc/redhat-release ]]; then
        osReleaseVersion=$(grep -oE '[0-9.]+' /etc/redhat-release)
    else
        osReleaseVersion=$(grep -oE '[0-9.]+' /etc/issue)
    fi

    # https://unix.stackexchange.com/questions/6345/how-can-i-get-distribution-name-and-version-number-in-a-simple-shell-script

    if [ -f /etc/os-release ]; then
        # freedesktop.org and systemd
        source /etc/os-release
        osInfo=$NAME
        osReleaseVersionNo=$VERSION_ID

        if [ -n $VERSION_CODENAME ]; then
            osReleaseVersionCodeName=$VERSION_CODENAME
        fi
    elif type lsb_release >/dev/null 2>&1; then
        # linuxbase.org
        osInfo=$(lsb_release -si)
        osReleaseVersionNo=$(lsb_release -sr)
    elif [ -f /etc/lsb-release ]; then
        # For some versions of Debian/Ubuntu without lsb_release command
        . /etc/lsb-release
        osInfo=$DISTRIB_ID
        
        osReleaseVersionNo=$DISTRIB_RELEASE
    elif [ -f /etc/debian_version ]; then
        # Older Debian/Ubuntu/etc.
        osInfo=Debian
        osReleaseVersion=$(cat /etc/debian_version)
        osReleaseVersionNo=$(sed 's/\..*//' /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        osReleaseVersion=$(grep -oE '[0-9.]+' /etc/redhat-release)
    else
        # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
        osInfo=$(uname -s)
        osReleaseVersionNo=$(uname -r)
    fi
}

osPort80=""
osPort443=""
osSELINUXCheck=""
osSELINUXCheckIsRebootInput=""

function testLinuxPortUsage(){
    $osSystemPackage -y install net-tools socat

    osPort80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80`
    osPort443=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443`

    if [ -n "$osPort80" ]; then
        process80=`netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}'`
        red "==========================================================="
        red "检测到80端口被占用，占用进程为：${process80}，本次安装结束"
        red "==========================================================="
        exit 1
    fi

    if [ -n "$osPort443" ]; then
        process443=`netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}'`
        red "============================================================="
        red "检测到443端口被占用，占用进程为：${process443}，本次安装结束"
        red "============================================================="
        exit 1
    fi

    if [ "$osRelease" == "centos" ]; then
        if  [[ ${osReleaseVersionNo} == "6" || ${osReleaseVersionNo} == "5" ]]; then
            green " =================================================="
            red " 本脚本不支持 Centos 6 或 Centos 6 更早的版本"
            green " =================================================="
            exit
        fi

        red " 关闭防火墙 firewalld"
        ${sudoCmd} systemctl stop firewalld
        ${sudoCmd} systemctl disable firewalld

    elif [ "$osRelease" == "ubuntu" ]; then
        if  [[ ${osReleaseVersionNo} == "14" || ${osReleaseVersionNo} == "12" ]]; then
            green " =================================================="
            red " 本脚本不支持 Ubuntu 14 或 Ubuntu 14 更早的版本"
            green " =================================================="
            exit
        fi

        red " 关闭防火墙 ufw"
        ${sudoCmd} systemctl stop ufw
        ${sudoCmd} systemctl disable ufw
        
    elif [ "$osRelease" == "debian" ]; then
        $osSystemPackage update -y
    fi

}










# 编辑 SSH 公钥 文件用于 免密码登录
function editLinuxLoginWithPublicKey(){
    if [ ! -d "${HOME}/ssh" ]; then
        mkdir -p ${HOME}/.ssh
    fi

    vi ${HOME}/.ssh/authorized_keys
}



# 设置SSH root 登录

function setLinuxRootLogin(){

    read -p "是否设置允许root登陆(ssh密钥方式 或 密码方式登陆 )? 请输入[Y/n]:" osIsRootLoginInput
    osIsRootLoginInput=${osIsRootLoginInput:-Y}

    if [[ $osIsRootLoginInput == [Yy] ]]; then

        if [ "$osRelease" == "centos" ] || [ "$osRelease" == "debian" ] ; then
            ${sudoCmd} sed -i 's/#\?PermitRootLogin \(yes\|no\|Yes\|No\|prohibit-password\)/PermitRootLogin yes/g' /etc/ssh/sshd_config
        fi
        if [ "$osRelease" == "ubuntu" ]; then
            ${sudoCmd} sed -i 's/#\?PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
        fi

        green "设置允许root登陆成功!"
    fi


    read -p "是否设置允许root使用密码登陆(上一步请先设置允许root登陆才可以)? 请输入[Y/n]:" osIsRootLoginWithPasswordInput
    osIsRootLoginWithPasswordInput=${osIsRootLoginWithPasswordInput:-Y}

    if [[ $osIsRootLoginWithPasswordInput == [Yy] ]]; then
        sed -i 's/#\?PasswordAuthentication \(yes\|no\)/PasswordAuthentication yes/g' /etc/ssh/sshd_config
        green "设置允许root使用密码登陆成功!"
    fi


    ${sudoCmd} sed -i 's/#\?TCPKeepAlive yes/TCPKeepAlive yes/g' /etc/ssh/sshd_config
    ${sudoCmd} sed -i 's/#\?ClientAliveCountMax 3/ClientAliveCountMax 30/g' /etc/ssh/sshd_config
    ${sudoCmd} sed -i 's/#\?ClientAliveInterval [0-9]*/ClientAliveInterval 40/g' /etc/ssh/sshd_config

    if [ "$osRelease" == "centos" ] ; then

        ${sudoCmd} service sshd restart
        ${sudoCmd} systemctl restart sshd

        green "设置成功, 请用shell工具软件登陆vps服务器!"
    fi

    if [ "$osRelease" == "ubuntu" ] || [ "$osRelease" == "debian" ] ; then
        
        ${sudoCmd} service ssh restart
        ${sudoCmd} systemctl restart ssh

        green "设置成功, 请用shell工具软件登陆vps服务器!"
    fi

    # /etc/init.d/ssh restart

}


# 修改SSH 端口号
function changeLinuxSSHPort(){
    green " 修改的SSH登陆的端口号, 不要使用常用的端口号. 例如 20|21|23|25|53|69|80|110|443|123!"
    read -p "请输入要修改的端口号(必须是纯数字并且在1024~65535之间或22):" osSSHLoginPortInput
    osSSHLoginPortInput=${osSSHLoginPortInput:-0}

    if [ $osSSHLoginPortInput -eq 22 -o $osSSHLoginPortInput -gt 1024 -a $osSSHLoginPortInput -lt 65535 ]; then
        sed -i "s/#\?Port [0-9]*/Port $osSSHLoginPortInput/g" /etc/ssh/sshd_config

        if [ "$osRelease" == "centos" ] ; then

            if  [[ ${osReleaseVersionNo} == "7" ]]; then
                yum -y install policycoreutils-python
            elif  [[ ${osReleaseVersionNo} == "8" ]]; then
                yum -y install policycoreutils-python-utils
            fi

            # semanage port -l
            semanage port -a -t ssh_port_t -p tcp $osSSHLoginPortInput
            firewall-cmd --permanent --zone=public --add-port=$osSSHLoginPortInput/tcp 
            firewall-cmd --reload
    
            ${sudoCmd} systemctl restart sshd.service

        fi

        if [ "$osRelease" == "ubuntu" ] || [ "$osRelease" == "debian" ] ; then
            semanage port -a -t ssh_port_t -p tcp $osSSHLoginPortInput
            sudo ufw allow $osSSHLoginPortInput/tcp

            ${sudoCmd} service ssh restart
            ${sudoCmd} systemctl restart ssh
        fi

        green "设置成功, 请记住设置的端口号 ${osSSHLoginPortInput}!"
        green "登陆服务器命令: ssh -p ${osSSHLoginPortInput} root@111.111.111.your ip !"
    else
        echo "输入的端口号错误! 范围: 22,1025~65534"
    fi
}

function setLinuxDateZone(){

    tempCurrentDateZone=$(date +'%z')

    echo
    if [[ ${tempCurrentDateZone} == "+0800" ]]; then
        yellow "当前时区已经为北京时间  $tempCurrentDateZone | $(date -R) "
    else 
        green " =================================================="
        yellow " 当前时区为: $tempCurrentDateZone | $(date -R) "
        yellow " 是否设置时区为北京时间 +0800区, 以便cron定时重启脚本按照北京时间运行."
        green " =================================================="
        # read 默认值 https://stackoverflow.com/questions/2642585/read-a-variable-in-bash-with-a-default-value

        if [[ -f /etc/localtime ]] && [[ -f /usr/share/zoneinfo/Asia/Shanghai ]];  then
              mv /etc/localtime /etc/localtime.bak
              cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

              yellow "设置成功! 当前时区已设置为 $(date -R)"
              green " =================================================="
        fi

    fi
    echo
}




# 更新本脚本
function upgradeScript(){
    wget -Nq --no-check-certificate -O ./trojan_v2ray_install.sh "https://raw.githubusercontent.com/jinwyp/one_click_script/master/trojan_v2ray_install.sh"
    green " 本脚本升级成功! "
    chmod +x ./trojan_v2ray_install.sh
    sleep 2s
    exec "./trojan_v2ray_install.sh"
}



# 软件安装

function installSoftDownload(){
	if [[ "${osRelease}" == "debian" || "${osRelease}" == "ubuntu" ]]; then
		if ! dpkg -l | grep -qw wget; then
			${osSystemPackage} -y install wget curl git
			
			# https://stackoverflow.com/questions/11116704/check-if-vt-x-is-activated-without-having-to-reboot-in-linux
			${osSystemPackage} -y install cpu-checker
		fi

	elif [[ "${osRelease}" == "centos" ]]; then
		if ! rpm -qa | grep -qw wget; then
			${osSystemPackage} -y install wget curl git
		fi
	fi 
}

function installPackage(){
    if [ "$osRelease" == "centos" ]; then
       
        # rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm

        cat > "/etc/yum.repos.d/nginx.repo" <<-EOF
[nginx]
name=nginx repo
baseurl=https://nginx.org/packages/centos/$osReleaseVersionNo/\$basearch/
gpgcheck=0
enabled=1

EOF
        if ! rpm -qa | grep -qw iperf3; then
			${sudoCmd} ${osSystemPackage} install -y epel-release

            ${osSystemPackage} install -y curl wget git unzip zip tar
            ${osSystemPackage} install -y xz jq redhat-lsb-core 
            ${osSystemPackage} install -y iputils
            ${osSystemPackage} install -y iperf3
		fi

        ${osSystemPackage} update -y


        # https://www.cyberciti.biz/faq/how-to-install-and-use-nginx-on-centos-8/
        if  [[ ${osReleaseVersionNo} == "8" ]]; then
            ${sudoCmd} yum module -y reset nginx
            ${sudoCmd} yum module -y enable nginx:1.18
            ${sudoCmd} yum module list nginx
        fi

    elif [ "$osRelease" == "ubuntu" ]; then
        
        # https://joshtronic.com/2018/12/17/how-to-install-the-latest-nginx-on-debian-and-ubuntu/
        # https://www.nginx.com/resources/wiki/start/topics/tutorials/install/
        
        $osSystemPackage install -y gnupg2
        wget -O - https://nginx.org/keys/nginx_signing.key | ${sudoCmd} apt-key add -

        cat > "/etc/apt/sources.list.d/nginx.list" <<-EOF
deb https://nginx.org/packages/ubuntu/ $osReleaseVersionCodeName nginx
deb-src https://nginx.org/packages/ubuntu/ $osReleaseVersionCodeName nginx
EOF

        ${osSystemPackage} update -y

        if ! dpkg -l | grep -qw iperf3; then
            ${sudoCmd} ${osSystemPackage} install -y software-properties-common
            ${osSystemPackage} install -y curl wget git unzip zip tar
            ${osSystemPackage} install -y xz-utils jq lsb-core lsb-release
            ${osSystemPackage} install -y iputils-ping
            ${osSystemPackage} install -y iperf3
		fi    

    elif [ "$osRelease" == "debian" ]; then
        # ${sudoCmd} add-apt-repository ppa:nginx/stable -y

        ${osSystemPackage} install -y gnupg2
        wget -O - https://nginx.org/keys/nginx_signing.key | ${sudoCmd} apt-key add -
        # curl -L https://nginx.org/keys/nginx_signing.key | ${sudoCmd} apt-key add -

        cat > "/etc/apt/sources.list.d/nginx.list" <<-EOF 
deb http://nginx.org/packages/debian/ $osReleaseVersionCodeName nginx
deb-src http://nginx.org/packages/debian/ $osReleaseVersionCodeName nginx
EOF
        
        ${osSystemPackage} update -y

        if ! dpkg -l | grep -qw iperf3; then
            ${osSystemPackage} install -y curl wget git unzip zip tar
            ${osSystemPackage} install -y xz-utils jq lsb-core lsb-release
            ${osSystemPackage} install -y iputils-ping
            ${osSystemPackage} install -y iperf3
        fi        
    fi
}


function installSoftEditor(){
    # 安装 micro 编辑器
    if [[ ! -f "${HOME}/bin/micro" ]] ;  then
        mkdir -p ${HOME}/bin
        cd ${HOME}/bin
        curl https://getmic.ro | bash

        cp ${HOME}/bin/micro /usr/local/bin

        green " =================================================="
        green " micro 编辑器 安装成功!"
        green " =================================================="
    fi

    if [ "$osRelease" == "centos" ]; then   
        $osSystemPackage install -y xz  vim-minimal vim-enhanced vim-common
    else
        $osSystemPackage install -y vim-gui-common vim-runtime vim 
    fi

    # 设置vim 中文乱码
    if [[ ! -d "${HOME}/.vimrc" ]] ;  then
        cat > "${HOME}/.vimrc" <<-EOF
set fileencodings=utf-8,gb2312,gb18030,gbk,ucs-bom,cp936,latin1
set enc=utf8
set fencs=utf8,gbk,gb2312,gb18030

syntax on
colorscheme elflord

if has('mouse')
  se mouse+=a
  set number
endif

EOF
    fi
}

function installSoftOhMyZsh(){

    echo
    green " =================================================="
    yellow "   准备安装 ZSH"
    green " =================================================="
    echo

    if [ "$osRelease" == "centos" ]; then

        ${sudoCmd} $osSystemPackage install zsh -y
        $osSystemPackage install util-linux-user -y

    elif [ "$osRelease" == "ubuntu" ]; then

        ${sudoCmd} $osSystemPackage install zsh -y

    elif [ "$osRelease" == "debian" ]; then

        ${sudoCmd} $osSystemPackage install zsh -y
    fi

    green " =================================================="
    green " ZSH 安装成功"
    green " =================================================="

    # 安装 oh-my-zsh
    if [[ ! -d "${HOME}/.oh-my-zsh" ]] ;  then

        green " =================================================="
        yellow " 准备安装 oh-my-zsh"
        green " =================================================="
        curl -Lo ${HOME}/ohmyzsh_install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
        chmod +x ${HOME}/ohmyzsh_install.sh
        sh ${HOME}/ohmyzsh_install.sh --unattended
    fi

    if [[ ! -d "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]] ;  then
        git clone "https://github.com/zsh-users/zsh-autosuggestions" "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions"

        # 配置 zshrc 文件
        zshConfig=${HOME}/.zshrc
        zshTheme="maran"
        sed -i 's/ZSH_THEME=.*/ZSH_THEME="'"${zshTheme}"'"/' $zshConfig
        sed -i 's/plugins=(git)/plugins=(git cp history z rsync colorize nvm zsh-autosuggestions)/' $zshConfig

        zshAutosuggestionsConfig=${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
        sed -i "s/ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'/ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=1'/" $zshAutosuggestionsConfig


        # Actually change the default shell to zsh
        zsh=$(which zsh)

        if ! chsh -s "$zsh"; then
            error "chsh command unsuccessful. Change your default shell manually."
        else
            export SHELL="$zsh"
            green "===== Shell successfully changed to '$zsh'."
        fi


        echo 'alias lla="ls -ahl"' >> ${HOME}/.zshrc
        echo 'alias mi="micro"' >> ${HOME}/.zshrc

        green " =================================================="
        yellow " oh-my-zsh 安装成功, 请用exit命令退出服务器后重新登陆即可!"
        green " =================================================="

    fi

}



# 网络测速

function vps_netflix(){
    # bash <(curl -sSL https://raw.githubusercontent.com/Netflixxp/NF/main/nf.sh)
    # bash <(curl -sSL "https://github.com/CoiaPrant/Netflix_Unlock_Information/raw/main/netflix.sh")
	# wget -N --no-check-certificate https://github.com/CoiaPrant/Netflix_Unlock_Information/raw/main/netflix.sh && chmod +x netflix.sh && ./netflix.sh

	wget -N --no-check-certificate -O ./netflix.sh https://github.com/CoiaPrant/MediaUnlock_Test/raw/main/check.sh && chmod +x ./netflix.sh && ./netflix.sh

    # wget -N -O nf https://github.com/sjlleo/netflix-verify/releases/download/2.01/nf_2.01_linux_amd64 && chmod +x nf && clear && ./nf
}


function vps_superspeed(){
	bash <(curl -Lso- https://git.io/superspeed)
	#wget -N --no-check-certificate https://raw.githubusercontent.com/ernisn/superspeed/master/superspeed.sh && chmod +x superspeed.sh && ./superspeed.sh
}

function vps_bench(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/teddysun/across/master/bench.sh && chmod +x bench.sh && bash bench.sh
}

function vps_zbench(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/FunctionClub/ZBench/master/ZBench-CN.sh && chmod +x ZBench-CN.sh && bash ZBench-CN.sh
}

function vps_testrace(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/nanqinlang-script/testrace/master/testrace.sh && chmod +x testrace.sh && ./testrace.sh
}

function vps_LemonBench(){
    wget -O LemonBench.sh -N --no-check-certificate https://ilemonra.in/LemonBenchIntl && chmod +x LemonBench.sh && ./LemonBench.sh fast
}




function installBBR(){
    wget -O tcp_old.sh -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp_old.sh && ./tcp_old.sh
}

function installBBR2(){
    
    if [[ -f ./tcp.sh ]];  then
        mv ./tcp.sh ./tcp_old.sh
    fi    
    wget -N --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}



function installWireguard(){
    bash <(wget -qO- https://github.com/chenshuo-as/one_click_script/raw/master/install_kernel.sh)
    # wget -N --no-check-certificate https://github.com/jinwyp/one_click_script/raw/master/install_kernel.sh && chmod +x ./install_kernel.sh && ./install_kernel.sh
}


function installBTPanel(){
    if [ "$osRelease" == "centos" ]; then
        yum install -y wget && wget -O install.sh http://download.bt.cn/install/install_6.0.sh && sh install.sh
    else
        curl -sSO http://download.bt.cn/install/install_panel.sh && bash install_panel.sh

    fi
}

function installBTPanelCrack(){
    if [ "$osRelease" == "centos" ]; then
        yum install -y wget && wget -O install.sh https://download.fenhao.me/install/install_6.0.sh && sh install.sh
    else
        curl -sSO https://download.fenhao.me/install/install_panel.sh && bash install_panel.sh
    fi
}

function installBTPanelCrack2(){
    if [ "$osRelease" == "centos" ]; then
        yum install -y wget && wget -O install.sh http://download.hostcli.com/install/install_6.0.sh && sh install.sh
    else
        exit
    fi
}









































configNetworkRealIp=""
configNetworkLocalIp=""
configSSLDomain=""

configSSLAcmeScriptPath="${HOME}/.acme.sh"
configWebsiteFatherPath="${HOME}/website"
configSSLCertBakPath="${HOME}/sslbackup"
configSSLCertPath="${HOME}/website/cert"
configSSLCertKeyFilename="private.key"
configSSLCertFullchainFilename="fullchain.cer"
configWebsitePath="${HOME}/website/html"
configTrojanWindowsCliPrefixPath=$(cat /dev/urandom | head -1 | md5sum | head -c 20)
configWebsiteDownloadPath="${configWebsitePath}/download/${configTrojanWindowsCliPrefixPath}"
configDownloadTempPath="${HOME}/temp"

configRanPath="${HOME}/ran"


versionTrojan="1.16.0"
downloadFilenameTrojan="trojan-${versionTrojan}-linux-amd64.tar.xz"

versionTrojanGo="0.8.2"
downloadFilenameTrojanGo="trojan-go-linux-amd64.zip"

versionV2ray="4.33.0"
downloadFilenameV2ray="v2ray-linux-64.zip"

versionXray="1.1.1"
downloadFilenameXray="Xray-linux-64.zip"

versionTrojanWeb="2.8.7"
downloadFilenameTrojanWeb="trojan"

promptInfoTrojanName=""
isTrojanGo="no"
isTrojanGoSupportWebsocket="false"
configTrojanGoWebSocketPath=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
configTrojanPasswordPrefixInput="jin"

configTrojanPath="${HOME}/trojan"
configTrojanGoPath="${HOME}/trojan-go"
configTrojanWebPath="${HOME}/trojan-web"
configTrojanLogFile="${HOME}/trojan-access.log"
configTrojanGoLogFile="${HOME}/trojan-go-access.log"

configTrojanBasePath=${configTrojanPath}
configTrojanBaseVersion=${versionTrojan}

configTrojanWebNginxPath=$(cat /dev/urandom | head -1 | md5sum | head -c 5)
configTrojanWebPort="$(($RANDOM + 10000))"


isInstallNginx="true"
isNginxWithSSL="no"
nginxConfigPath="/etc/nginx/nginx.conf"
nginxAccessLogFilePath="${HOME}/nginx-access.log"
nginxErrorLogFilePath="${HOME}/nginx-error.log"

promptInfoXrayInstall="V2ray"
promptInfoXrayVersion=""
promptInfoXrayName="v2ray"
isXray="no"

configV2rayWebSocketPath=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
configV2rayGRPCServiceName=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
configV2rayPort="$(($RANDOM + 10000))"
configV2rayGRPCPort="$(($RANDOM + 10000))"
configV2rayVmesWSPort="$(($RANDOM + 10000))"
configV2rayVmessTCPPort="$(($RANDOM + 10000))"
configV2rayPortShowInfo=$configV2rayPort
configV2rayPortGRPCShowInfo=$configV2rayGRPCPort
configV2rayIsTlsShowInfo="tls"
configV2rayTrojanPort="$(($RANDOM + 10000))"

configV2rayPath="${HOME}/v2ray"
configV2rayAccessLogFilePath="${HOME}/v2ray-access.log"
configV2rayErrorLogFilePath="${HOME}/v2ray-error.log"
configV2rayProtocol="vmess"
configV2rayVlessMode=""
configV2rayWSorGrpc="ws"


configReadme=${HOME}/readme_trojan_v2ray.txt


function downloadAndUnzip(){
    if [ -z $1 ]; then
        green " ================================================== "
        green "     下载文件地址为空!"
        green " ================================================== "
        exit
    fi
    if [ -z $2 ]; then
        green " ================================================== "
        green "     目标路径地址为空!"
        green " ================================================== "
        exit
    fi
    if [ -z $3 ]; then
        green " ================================================== "
        green "     下载文件的文件名为空!"
        green " ================================================== "
        exit
    fi

    mkdir -p ${configDownloadTempPath}

    if [[ $3 == *"tar.xz"* ]]; then
        green "===== 下载并解压tar文件: $3 "
        wget -O ${configDownloadTempPath}/$3 $1
        tar xf ${configDownloadTempPath}/$3 -C ${configDownloadTempPath}
        mv ${configDownloadTempPath}/trojan/* $2
        rm -rf ${configDownloadTempPath}/trojan
    else
        green "===== 下载并解压zip文件:  $3 "
        wget -O ${configDownloadTempPath}/$3 $1
        unzip -d $2 ${configDownloadTempPath}/$3
    fi

}

function getGithubLatestReleaseVersion(){
    # https://github.com/p4gefau1t/trojan-go/issues/63
    wget --no-check-certificate -qO- https://api.github.com/repos/$1/tags | grep 'name' | cut -d\" -f4 | head -1 | cut -b 2-
}

function getTrojanAndV2rayVersion(){
    # https://github.com/trojan-gfw/trojan/releases/download/v1.16.0/trojan-1.16.0-linux-amd64.tar.xz
    # https://github.com/p4gefau1t/trojan-go/releases/download/v0.8.1/trojan-go-linux-amd64.zip

    echo ""

    if [[ $1 == "trojan" ]] ; then
        versionTrojan=$(getGithubLatestReleaseVersion "trojan-gfw/trojan")
        downloadFilenameTrojan="trojan-${versionTrojan}-linux-amd64.tar.xz"
        echo "versionTrojan: ${versionTrojan}"
    fi

    if [[ $1 == "trojan-go" ]] ; then
        versionTrojanGo=$(getGithubLatestReleaseVersion "p4gefau1t/trojan-go")
        downloadFilenameTrojanGo="trojan-go-linux-amd64.zip"
        echo "versionTrojanGo: ${versionTrojanGo}"
    fi

    if [[ $1 == "v2ray" ]] ; then
        versionV2ray=$(getGithubLatestReleaseVersion "v2fly/v2ray-core")
        echo "versionV2ray: ${versionV2ray}"
    fi

    if [[ $1 == "xray" ]] ; then
        versionXray=$(getGithubLatestReleaseVersion "XTLS/Xray-core")
        echo "versionXray: ${versionXray}"
    fi

    if [[ $1 == "trojan-web" ]] ; then
        versionTrojanWeb=$(getGithubLatestReleaseVersion "Jrohy/trojan")
        downloadFilenameTrojanWeb="trojan"
        echo "versionTrojanWeb: ${versionTrojanWeb}"
    fi

    if [[ $1 == "wgcf" ]] ; then
        versionWgcf=$(getGithubLatestReleaseVersion "ViRb3/wgcf")
        downloadFilenameWgcf="wgcf_${versionWgcf}_linux_amd64"
        echo "versionWgcf: ${versionWgcf}"
    fi

}

function stopServiceNginx(){
    serviceNginxStatus=`ps -aux | grep "nginx: worker" | grep -v "grep"`
    if [[ -n "$serviceNginxStatus" ]]; then
        ${sudoCmd} systemctl stop nginx.service
    fi
}

function stopServiceV2ray(){
    if [[ -f "${osSystemMdPath}v2ray.service" ]] || [[ -f "/etc/systemd/system/v2ray.service" ]] || [[ -f "/lib/systemd/system/v2ray.service" ]] ; then
        ${sudoCmd} systemctl stop v2ray.service
    fi
}

function isTrojanGoInstall(){
    if [ "$isTrojanGo" = "yes" ] ; then
        getTrojanAndV2rayVersion "trojan-go"
        configTrojanBaseVersion=${versionTrojanGo}
        configTrojanBasePath="${configTrojanGoPath}"
        promptInfoTrojanName="-go"
    else
        getTrojanAndV2rayVersion "trojan"
        configTrojanBaseVersion=${versionTrojan}
        configTrojanBasePath="${configTrojanPath}"
        promptInfoTrojanName=""
    fi
}


function compareRealIpWithLocalIp(){
    echo
    echo
    green " 是否检测域名指向的IP正确 (默认检测，如果域名指向的IP不是本机器IP则无法继续. 如果已开启CDN不方便关闭可以选择否)"
    read -p "是否检测域名指向的IP正确? 请输入[Y/n]:" isDomainValidInput
    isDomainValidInput=${isDomainValidInput:-Y}

    if [[ $isDomainValidInput == [Yy] ]]; then
        if [ -n $1 ]; then
            configNetworkRealIp=`ping $1 -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
            # configNetworkLocalIp=`curl ipv4.icanhazip.com`
            configNetworkLocalIp=`curl v4.ident.me`

            green " ================================================== "
            green "     域名解析地址为 ${configNetworkRealIp}, 本VPS的IP为 ${configNetworkLocalIp}. "
            green " ================================================== "

            if [[ ${configNetworkRealIp} == ${configNetworkLocalIp} ]] ; then
                green " ================================================== "
                green "     域名解析的IP正常!"
                green " ================================================== "
                true
            else
                green " ================================================== "
                red "     域名解析地址与本VPS IP地址不一致!"
                red "     本次安装失败，请确保域名解析正常, 请检查域名和DNS是否生效!"
                green " ================================================== "
                false
            fi
        else
            green " ================================================== "        
            red "     域名输入错误!"
            green " ================================================== "        
            false
        fi
        
    else
        green " ================================================== "
        green "     不检测域名解析是否正确!"
        green " ================================================== "
        true
    fi
}

function getHTTPSCertificate(){

    # 申请https证书
	mkdir -p ${configSSLCertPath}
	mkdir -p ${configWebsitePath}
	curl https://get.acme.sh | sh

    green " ================================================== "

	if [[ $1 == "standalone" ]] ; then
	    green "  开始申请证书, acme.sh 通过 standalone mode 申请 "
        echo

	    ${configSSLAcmeScriptPath}/acme.sh --issue --standalone -d ${configSSLDomain}  --keylength ec-256
        echo

        ${configSSLAcmeScriptPath}/acme.sh --installcert --ecc -d ${configSSLDomain} \
        --key-file ${configSSLCertPath}/$configSSLCertKeyFilename \
        --fullchain-file ${configSSLCertPath}/$configSSLCertFullchainFilename \
        --reloadcmd "systemctl restart nginx.service"

	else
        # https://github.com/m3ng9i/ran/issues/10

        mkdir -p ${configRanPath}
        
        if [[ -f "${configRanPath}/ran_linux_amd64" ]]; then
            echo
        else

            downloadAndUnzip "https://github.com/m3ng9i/ran/releases/download/v0.1.5/ran_linux_amd64.zip" "${configRanPath}" "ran_linux_amd64.zip" 
            chmod +x ${configRanPath}/ran_linux_amd64
            
        fi    

        echo
        echo "nohup ${configRanPath}/ran_linux_amd64 -l=false -g=false -sa=true -p=80 -r=${configWebsitePath} >/dev/null 2>&1 &"
        nohup ${configRanPath}/ran_linux_amd64 -l=false -g=false -sa=true -p=80 -r=${configWebsitePath} >/dev/null 2>&1 &
        echo
	    green "  开始申请证书, acme.sh 通过 webroot mode 申请 "
        echo
        echo
        green "默认通过Letsencrypt.org来申请证书, 如果证书申请失败, 例如一天内通过Letsencrypt.org申请次数过多, 可以选否通过BuyPass.com来申请."
        read -p "是否通过Letsencrypt.org来申请证书? 默认直接回车为是, 选否则通过BuyPass.com来申请, 请输入[Y/n]:" isDomainSSLFromLetInput
        isDomainSSLFromLetInput=${isDomainSSLFromLetInput:-Y}

        echo
        if [[ $isDomainSSLFromLetInput == [Yy] ]]; then
            ${configSSLAcmeScriptPath}/acme.sh --issue -d ${configSSLDomain} --webroot ${configWebsitePath} --keylength ec-256
            
        else
            read -p "请输入邮箱地址, 用于BuyPass.com申请证书:" isDomainSSLFromBuyPassEmailInput
            isDomainSSLFromBuyPassEmailInput=${isDomainSSLFromBuyPassEmailInput:-test@gmail.com}

            echo
            ${configSSLAcmeScriptPath}/acme.sh --server https://api.buypass.com/acme/directory --register-account  --accountemail ${isDomainSSLFromBuyPassEmailInput}
            
            echo
            ${configSSLAcmeScriptPath}/acme.sh --server https://api.buypass.com/acme/directory --days 170 --issue -d ${configSSLDomain} --webroot ${configWebsitePath}  --keylength ec-256
         
        fi
        
        echo
        ${configSSLAcmeScriptPath}/acme.sh --installcert --ecc -d ${configSSLDomain} \
        --key-file ${configSSLCertPath}/$configSSLCertKeyFilename \
        --fullchain-file ${configSSLCertPath}/$configSSLCertFullchainFilename \
        --reloadcmd "systemctl restart nginx.service"

        sleep 4
        ps -C ran_linux_amd64 -o pid= | xargs -I {} kill {}
    fi

    green " ================================================== "
}



function installWebServerNginx(){

    green " ================================================== "
    yellow "     开始安装 Web服务器 nginx !"
    green " ================================================== "

    if test -s ${nginxConfigPath}; then
        green " ================================================== "
        red "     Nginx 已存在, 退出安装!"
        green " ================================================== "
        exit
    fi

    stopServiceV2ray
    
    ${osSystemPackage} install nginx -y
    ${sudoCmd} systemctl enable nginx.service
    ${sudoCmd} systemctl stop nginx.service

    if [[ -z $1 ]] ; then
        cat > "${nginxConfigPath}" <<-EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] '
                      '"\$request" \$status \$body_bytes_sent  '
                      '"\$http_referer" "\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  $nginxAccessLogFilePath  main;
    error_log $nginxErrorLogFilePath;

    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    gzip  on;

    server {
        listen       80;
        server_name  $configSSLDomain;
        root $configWebsitePath;
        index index.php index.html index.htm;

        location /$configV2rayWebSocketPath {
            proxy_pass http://127.0.0.1:$configV2rayPort;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;

            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }
}
EOF

    elif [[ $1 == "trojan-web" ]] ; then

        cat > "${nginxConfigPath}" <<-EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] '
                      '"\$request" \$status \$body_bytes_sent  '
                      '"\$http_referer" "\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  $nginxAccessLogFilePath  main;
    error_log $nginxErrorLogFilePath;

    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip on;

    server {
        listen       80;
        server_name  $configSSLDomain;
        root $configWebsitePath;
        index index.php index.html index.htm;

        location /$configTrojanWebNginxPath {
            proxy_pass http://127.0.0.1:$configTrojanWebPort/;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Host \$http_host;
        }

        location ~* ^/(static|common|auth|trojan)/ {
            proxy_pass  http://127.0.0.1:$configTrojanWebPort;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;
        }

        # http redirect to https
        if ( \$remote_addr != 127.0.0.1 ){
            rewrite ^/(.*)$ https://$configSSLDomain/\$1 redirect;
        }
    }
}
EOF
    else
        cat > "${nginxConfigPath}" <<-EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] '
                      '"\$request" \$status \$body_bytes_sent  '
                      '"\$http_referer" "\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  $nginxAccessLogFilePath  main;
    error_log $nginxErrorLogFilePath;

    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    gzip  on;

    server {
        listen 443 ssl http2;
        listen [::]:443 http2;
        server_name  $configSSLDomain;

        ssl_certificate       ${configSSLCertPath}/$configSSLCertFullchainFilename;
        ssl_certificate_key   ${configSSLCertPath}/$configSSLCertKeyFilename;
        ssl_protocols         TLSv1.2 TLSv1.3;
        ssl_ciphers           TLS-AES-256-GCM-SHA384:TLS-CHACHA20-POLY1305-SHA256:TLS-AES-128-GCM-SHA256:TLS-AES-128-CCM-8-SHA256:TLS-AES-128-CCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256;

        # Config for 0-RTT in TLSv1.3
        ssl_early_data on;
        ssl_stapling on;
        ssl_stapling_verify on;
        add_header Strict-Transport-Security "max-age=31536000";
        
        root $configWebsitePath;
        index index.php index.html index.htm;

        location /$configV2rayWebSocketPath {
            proxy_pass http://127.0.0.1:$configV2rayPort;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }

        location /$configV2rayGRPCServiceName {
            grpc_pass grpc://127.0.0.1:$configV2rayGRPCPort;
            grpc_connect_timeout 60s;
            grpc_read_timeout 720m;
            grpc_send_timeout 720m;
            grpc_set_header X-Real-IP \$remote_addr;
            grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }

    server {
        listen 80;
        listen [::]:80;
        server_name  $configSSLDomain;
        return 301 https://$configSSLDomain\$request_uri;
    }
}
EOF
    fi



    # 下载伪装站点 并设置伪装网站
    rm -rf ${configWebsitePath}/*
    mkdir -p ${configWebsiteDownloadPath}

    downloadAndUnzip "https://github.com/jinwyp/one_click_script/raw/master/download/website.zip" "${configWebsitePath}" "website.zip"

    wget -P "${configWebsiteDownloadPath}" "https://github.com/jinwyp/one_click_script/raw/master/download/trojan-mac.zip"
    wget -P "${configWebsiteDownloadPath}" "https://github.com/jinwyp/one_click_script/raw/master/download/v2ray-windows.zip" 
    wget -P "${configWebsiteDownloadPath}" "https://github.com/jinwyp/one_click_script/raw/master/download/v2ray-mac.zip"

    # downloadAndUnzip "https://github.com/jinwyp/one_click_script/raw/master/download/trojan_client_all.zip" "${configWebsiteDownloadPath}" "trojan_client_all.zip"
    # downloadAndUnzip "https://github.com/jinwyp/one_click_script/raw/master/download/trojan-qt5.zip" "${configWebsiteDownloadPath}" "trojan-qt5.zip"
    # downloadAndUnzip "https://github.com/jinwyp/one_click_script/raw/master/download/v2ray_client_all.zip" "${configWebsiteDownloadPath}" "v2ray_client_all.zip"

    #wget -P "${configWebsiteDownloadPath}" "https://github.com/jinwyp/one_click_script/raw/master/download/v2ray-android.zip"

    ${sudoCmd} systemctl start nginx.service

    green " ================================================== "
    green "       Web服务器 nginx 安装成功!!"
    green "    伪装站点为 http://${configSSLDomain}"

	if [[ $1 == "trojan-web" ]] ; then
	    yellow "    Trojan-web ${versionTrojanWeb} 可视化管理面板地址  http://${configSSLDomain}/${configTrojanWebNginxPath} "
	    green "    Trojan-web 可视化管理面板 可执行文件路径 ${configTrojanWebPath}/trojan-web"
	    green "    Trojan 服务器端可执行文件路径 /usr/bin/trojan/trojan"
	    green "    Trojan 服务器端配置路径 /usr/local/etc/trojan/config.json "
	    green "    Trojan-web 停止命令: systemctl stop trojan-web.service  启动命令: systemctl start trojan-web.service  重启命令: systemctl restart trojan-web.service"
	    green "    Trojan 停止命令: systemctl stop trojan.service  启动命令: systemctl start trojan.service  重启命令: systemctl restart trojan.service"
	fi

    green "    伪装站点的静态html内容放置在目录 ${configWebsitePath}, 可自行更换网站内容!"
	red "    nginx 配置路径 ${nginxConfigPath} "
	green "    nginx 访问日志 ${nginxAccessLogFilePath} "
	green "    nginx 错误日志 ${nginxErrorLogFilePath} "
    green "    nginx 查看日志命令: journalctl -n 50 -u nginx.service"
	green "    nginx 启动命令: systemctl start nginx.service  停止命令: systemctl stop nginx.service  重启命令: systemctl restart nginx.service"
	green "    nginx 查看运行状态命令: systemctl status nginx.service "

    green " ================================================== "

    cat >> ${configReadme} <<-EOF

Web服务器 nginx 安装成功! 伪装站点为 ${configSSLDomain}   
伪装站点的静态html内容放置在目录 ${configWebsitePath}, 可自行更换网站内容.
nginx 配置路径 ${nginxConfigPath}
nginx 访问日志 ${nginxAccessLogFilePath}
nginx 错误日志 ${nginxErrorLogFilePath}

nginx 查看日志命令: journalctl -n 50 -u nginx.service

nginx 启动命令: systemctl start nginx.service  
nginx 停止命令: systemctl stop nginx.service  
nginx 重启命令: systemctl restart nginx.service
nginx 查看运行状态命令: systemctl status nginx.service


EOF

	if [[ $1 == "trojan-web" ]] ; then
        cat >> ${configReadme} <<-EOF

安装的Trojan-web ${versionTrojanWeb} 可视化管理面板,访问地址  ${configSSLDomain}/${configTrojanWebNginxPath}
Trojan-web 停止命令: systemctl stop trojan-web.service  启动命令: systemctl start trojan-web.service  重启命令: systemctl restart trojan-web.service

EOF
	fi

}

function removeNginx(){

    ${sudoCmd} systemctl stop nginx.service

    echo
    green " ================================================== "
    red " 准备卸载已安装的nginx"
    green " ================================================== "
    echo

    if [ "$osRelease" == "centos" ]; then
        yum remove -y nginx
    else
        apt autoremove -y --purge nginx nginx-common nginx-core
        apt-get remove --purge nginx nginx-full nginx-common nginx-core
    fi


    rm -rf ${configSSLCertBakPath}
    mkdir -p ${configSSLCertBakPath}
    cp -f ${configSSLCertPath}/* ${configSSLCertBakPath}

    rm -rf ${configWebsiteFatherPath}
    rm -f ${nginxAccessLogFilePath}
    rm -f ${nginxErrorLogFilePath}

    rm -f ${configReadme}

    rm -rf "/etc/nginx"
    
    uninstall ${configSSLAcmeScriptPath}
    rm -rf ${configDownloadTempPath}

    read -p "是否删除证书 和 卸载acme.sh申请证书工具, 由于一天内申请证书有次数限制, 默认建议不删除证书,  请输入[y/N]:" isDomainSSLRemoveInput
    isDomainSSLRemoveInput=${isDomainSSLRemoveInput:-n}

    echo
    green " ================================================== "
    if [[ $isDomainSSLRemoveInput == [Yy] ]]; then
        ${sudoCmd} bash ${configSSLAcmeScriptPath}/acme.sh --uninstall
        green "  Nginx 卸载完毕, SSL 证书文件已删除!"
        
    else
        green "  Nginx 卸载完毕, 已保留 SSL 证书文件!"
    fi
    green " ================================================== "
    echo
}













function installTrojanV2rayWithNginx(){

    stopServiceNginx
    testLinuxPortUsage
    installPackage
    
    green " ================================================== "
    yellow " 请输入绑定到本VPS的域名 例如www.xxx.com: (此步骤请关闭CDN后安装)"
    if [[ $1 == "repair" ]] ; then
        blue " 务必与之前安装失败时使用的域名一致"
    fi
    green " ================================================== "

    read configSSLDomain

    echo
    echo

    green "是否申请证书? 默认为自动申请证书, 如果二次安装或已有证书 可以选否"
    green "如果已经有SSL证书文件请放到下面路径"
    red " ${configSSLDomain} 域名证书内容文件路径 ${configSSLCertPath}/$configSSLCertFullchainFilename "
    red " ${configSSLDomain} 域名证书私钥文件路径 ${configSSLCertPath}/$configSSLCertKeyFilename "
    echo
    read -p "是否申请证书? 默认为自动申请证书,如果二次安装或已有证书可以选否 请输入[Y/n]:" isDomainSSLRequestInput
    isDomainSSLRequestInput=${isDomainSSLRequestInput:-Y}

    if compareRealIpWithLocalIp "${configSSLDomain}" ; then
        if [[ $isDomainSSLRequestInput == [Yy] ]]; then
            getHTTPSCertificate 
        else
            green " =================================================="
            green " 不申请域名的证书, 请把证书放到如下目录, 或自行修改trojan或v2ray配置!"
            green " ${configSSLDomain} 域名证书内容文件路径 ${configSSLCertPath}/$configSSLCertFullchainFilename "
            green " ${configSSLDomain} 域名证书私钥文件路径 ${configSSLCertPath}/$configSSLCertKeyFilename "
            green " =================================================="
        fi
    else
        exit
    fi


    if test -s ${configSSLCertPath}/$configSSLCertFullchainFilename; then
        green " ================================================== "
        green "     SSL证书 已检测到获取成功!"
        green " ================================================== "

        if [ "$isNginxWithSSL" = "no" ] ; then
            installWebServerNginx
        else
            installWebServerNginx "v2ray"
        fi

        if [ -z $1 ]; then
            installTrojanServer
        elif [ $1 = "both" ]; then
            installTrojanServer
            installV2ray
        else
            installV2ray
        fi
    else
        red " ================================================== "
        red " https证书没有申请成功，安装失败!"
        red " 请检查域名和DNS是否生效, 同一域名请不要一天内多次申请!"
        red " 请检查80和443端口是否开启, VPS服务商可能需要添加额外防火墙规则，例如阿里云、谷歌云等!"
        red " 重启VPS, 重新执行脚本, 可重新选择该项再次申请证书 ! "
        red " ================================================== "
        exit
    fi    
}























function installTrojanServer(){

    trojanPassword1=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword2=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword3=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword4=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword5=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword6=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword7=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword8=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword9=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword10=$(cat /dev/urandom | head -1 | md5sum | head -c 10)

    isTrojanGoInstall

    if [[ -f "${configTrojanBasePath}/trojan${promptInfoTrojanName}" ]]; then
        green " =================================================="
        green "  已安装过 Trojan${promptInfoTrojanName} , 退出安装 !"
        green " =================================================="
        exit
    fi


    green " =================================================="
    green " 开始安装 Trojan${promptInfoTrojanName} Version: ${configTrojanBaseVersion} !"
    yellow " 请输入trojan密码的前缀? (会生成若干随机密码和带有该前缀的密码)"
    green " =================================================="

    read configTrojanPasswordPrefixInput
    configTrojanPasswordPrefixInput=${configTrojanPasswordPrefixInput:-jin}

    mkdir -p ${configTrojanBasePath}
    cd ${configTrojanBasePath}
    rm -rf ${configTrojanBasePath}/*

    if [ "$isTrojanGo" = "no" ] ; then
        # https://github.com/trojan-gfw/trojan/releases/download/v1.16.0/trojan-1.16.0-linux-amd64.tar.xz
        downloadAndUnzip "https://github.com/trojan-gfw/trojan/releases/download/v${versionTrojan}/${downloadFilenameTrojan}" "${configTrojanPath}" "${downloadFilenameTrojan}"
    else
        # https://github.com/p4gefau1t/trojan-go/releases/download/v0.8.1/trojan-go-linux-amd64.zip
        downloadAndUnzip "https://github.com/p4gefau1t/trojan-go/releases/download/v${versionTrojanGo}/${downloadFilenameTrojanGo}" "${configTrojanGoPath}" "${downloadFilenameTrojanGo}"
    fi


    if [ "$configV2rayVlessMode" != "trojan" ] ; then
        configV2rayTrojanPort=443
    fi


    if [ "$isTrojanGo" = "no" ] ; then

        # 增加trojan 服务器端配置
	    cat > ${configTrojanBasePath}/server.json <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": $configV2rayTrojanPort,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "${trojanPassword1}",
        "${trojanPassword2}",
        "${trojanPassword3}",
        "${trojanPassword4}",
        "${trojanPassword5}",
        "${trojanPassword6}",
        "${trojanPassword7}",
        "${trojanPassword8}",
        "${trojanPassword9}",
        "${trojanPassword10}",
        "${configTrojanPasswordPrefixInput}202001",
        "${configTrojanPasswordPrefixInput}202002",
        "${configTrojanPasswordPrefixInput}202003",
        "${configTrojanPasswordPrefixInput}202004",
        "${configTrojanPasswordPrefixInput}202005",
        "${configTrojanPasswordPrefixInput}202006",
        "${configTrojanPasswordPrefixInput}202007",
        "${configTrojanPasswordPrefixInput}202008",
        "${configTrojanPasswordPrefixInput}202009",
        "${configTrojanPasswordPrefixInput}202010",
        "${configTrojanPasswordPrefixInput}202011",
        "${configTrojanPasswordPrefixInput}202012",
        "${configTrojanPasswordPrefixInput}202013",
        "${configTrojanPasswordPrefixInput}202014",
        "${configTrojanPasswordPrefixInput}202015",
        "${configTrojanPasswordPrefixInput}202016",
        "${configTrojanPasswordPrefixInput}202017",
        "${configTrojanPasswordPrefixInput}202018",
        "${configTrojanPasswordPrefixInput}202019",
        "${configTrojanPasswordPrefixInput}202020"

    ],
    "log_level": 1,
    "ssl": {
        "cert": "${configSSLCertPath}/$configSSLCertFullchainFilename",
        "key": "${configSSLCertPath}/$configSSLCertKeyFilename",
        "key_password": "",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	    "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF

        # rm /etc/systemd/system/trojan.service   
        # 增加启动脚本
        cat > ${osSystemMdPath}trojan.service <<-EOF
[Unit]
Description=trojan
After=network.target

[Service]
Type=simple
PIDFile=${configTrojanPath}/trojan.pid
ExecStart=${configTrojanPath}/trojan -l ${configTrojanLogFile} -c "${configTrojanPath}/server.json"
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
RestartPreventExitStatus=23
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    fi


    if [ "$isTrojanGo" = "yes" ] ; then

        # 增加trojan 服务器端配置
	    cat > ${configTrojanBasePath}/server.json <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": $configV2rayTrojanPort,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "${trojanPassword1}",
        "${trojanPassword2}",
        "${trojanPassword3}",
        "${trojanPassword4}",
        "${trojanPassword5}",
        "${trojanPassword6}",
        "${trojanPassword7}",
        "${trojanPassword8}",
        "${trojanPassword9}",
        "${trojanPassword10}",
        "${configTrojanPasswordPrefixInput}202001",
        "${configTrojanPasswordPrefixInput}202002",
        "${configTrojanPasswordPrefixInput}202003",
        "${configTrojanPasswordPrefixInput}202004",
        "${configTrojanPasswordPrefixInput}202005",
        "${configTrojanPasswordPrefixInput}202006",
        "${configTrojanPasswordPrefixInput}202007",
        "${configTrojanPasswordPrefixInput}202008",
        "${configTrojanPasswordPrefixInput}202009",
        "${configTrojanPasswordPrefixInput}202010",
        "${configTrojanPasswordPrefixInput}202011",
        "${configTrojanPasswordPrefixInput}202012",
        "${configTrojanPasswordPrefixInput}202013",
        "${configTrojanPasswordPrefixInput}202014",
        "${configTrojanPasswordPrefixInput}202015",
        "${configTrojanPasswordPrefixInput}202016",
        "${configTrojanPasswordPrefixInput}202017",
        "${configTrojanPasswordPrefixInput}202018",
        "${configTrojanPasswordPrefixInput}202019",
        "${configTrojanPasswordPrefixInput}202020"

    ],
    "log_level": 1,
    "log_file": "${configTrojanGoLogFile}",
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "${configSSLCertPath}/$configSSLCertFullchainFilename",
        "key": "${configSSLCertPath}/$configSSLCertKeyFilename",
        "key_password": "",
        "curves": "",
        "cipher": "",        
	    "prefer_server_cipher": false,
        "sni": "${configSSLDomain}",
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": true,
        "plain_http_response": "",
        "fallback_addr": "127.0.0.1",
        "fallback_port": 80,    
        "fingerprint": "firefox"
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true
    },
    "websocket": {
        "enabled": ${isTrojanGoSupportWebsocket},
        "path": "/${configTrojanGoWebSocketPath}",
        "host": "${configSSLDomain}"
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF

        # 增加启动脚本
        cat > ${osSystemMdPath}trojan-go.service <<-EOF
[Unit]
Description=trojan-go
After=network.target

[Service]
Type=simple
PIDFile=${configTrojanGoPath}/trojan-go.pid
ExecStart=${configTrojanGoPath}/trojan-go -config "${configTrojanGoPath}/server.json"
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF
    fi

    ${sudoCmd} chmod +x ${osSystemMdPath}trojan${promptInfoTrojanName}.service
    ${sudoCmd} systemctl daemon-reload
    ${sudoCmd} systemctl start trojan${promptInfoTrojanName}.service
    ${sudoCmd} systemctl enable trojan${promptInfoTrojanName}.service


    if [ "$configV2rayVlessMode" != "trojan" ] ; then
        
    
    # 下载并制作 trojan windows 客户端的命令行启动文件
    rm -rf ${configTrojanBasePath}/trojan-win-cli
    rm -rf ${configTrojanBasePath}/trojan-win-cli-temp
    mkdir -p ${configTrojanBasePath}/trojan-win-cli-temp

    downloadAndUnzip "https://github.com/jinwyp/one_click_script/raw/master/download/trojan-win-cli.zip" "${configTrojanBasePath}" "trojan-win-cli.zip"

    if [ "$isTrojanGo" = "no" ] ; then
        downloadAndUnzip "https://github.com/trojan-gfw/trojan/releases/download/v${versionTrojan}/trojan-${versionTrojan}-win.zip" "${configTrojanBasePath}/trojan-win-cli-temp" "trojan-${versionTrojan}-win.zip"
        mv -f ${configTrojanBasePath}/trojan-win-cli-temp/trojan/trojan.exe ${configTrojanBasePath}/trojan-win-cli/
        mv -f ${configTrojanBasePath}/trojan-win-cli-temp/trojan/VC_redist.x64.exe ${configTrojanBasePath}/trojan-win-cli/
    fi

    if [ "$isTrojanGo" = "yes" ] ; then
        downloadAndUnzip "https://github.com/p4gefau1t/trojan-go/releases/download/v${versionTrojanGo}/trojan-go-windows-amd64.zip" "${configTrojanBasePath}/trojan-win-cli-temp" "trojan-go-windows-amd64.zip"
        mv -f ${configTrojanBasePath}/trojan-win-cli-temp/* ${configTrojanBasePath}/trojan-win-cli/
    fi

    rm -rf ${configTrojanBasePath}/trojan-win-cli-temp
    cp ${configSSLCertPath}/$configSSLCertFullchainFilename ${configTrojanBasePath}/trojan-win-cli/$configSSLCertFullchainFilename

    cat > ${configTrojanBasePath}/trojan-win-cli/config.json <<-EOF
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "${configSSLDomain}",
    "remote_port": 443,
    "password": [
        "${trojanPassword1}"
    ],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "$configSSLCertFullchainFilename",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	    "sni": "",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOF

    zip -r ${configWebsiteDownloadPath}/trojan-win-cli.zip ${configTrojanBasePath}/trojan-win-cli/

    fi



    # 设置 cron 定时任务
    # https://stackoverflow.com/questions/610839/how-can-i-programmatically-create-a-new-cron-job

    # (crontab -l 2>/dev/null | grep -v '^[a-zA-Z]'; echo "15 4 * * 0,1,2,3,4,5,6 systemctl restart trojan.service") | sort - | uniq - | crontab -
    (crontab -l ; echo "10 4 * * 0,1,2,3,4,5,6 systemctl restart trojan${promptInfoTrojanName}.service") | sort - | uniq - | crontab -


	green "======================================================================"
	green "    Trojan${promptInfoTrojanName} Version: ${configTrojanBaseVersion} 安装成功 !"

    if [[ ${isInstallNginx} == "true" ]]; then
        green "    伪装站点为 https://${configSSLDomain}"
	    green "    伪装站点的静态html内容放置在目录 ${configWebsitePath}, 可自行更换网站内容!"
    fi

	red "    Trojan${promptInfoTrojanName} 服务器端配置路径 ${configTrojanBasePath}/server.json "
	red "    Trojan${promptInfoTrojanName} 运行日志文件路径: ${configTrojanLogFile} "
	green "    Trojan${promptInfoTrojanName} 查看日志命令: journalctl -n 50 -u trojan${promptInfoTrojanName}.service "

	green "    Trojan${promptInfoTrojanName} 停止命令: systemctl stop trojan${promptInfoTrojanName}.service  启动命令: systemctl start trojan${promptInfoTrojanName}.service  重启命令: systemctl restart trojan${promptInfoTrojanName}.service"
	green "    Trojan${promptInfoTrojanName} 查看运行状态命令:  systemctl status trojan${promptInfoTrojanName}.service "
	green "    Trojan${promptInfoTrojanName} 服务器 每天会自动重启, 防止内存泄漏. 运行 crontab -l 命令 查看定时重启命令 !"
	green "======================================================================"
	blue  "----------------------------------------"
	yellow "Trojan${promptInfoTrojanName} 配置信息如下, 请自行复制保存, 密码任选其一 !"
	yellow "服务器地址: ${configSSLDomain}  端口: $configV2rayTrojanPort"
	yellow "密码1: ${trojanPassword1}"
	yellow "密码2: ${trojanPassword2}"
	yellow "密码3: ${trojanPassword3}"
	yellow "密码4: ${trojanPassword4}"
	yellow "密码5: ${trojanPassword5}"
	yellow "密码6: ${trojanPassword6}"
	yellow "密码7: ${trojanPassword7}"
	yellow "密码8: ${trojanPassword8}"
	yellow "密码9: ${trojanPassword9}"
	yellow "密码10: ${trojanPassword10}"
	yellow "您指定前缀的密码共20个: 从 ${configTrojanPasswordPrefixInput}202001 到 ${configTrojanPasswordPrefixInput}202020 都可以使用"
	yellow "例如: 密码:${configTrojanPasswordPrefixInput}202002 或 密码:${configTrojanPasswordPrefixInput}202019 都可以使用"

    if [[ ${isTrojanGoSupportWebsocket} == "true" ]]; then
        yellow "Websocket path 路径为: /${configTrojanGoWebSocketPath}"
        # yellow "Websocket obfuscation_password 混淆密码为: ${trojanPasswordWS}"
        yellow "Websocket 双重TLS为: true 开启"
    fi

    echo
    green "======================================================================"
    yellow " Trojan${promptInfoTrojanName} 小火箭 Shadowrocket 链接地址"

    if [ "$isTrojanGo" = "yes" ] ; then
        if [[ ${isTrojanGoSupportWebsocket} == "true" ]]; then
            green " trojan://${trojanPassword1}@${configSSLDomain}:${configV2rayTrojanPort}?peer=${configSSLDomain}&sni=${configSSLDomain}&plugin=obfs-local;obfs=websocket;obfs-host=${configSSLDomain};obfs-uri=/${configTrojanGoWebSocketPath}#${configSSLDomain}_trojan_go_ws"
            echo
            yellow " 二维码 Trojan${promptInfoTrojanName} "
		    green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${trojanPassword1}%40${configSSLDomain}%3a${configV2rayTrojanPort}%3fallowInsecure%3d0%26peer%3d${configSSLDomain}%26plugin%3dobfs-local%3bobfs%3dwebsocket%3bobfs-host%3d${configSSLDomain}%3bobfs-uri%3d/${configTrojanGoWebSocketPath}%23${configSSLDomain}_trojan_go_ws"

            echo
            yellow " Trojan${promptInfoTrojanName} QV2ray 链接地址"
            green " trojan-go://${trojanPassword1}@${configSSLDomain}:${configV2rayTrojanPort}?sni=${configSSLDomain}&type=ws&host=${configSSLDomain}&path=%2F${configTrojanGoWebSocketPath}#${configSSLDomain}_trojan_go_ws"
        
        else
            green " trojan://${trojanPassword1}@${configSSLDomain}:${configV2rayTrojanPort}?peer=${configSSLDomain}&sni=${configSSLDomain}#${configSSLDomain}_trojan_go"
            echo
            yellow " 二维码 Trojan${promptInfoTrojanName} "
            green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${trojanPassword1}%40${configSSLDomain}%3a${configV2rayTrojanPort}%3fpeer%3d${configSSLDomain}%26sni%3d${configSSLDomain}%23${configSSLDomain}_trojan_go"

            echo
            yellow " Trojan${promptInfoTrojanName} QV2ray 链接地址"
            green " trojan-go://${trojanPassword1}@${configSSLDomain}:${configV2rayTrojanPort}?sni=${configSSLDomain}&type=original&host=${configSSLDomain}#${configSSLDomain}_trojan_go"
        fi

    else
        green " trojan://${trojanPassword1}@${configSSLDomain}:${configV2rayTrojanPort}?peer=${configSSLDomain}&sni=${configSSLDomain}#${configSSLDomain}_trojan"
        echo
        yellow " 二维码 Trojan${promptInfoTrojanName} "
		green "https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${trojanPassword1}%40${configSSLDomain}%3a${configV2rayTrojanPort}%3fpeer%3d${configSSLDomain}%26sni%3d${configSSLDomain}%23${configSSLDomain}_trojan"

    fi

	echo
	green "======================================================================"
	green "请下载相应的trojan客户端:"
	yellow "1 Windows 客户端下载：http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/v2ray-windows.zip"
	#yellow "  Windows 客户端另一个版本下载：http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/trojan-Qt5-windows.zip"
	yellow "  Windows 客户端命令行版本下载：http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/trojan-win-cli.zip"
	yellow "  Windows 客户端命令行版本需要搭配浏览器插件使用，例如switchyomega等! "
    yellow "2 MacOS 客户端下载：http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/v2ray-mac.zip"
    yellow "  MacOS 另一个客户端下载：http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/trojan-mac.zip"
    #yellow "  MacOS 客户端Trojan-Qt5下载：http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/trojan-Qt5-mac.zip"
    yellow "3 Android 客户端下载 https://github.com/trojan-gfw/igniter/releases "
    yellow "  Android 另一个客户端下载 https://github.com/2dust/v2rayNG/releases "
    yellow "  Android 客户端Clash下载 https://github.com/Kr328/ClashForAndroid/releases "
    yellow "4 iOS 客户端 请安装小火箭 https://shadowsockshelp.github.io/ios/ "
    yellow "  iOS 请安装小火箭另一个地址 https://lueyingpro.github.io/shadowrocket/index.html "
    yellow "  iOS 安装小火箭遇到问题 教程 https://github.com/shadowrocketHelp/help/ "
    green "======================================================================"
	green "教程与其他资源:"
	green "访问 https://www.v2rayssr.com/trojan-1.html ‎ 下载 浏览器插件 客户端 及教程"
	green "客户端汇总 https://tlanyan.me/trojan-clients-download ‎ 下载 trojan客户端"
    green "访问 https://westworldss.com/portal/page/download ‎ 下载 客户端 及教程"
	green "======================================================================"
	green "其他 Windows 客户端:"
	green "https://github.com/TheWanderingCoel/Trojan-Qt5/releases (exe为Win客户端, dmg为Mac客户端)"
	green "https://github.com/Qv2ray/Qv2ray/releases (exe为Win客户端, dmg为Mac客户端)"
	green "https://github.com/Dr-Incognito/V2Ray-Desktop/releases (exe为Win客户端, dmg为Mac客户端)"
	green "https://github.com/Fndroid/clash_for_windows_pkg/releases"
	green "======================================================================"
	green "其他 Mac 客户端:"
	green "https://github.com/TheWanderingCoel/Trojan-Qt5/releases (exe为Win客户端, dmg为Mac客户端)"
	green "https://github.com/Qv2ray/Qv2ray/releases (exe为Win客户端, dmg为Mac客户端)"
	green "https://github.com/Dr-Incognito/V2Ray-Desktop/releases (exe为Win客户端, dmg为Mac客户端)"
	green "https://github.com/JimLee1996/TrojanX/releases (exe为Win客户端, dmg为Mac客户端)"
	green "https://github.com/yichengchen/clashX/releases "
	green "======================================================================"
	green "其他 Android 客户端:"
	green "https://github.com/trojan-gfw/igniter/releases "
	green "https://github.com/Kr328/ClashForAndroid/releases "
	green "======================================================================"


    cat >> ${configReadme} <<-EOF

Trojan${promptInfoTrojanName} Version: ${configTrojanBaseVersion} 安装成功 !
Trojan${promptInfoTrojanName} 服务器端配置路径 ${configTrojanBasePath}/server.json

Trojan${promptInfoTrojanName} 运行日志文件路径: ${configTrojanLogFile} 
Trojan${promptInfoTrojanName} 查看日志命令: journalctl -n 50 -u trojan${promptInfoTrojanName}.service

Trojan${promptInfoTrojanName} 启动命令: systemctl start trojan${promptInfoTrojanName}.service
Trojan${promptInfoTrojanName} 停止命令: systemctl stop trojan${promptInfoTrojanName}.service  
Trojan${promptInfoTrojanName} 重启命令: systemctl restart trojan${promptInfoTrojanName}.service
Trojan${promptInfoTrojanName} 查看运行状态命令: systemctl status trojan${promptInfoTrojanName}.service

Trojan${promptInfoTrojanName}服务器地址: ${configSSLDomain}  端口: $configV2rayTrojanPort

密码1: ${trojanPassword1}
密码2: ${trojanPassword2}
密码3: ${trojanPassword3}
密码4: ${trojanPassword4}
密码5: ${trojanPassword5}
密码6: ${trojanPassword6}
密码7: ${trojanPassword7}
密码8: ${trojanPassword8}
密码9: ${trojanPassword9}
密码10: ${trojanPassword10}
您指定前缀的密码共20个: 从 ${configTrojanPasswordPrefixInput}202001 到 ${configTrojanPasswordPrefixInput}202020 都可以使用
例如: 密码:${configTrojanPasswordPrefixInput}202002 或 密码:${configTrojanPasswordPrefixInput}202019 都可以使用

如果是trojan-go开启了Websocket，那么Websocket path 路径为: /${configTrojanGoWebSocketPath}

小火箭链接:
trojan://${trojanPassword1}@${configSSLDomain}:${configV2rayTrojanPort}?peer=${configSSLDomain}&sni=${configSSLDomain}#${configSSLDomain}_trojan"

二维码 Trojan${promptInfoTrojanName}
https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${trojanPassword1}%40${configSSLDomain}%3a${configV2rayTrojanPort}%3fpeer%3d${configSSLDomain}%26sni%3d${configSSLDomain}%23${configSSLDomain}_trojan

EOF
}


function removeTrojan(){

    isTrojanGoInstall

    ${sudoCmd} systemctl stop trojan${promptInfoTrojanName}.service
    ${sudoCmd} systemctl disable trojan${promptInfoTrojanName}.service

    echo
    green " ================================================== "
    red " 准备卸载已安装的trojan${promptInfoTrojanName}"
    green " ================================================== "
    echo

    rm -rf ${configTrojanBasePath}
    rm -f ${osSystemMdPath}trojan${promptInfoTrojanName}.service
    rm -f ${configTrojanLogFile}
    rm -f ${configTrojanGoLogFile}

    rm -f ${configReadme}

    crontab -r

    echo
    green " ================================================== "
    green "  trojan${promptInfoTrojanName} 和 nginx 卸载完毕 !"
    green "  crontab 定时任务 删除完毕 !"
    green " ================================================== "
    echo
}


function upgradeTrojan(){

    isTrojanGoInstall

    green " ================================================== "
    green "     开始升级 Trojan${promptInfoTrojanName} Version: ${configTrojanBaseVersion}"
    green " ================================================== "

    ${sudoCmd} systemctl stop trojan${promptInfoTrojanName}.service

    mkdir -p ${configDownloadTempPath}/upgrade/trojan${promptInfoTrojanName}

    if [ "$isTrojanGo" = "no" ] ; then
        # https://github.com/trojan-gfw/trojan/releases/download/v1.16.0/trojan-1.16.0-linux-amd64.tar.xz
        downloadAndUnzip "https://github.com/trojan-gfw/trojan/releases/download/v${versionTrojan}/${downloadFilenameTrojan}" "${configDownloadTempPath}/upgrade/trojan" "${downloadFilenameTrojan}"
        mv -f ${configDownloadTempPath}/upgrade/trojan/trojan ${configTrojanPath}
    else
        # https://github.com/p4gefau1t/trojan-go/releases/download/v0.8.1/trojan-go-linux-amd64.zip
        downloadAndUnzip "https://github.com/p4gefau1t/trojan-go/releases/download/v${versionTrojanGo}/${downloadFilenameTrojanGo}" "${configDownloadTempPath}/upgrade/trojan-go" "${downloadFilenameTrojanGo}"
        mv -f ${configDownloadTempPath}/upgrade/trojan-go/trojan-go ${configTrojanGoPath}
    fi

    ${sudoCmd} systemctl start trojan${promptInfoTrojanName}.service

    green " ================================================== "
    green "     升级成功 Trojan${promptInfoTrojanName} Version: ${configTrojanBaseVersion} !"
    green " ================================================== "

}





























function inputV2rayWSPath(){ 
    configV2rayWebSocketPath=$(cat /dev/urandom | head -1 | md5sum | head -c 8)

    read -p "是否自定义${promptInfoXrayName}的WS的Path? 直接回车默认创建随机路径, 请输入自定义路径(不要输入/):" isV2rayUserWSPathInput
    isV2rayUserWSPathInput=${isV2rayUserWSPathInput:-${configV2rayWebSocketPath}}

    if [[ -z $isV2rayUserWSPathInput ]]; then
        echo
    else
        configV2rayWebSocketPath=${isV2rayUserWSPathInput}
    fi
}

function inputV2rayGRPCPath(){ 
    configV2rayGRPCServiceName=$(cat /dev/urandom | head -1 | md5sum | head -c 8)

    read -p "是否自定义${promptInfoXrayName}的 gRPC 的serviceName ? 直接回车默认创建随机路径, 请输入自定义路径(不要输入/):" isV2rayUserGRPCPathInput
    isV2rayUserGRPCPathInput=${isV2rayUserGRPCPathInput:-${configV2rayGRPCServiceName}}

    if [[ -z $isV2rayUserGRPCPathInput ]]; then
        echo
    else
        configV2rayGRPCServiceName=${isV2rayUserGRPCPathInput}
    fi
}


function inputV2rayServerPort(){  
    echo
	if [[ $1 == "textMainPort" ]]; then
        read -p "是否自定义${promptInfoXrayName}的端口号? 直接回车默认为${configV2rayPortShowInfo}, 请输入自定义端口号[1-65535]:" isV2rayUserPortInput
        isV2rayUserPortInput=${isV2rayUserPortInput:-${configV2rayPortShowInfo}}
		checkPortInUse "${isV2rayUserPortInput}" $1 
	fi

	if [[ $1 == "textMainGRPCPort" ]]; then
        green " 如果使用gRPC 协议并要支持cloudflare的CDN, 需要人工输入 443 端口才可以"
        read -p "是否自定义${promptInfoXrayName} gRPC的端口号? 直接回车默认为${configV2rayPortGRPCShowInfo}, 请输入自定义端口号[1-65535]:" isV2rayUserPortGRPCInput
        isV2rayUserPortGRPCInput=${isV2rayUserPortGRPCInput:-${configV2rayPortGRPCShowInfo}}
		checkPortInUse "${isV2rayUserPortGRPCInput}" $1 
	fi    

	if [[ $1 == "textAdditionalPort" ]]; then
        green " 是否添加一个额外监听端口, 与主端口${configV2rayPort}一起同时工作"
        green " 一般用于 中转机无法使用443端口中转给目标主机时使用"
        read -p "是否给${promptInfoXrayName}添加额外的监听端口? 直接回车默认否, 请输入额外端口号[1-65535]:" isV2rayAdditionalPortInput
        isV2rayAdditionalPortInput=${isV2rayAdditionalPortInput:-999999}
        checkPortInUse "${isV2rayAdditionalPortInput}" $1 
	fi
}

function checkPortInUse(){ 
    if [ $1 = "999999" ]; then
        echo
    elif [[ $1 -gt 1 && $1 -le 65535 ]]; then
            
        netstat -tulpn | grep [0-9]:$1 -q ; 
        if [ $? -eq 1 ]; then 
            green "输入的端口号 $1 没有被占用, 继续安装..."  
            
        else 
            red "输入的端口号 $1 已被占用! 请退出安装, 检查端口是否已被占用 或 重新输入!" 
            inputV2rayServerPort $2 
        fi
    else
        red "输入的端口号错误! 必须是[1-65535]. 请重新输入" 
        inputV2rayServerPort $2 
    fi
}




function installV2ray(){

    v2rayPassword1=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword2=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword3=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword4=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword5=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword6=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword7=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword8=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword9=$(cat /proc/sys/kernel/random/uuid)
    v2rayPassword10=$(cat /proc/sys/kernel/random/uuid)

    echo
    if [ -f "${configV2rayPath}/xray" ] || [ -f "${configV2rayPath}/v2ray" ] || [ -f "/usr/local/bin/v2ray" ] || [ -f "/usr/bin/v2ray" ]; then
        green " =================================================="
        green "     已安装过 V2ray 或 Xray, 退出安装 !"
        green " =================================================="
        exit
    fi

    green " =================================================="
    green "    开始安装 V2ray or Xray "
    green " =================================================="    
    echo


    if [[ ( $configV2rayVlessMode == "trojan" ) || ( $configV2rayVlessMode == "vlessxtlsws" ) || ( $configV2rayVlessMode == "vlessxtlstrojan" ) ]] ; then
        promptInfoXrayName="xray"
        isXray="yes"
	V2rayUnlockText="\"geosite:netflix\""
    else
        read -p "是否使用Xray内核? 直接回车默认为V2ray内核, 请输入[y/N]:" isV2rayOrXrayInput
        isV2rayOrXrayInput=${isV2rayOrXrayInput:-n}

        if [[ $isV2rayOrXrayInput == [Yy] ]]; then
            promptInfoXrayName="xray"
            isXray="yes"
        fi
    fi

    if [[ -n "$configV2rayVlessMode" ]]; then
         configV2rayProtocol="vless"
    else 

        echo
        read -p "是否使用VMess协议? 直接回车默认为Vless协议, 请输入[y/N]:" isV2rayUseVLessInput
        isV2rayUseVLessInput=${isV2rayUseVLessInput:-n}

        if [[ $isV2rayUseVLessInput == [Yy] ]]; then
            configV2rayProtocol="vmess"
        else
            configV2rayProtocol="vless"
        fi

    fi

					
    echo
    read -p "是否自定义${promptInfoXrayName}的密码? 直接回车默认创建随机密码, 请输入自定义UUID密码:" isV2rayUserPassordInput
    isV2rayUserPassordInput=${isV2rayUserPassordInput:-''}

    if [[ -z $isV2rayUserPassordInput ]]; then
        isV2rayUserPassordInput=""
    else
        v2rayPassword1=${isV2rayUserPassordInput}
    fi



    # 增加自定义端口号
    if [[ ${isInstallNginx} == "true" ]]; then
        configV2rayPortShowInfo=443
        configV2rayPortGRPCShowInfo=443
        
        if [[ $configV2rayVlessMode == "vlessxtlstrojan" ]]; then
            configV2rayPort=443
        fi
    else
        configV2rayPort="$(($RANDOM + 10000))"
        
        if [[ -n "$configV2rayVlessMode" ]]; then
            configV2rayPort=443
        fi
        configV2rayPortShowInfo=$configV2rayPort

        inputV2rayServerPort "textMainPort"

        configV2rayPort=${isV2rayUserPortInput}   
        configV2rayPortShowInfo=${isV2rayUserPortInput}   


        if [[ ( $configV2rayWSorGrpc == "grpc" ) || ( $configV2rayVlessMode == "wsgrpc" ) ]]; then
            inputV2rayServerPort "textMainGRPCPort"

            configV2rayGRPCPort=${isV2rayUserPortGRPCInput}   
            configV2rayPortGRPCShowInfo=${isV2rayUserPortGRPCInput}   
        fi


        echo
        if [[ ( $configV2rayWSorGrpc == "grpc" ) || ( $configV2rayVlessMode == "wsgrpc" ) || ( $configV2rayVlessMode == "vlessgrpc" ) ]]; then
            inputV2rayGRPCPath
        else
            inputV2rayWSPath
        fi




        
        
        inputV2rayServerPort "textAdditionalPort"

        if [[ $isV2rayAdditionalPortInput == "999999" ]]; then
            v2rayConfigAdditionalPortInput=""
        else
            read -r -d '' v2rayConfigAdditionalPortInput << EOM
        ,
        {
            "listen": "0.0.0.0",
            "port": ${isV2rayAdditionalPortInput}, 
            "protocol": "dokodemo-door",
            "settings": {
                "address": "127.0.0.1",
                "port": ${configV2rayPort},
                "network": "tcp, udp",
                "followRedirect": false 
            },
            "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls"]
            }
        }     

EOM

        fi

    fi




    
    if [ "$isXray" = "no" ] ; then
        getTrojanAndV2rayVersion "v2ray"
        green "    准备下载并安装 V2ray Version: ${versionV2ray} !"
        promptInfoXrayInstall="V2ray"
        promptInfoXrayVersion=${versionV2ray}
    else
        getTrojanAndV2rayVersion "xray"
        green "    准备下载并安装 Xray Version: ${versionXray} !"
        promptInfoXrayInstall="Xray"
        promptInfoXrayVersion=${versionXray}
    fi
    echo


    mkdir -p ${configV2rayPath}
    cd ${configV2rayPath}
    rm -rf ${configV2rayPath}/*


    if [ "$isXray" = "no" ] ; then
        # https://github.com/v2fly/v2ray-core/releases/download/v4.27.5/v2ray-linux-64.zip
        downloadAndUnzip "https://github.com/v2fly/v2ray-core/releases/download/v${versionV2ray}/${downloadFilenameV2ray}" "${configV2rayPath}" "${downloadFilenameV2ray}"

    else
        downloadAndUnzip "https://github.com/XTLS/Xray-core/releases/download/v${versionXray}/${downloadFilenameXray}" "${configV2rayPath}" "${downloadFilenameXray}"
    fi








    # 增加 v2ray 服务器端配置

    trojanPassword1=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword2=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword3=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword4=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword5=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword6=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword7=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword8=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword9=$(cat /dev/urandom | head -1 | md5sum | head -c 10)
    trojanPassword10=$(cat /dev/urandom | head -1 | md5sum | head -c 10)

    read -r -d '' v2rayConfigUserpasswordTrojanInput << EOM
                    {
                        "password": "${trojanPassword1}",
                        "level": 0,
                        "email": "password111@gmail.com"
                    },
                    {
                        "password": "${trojanPassword2}",
                        "level": 0,
                        "email": "password112@gmail.com"
                    },
                    {
                        "password": "${trojanPassword3}",
                        "level": 0,
                        "email": "password113@gmail.com"
                    },
                    {
                        "password": "${trojanPassword4}",
                        "level": 0,
                        "email": "password114@gmail.com"
                    },
                    {
                        "password": "${trojanPassword5}",
                        "level": 0,
                        "email": "password115@gmail.com"
                    },
                    {
                        "password": "${trojanPassword6}",
                        "level": 0,
                        "email": "password116@gmail.com"
                    },
                    {
                        "password": "${trojanPassword7}",
                        "level": 0,
                        "email": "password117@gmail.com"
                    },
                    {
                        "password": "${trojanPassword8}",
                        "level": 0,
                        "email": "password118@gmail.com"
                    },
                    {
                        "password": "${trojanPassword9}",
                        "level": 0,
                        "email": "password119@gmail.com"
                    },
                    {
                        "password": "${trojanPassword10}",
                        "level": 0,
                        "email": "password120@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202001",
                        "level": 0,
                        "email": "password201@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202002",
                        "level": 0,
                        "email": "password202@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202003",
                        "level": 0,
                        "email": "password203@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202004",
                        "level": 0,
                        "email": "password204@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202005",
                        "level": 0,
                        "email": "password205@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202006",
                        "level": 0,
                        "email": "password206@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202007",
                        "level": 0,
                        "email": "password207@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202008",
                        "level": 0,
                        "email": "password208@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202009",
                        "level": 0,
                        "email": "password209@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202010",
                        "level": 0,
                        "email": "password210@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202011",
                        "level": 0,
                        "email": "password211@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202012",
                        "level": 0,
                        "email": "password212@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202013",
                        "level": 0,
                        "email": "password213@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202014",
                        "level": 0,
                        "email": "password214@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202015",
                        "level": 0,
                        "email": "password215@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202016",
                        "level": 0,
                        "email": "password216@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202017",
                        "level": 0,
                        "email": "password217@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202018",
                        "level": 0,
                        "email": "password218@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202019",
                        "level": 0,
                        "email": "password219@gmail.com"
                    },
                    {
                        "password": "${configTrojanPasswordPrefixInput}202020",
                        "level": 0,
                        "email": "password220@gmail.com"
                    }

EOM


    read -r -d '' v2rayConfigUserpasswordInput << EOM
                    {
                        "id": "${v2rayPassword1}",
                        "level": 0,
                        "email": "password11@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword2}",
                        "level": 0,
                        "email": "password12@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword3}",
                        "level": 0,
                        "email": "password13@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword4}",
                        "level": 0,
                        "email": "password14@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword5}",
                        "level": 0,
                        "email": "password15@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword6}",
                        "level": 0,
                        "email": "password16@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword7}",
                        "level": 0,
                        "email": "password17@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword8}",
                        "level": 0,
                        "email": "password18@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword9}",
                        "level": 0,
                        "email": "password19@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword10}",
                        "level": 0,
                        "email": "password20@gmail.com"
                    }
EOM

    read -r -d '' v2rayConfigUserpasswordDirectInput << EOM
                    {
                        "id": "${v2rayPassword1}",
                        "flow": "xtls-rprx-direct",
                        "level": 0,
                        "email": "password11@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword2}",
                        "flow": "xtls-rprx-direct",
                        "level": 0,
                        "email": "password12@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword3}",
                        "flow": "xtls-rprx-direct",
                        "level": 0,
                        "email": "password13@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword4}",
                        "flow": "xtls-rprx-direct",
                        "level": 0,
                        "email": "password14@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword5}",
                        "flow": "xtls-rprx-direct",
                        "level": 0,
                        "email": "password15@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword6}",
                        "flow": "xtls-rprx-direct",
                        "level": 0,
                        "email": "password16@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword7}",
                        "flow": "xtls-rprx-direct",
                        "level": 0,
                        "email": "password17@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword8}",
                        "flow": "xtls-rprx-direct",
                        "level": 0,
                        "email": "password18@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword9}",
                        "flow": "xtls-rprx-direct",
                        "level": 0,
                        "email": "password19@gmail.com"
                    },
                    {
                        "id": "${v2rayPassword10}",
                        "flow": "xtls-rprx-direct",
                        "level": 0,
                        "email": "password20@gmail.com"
                    }
EOM


    if [[ $isV2rayUnlockGoogleInput == "1" ]]; then

        read -r -d '' v2rayConfigOutboundInput << EOM
    "outbounds": [
        {
            "tag": "direct",
            "protocol": "freedom",
            "settings": {}
        },
        {
            "tag": "blocked",
            "protocol": "blackhole",
            "settings": {}
        }
    ]
EOM

    else

        read -r -d '' v2rayConfigOutboundInput << EOM
    "outbounds": [
        {
            "tag":"IP4_out",
            "protocol": "freedom",
            "settings": {}
        },
        {
            "tag":"IP6_out",
            "protocol": "freedom",
            "settings": {
                "domainStrategy": "UseIPv6" 
            }
        }
    ],    
    "routing": {
        "rules": [
            {
                "type": "field",
                "outboundTag": "IP6_out",
                "domain": [${V2rayUnlockText}] 
            },
            {
                "type": "field",
                "outboundTag": "IP4_out",
                "network": "udp,tcp"
            }
        ]
    }
EOM
        
    fi




    read -r -d '' v2rayConfigLogInput << EOM
    "log" : {
        "access": "${configV2rayAccessLogFilePath}",
        "error": "${configV2rayErrorLogFilePath}",
        "loglevel": "warning"
    },
EOM




    if [[ -z "$configV2rayVlessMode" ]]; then

        if [[ "$configV2rayWSorGrpc" == "grpc" ]]; then
            cat > ${configV2rayPath}/config.json <<-EOF
{
    ${v2rayConfigLogInput}
    "inbounds": [
        {
            "port": ${configV2rayGRPCPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "grpc",
                "grpcSettings": {
                    "serviceName": "${configV2rayGRPCServiceName}" 
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
    ${v2rayConfigOutboundInput}
}
EOF
        elif [[ "$configV2rayWSorGrpc" == "wsgrpc" ]]; then
            cat > ${configV2rayPath}/config.json <<-EOF
{
    ${v2rayConfigLogInput}
    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/${configV2rayWebSocketPath}"
                }
            }
        },
        {
            "port": ${configV2rayGRPCPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "grpc",
                "grpcSettings": {
                    "serviceName": "${configV2rayGRPCServiceName}" 
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
    ${v2rayConfigOutboundInput}
}
EOF

        else
            cat > ${configV2rayPath}/config.json <<-EOF
{
    ${v2rayConfigLogInput}
    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/${configV2rayWebSocketPath}"
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
    ${v2rayConfigOutboundInput}
}
EOF

        fi

    fi


    if [[ "$configV2rayVlessMode" == "vlessws" ]]; then
        cat > ${configV2rayPath}/config.json <<-EOF
{
    ${v2rayConfigLogInput}
    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 80
                    },
                    {
                        "path": "/${configV2rayWebSocketPath}",
                        "dest": ${configV2rayVmesWSPort},
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "alpn": [
                        "http/1.1"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "${configSSLCertPath}/$configSSLCertFullchainFilename",
                            "keyFile": "${configSSLCertPath}/$configSSLCertKeyFilename"
                        }
                    ]
                }
            }
        },
        {
            "port": ${configV2rayVmesWSPort},
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "acceptProxyProtocol": true,
                    "path": "/${configV2rayWebSocketPath}" 
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
    ${v2rayConfigOutboundInput}
}
EOF
    fi


    if [[ "$configV2rayVlessMode" == "vlessgrpc" ]]; then
        cat > ${configV2rayPath}/config.json <<-EOF
{
    ${v2rayConfigLogInput}
    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 80
                    }
                ]
            },
            "streamSettings": {
                "network": "grpc",
                "security": "tls",
                "tlsSettings": {
                    "alpn": [
                        "h2", 
                        "http/1.1"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "${configSSLCertPath}/$configSSLCertFullchainFilename",
                            "keyFile": "${configSSLCertPath}/$configSSLCertKeyFilename"
                        }
                    ]
                },
                "grpcSettings": {
                    "serviceName": "${configV2rayGRPCServiceName}"
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
    ${v2rayConfigOutboundInput}
}
EOF
    fi



    if [[ "$configV2rayVlessMode" == "vmessws" ]]; then
        cat > ${configV2rayPath}/config.json <<-EOF
{
    ${v2rayConfigLogInput}
    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 80
                    },
                    {
                        "path": "/${configV2rayWebSocketPath}",
                        "dest": ${configV2rayVmesWSPort},
                        "xver": 1
                    },
                    {
                        "path": "/tcp${configV2rayWebSocketPath}",
                        "dest": ${configV2rayVmessTCPPort},
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "tls",
                "tlsSettings": {
                    "alpn": [
                        "http/1.1"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "${configSSLCertPath}/$configSSLCertFullchainFilename",
                            "keyFile": "${configSSLCertPath}/$configSSLCertKeyFilename"
                        }
                    ]
                }
            }
        },
        {
            "port": ${configV2rayVmesWSPort},
            "listen": "127.0.0.1",
            "protocol": "vmess",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ]
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "path": "/${configV2rayWebSocketPath}" 
                }
            }
        },
        {
            "port": ${configV2rayVmessTCPPort},
            "listen": "127.0.0.1",
            "protocol": "vmess",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "none",
                "tcpSettings": {
                    "acceptProxyProtocol": true,
                    "header": {
                        "type": "http",
                        "request": {
                            "path": [
                                "/tcp${configV2rayWebSocketPath}"
                            ]
                        }
                    }
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
    ${v2rayConfigOutboundInput}
}
EOF
    fi



    if [[  $configV2rayVlessMode == "vlessxtlstrojan" ]]; then
            cat > ${configV2rayPath}/config.json <<-EOF
{
    ${v2rayConfigLogInput}
    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordDirectInput}
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": ${configV2rayTrojanPort},
                        "xver": 1
                    },
                    {
                        "path": "/${configV2rayWebSocketPath}",
                        "dest": ${configV2rayVmesWSPort},
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "xtls",
                "xtlsSettings": {
                    "alpn": [
                        "http/1.1"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "${configSSLCertPath}/$configSSLCertFullchainFilename",
                            "keyFile": "${configSSLCertPath}/$configSSLCertKeyFilename"
                        }
                    ]
                }
            }
        },
        {
            "port": ${configV2rayTrojanPort},
            "listen": "127.0.0.1",
            "protocol": "trojan",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordTrojanInput}
                ],
                "fallbacks": [
                    {
                        "dest": 80 
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "none",
                "tcpSettings": {
                    "acceptProxyProtocol": true
                }
            }
        },
        {
            "port": ${configV2rayVmesWSPort},
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "acceptProxyProtocol": true,
                    "path": "/${configV2rayWebSocketPath}" 
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
    ${v2rayConfigOutboundInput}
}
EOF
    fi


    if [[  $configV2rayVlessMode == "vlessxtlsws" ]]; then
            cat > ${configV2rayPath}/config.json <<-EOF
{
    ${v2rayConfigLogInput}
    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordDirectInput}
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": 80
                    },
                    {
                        "path": "/${configV2rayWebSocketPath}",
                        "dest": ${configV2rayVmesWSPort},
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "xtls",
                "xtlsSettings": {
                    "alpn": [
                        "http/1.1"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "${configSSLCertPath}/$configSSLCertFullchainFilename",
                            "keyFile": "${configSSLCertPath}/$configSSLCertKeyFilename"
                        }
                    ]
                }
            }
        },
        {
            "port": ${configV2rayVmesWSPort},
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "acceptProxyProtocol": true,
                    "path": "/${configV2rayWebSocketPath}" 
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
    ${v2rayConfigOutboundInput}
}
EOF
    fi






    if [[ $configV2rayVlessMode == "trojan" ]]; then

            cat > ${configV2rayPath}/config.json <<-EOF
{
    ${v2rayConfigLogInput}
    "inbounds": [
        {
            "port": ${configV2rayPort},
            "protocol": "${configV2rayProtocol}",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordDirectInput}
                ],
                "decryption": "none",
                "fallbacks": [
                    {
                        "dest": ${configV2rayTrojanPort},
                        "xver": 1
                    },
                    {
                        "path": "/${configTrojanGoWebSocketPath}",
                        "dest": ${configV2rayTrojanPort},
                        "xver": 1
                    },
                    {
                        "path": "/${configV2rayWebSocketPath}",
                        "dest": ${configV2rayVmesWSPort},
                        "xver": 1
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "xtls",
                "xtlsSettings": {
                    "alpn": [
                        "http/1.1"
                    ],
                    "certificates": [
                        {
                            "certificateFile": "${configSSLCertPath}/$configSSLCertFullchainFilename",
                            "keyFile": "${configSSLCertPath}/$configSSLCertKeyFilename"
                        }
                    ]
                }
            }
        },
        {
            "port": ${configV2rayVmesWSPort},
            "listen": "127.0.0.1",
            "protocol": "vless",
            "settings": {
                "clients": [
                    ${v2rayConfigUserpasswordInput}
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                    "acceptProxyProtocol": true,
                    "path": "/${configV2rayWebSocketPath}" 
                }
            }
        }
        ${v2rayConfigAdditionalPortInput}
    ],
    ${v2rayConfigOutboundInput}
}
EOF

    fi



    # 增加 V2ray启动脚本
    if [ "$isXray" = "no" ] ; then
    
        cat > ${osSystemMdPath}v2ray.service <<-EOF
[Unit]
Description=V2Ray
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
Type=simple
# This service runs as root. You may consider to run it as another user for security concerns.
# By uncommenting User=nobody and commenting out User=root, the service will run as user nobody.
# More discussion at https://github.com/v2ray/v2ray-core/issues/1011
User=root
#User=nobody
#CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=${configV2rayPath}/v2ray -config ${configV2rayPath}/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF
    else
        cat > ${osSystemMdPath}xray.service <<-EOF
[Unit]
Description=Xray
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
Type=simple
# This service runs as root. You may consider to run it as another user for security concerns.
# By uncommenting User=nobody and commenting out User=root, the service will run as user nobody.
# More discussion at https://github.com/v2ray/v2ray-core/issues/1011
User=root
#User=nobody
#CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=${configV2rayPath}/xray run -config ${configV2rayPath}/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF
    fi

    ${sudoCmd} chmod +x ${configV2rayPath}/${promptInfoXrayName}
    ${sudoCmd} chmod +x ${osSystemMdPath}${promptInfoXrayName}.service
    ${sudoCmd} systemctl daemon-reload
    
    ${sudoCmd} systemctl enable ${promptInfoXrayName}.service
    ${sudoCmd} systemctl restart ${promptInfoXrayName}.service



    # 增加客户端配置说明
    if [[ ${isInstallNginx} != "true" ]]; then
        if [[ -z "$configV2rayVlessMode" ]]; then
                        
            configV2rayIsTlsShowInfo="none"
        fi
    fi


    # https://stackoverflow.com/questions/296536/how-to-urlencode-data-for-curl-command

    rawurlencode() {
        local string="${1}"
        local strlen=${#string}
        local encoded=""
        local pos c o

        for (( pos=0 ; pos<strlen ; pos++ )); do
            c=${string:$pos:1}
            case "$c" in
                [-_.~a-zA-Z0-9] ) o="${c}" ;;
                * )               printf -v o '%%%02x' "'$c"
            esac
            encoded+="${o}"
        done
        echo
        green "URL Encoded: ${encoded}"    # You can either set a return variable (FASTER) 
        v2rayPassUrl="${encoded}"   #+or echo the result (EASIER)... or both... :p
    }

    rawurlencode "${v2rayPassword1}"

    base64VmessLink=$(echo -n '{"port":"'${configV2rayPortShowInfo}'","ps":'${configSSLDomain}',"tls":"tls","id":'"${v2rayPassword1}"',"aid":"1","v":"2","host":"'${configSSLDomain}'","type":"none","path":"/'${configV2rayWebSocketPath}'","net":"ws","add":"'${configSSLDomain}'","allowInsecure":0,"method":"none","peer":"'${configSSLDomain}'"}' | sed 's#/#\\\/#g' | base64)
    base64VmessLink2=$(echo ${base64VmessLink} | sed 's/ //g')






    if [[ "$configV2rayWSorGrpc" == "grpc" ]]; then
        cat > ${configV2rayPath}/clientConfig.json <<-EOF
=========== ${promptInfoXrayInstall}客户端配置参数 =============
{
    协议: ${configV2rayProtocol},
    地址: ${configSSLDomain},
    端口: ${configV2rayPortGRPCShowInfo},
    uuid: ${v2rayPassword1},
    额外id: 0,  // AlterID 如果是Vless协议则不需要该项
    加密方式: aes-128-gcm,  // 如果是Vless协议则为none
    传输协议: gRPC,
    gRPC serviceName: ${configV2rayGRPCServiceName},
    底层传输协议:${configV2rayIsTlsShowInfo},
    别名:自己起个任意名称
}

导入链接 Vless (grpc导入链接可能不正常, 导入后可能需要手动修改):
${configV2rayProtocol}://${v2rayPassUrl}@${configSSLDomain}:${configV2rayPortGRPCShowInfo}?encryption=none&security=${configV2rayIsTlsShowInfo}&type=grpc&serviceName=${configV2rayGRPCServiceName}&host=${configSSLDomain}&headerType=none#${configSSLDomain}+gRPC%E5%8D%8F%E8%AE%AE

EOF

    elif [[ "$configV2rayWSorGrpc" == "wsgrpc" ]]; then
        cat > ${configV2rayPath}/clientConfig.json <<-EOF
=========== ${promptInfoXrayInstall} 客户端配置参数 =============
{
    协议: ${configV2rayProtocol},
    地址: ${configSSLDomain},
    端口: ${configV2rayPortShowInfo},
    uuid: ${v2rayPassword1},
    额外id: 0,  // AlterID 如果是Vless协议则不需要该项
    加密方式: aes-128-gcm,  // 如果是Vless协议则为none
    传输协议: websocket,
    websocket路径:/${configV2rayWebSocketPath},
    底层传输协议:${configV2rayIsTlsShowInfo},
    别名:自己起个任意名称
}

导入链接 Vless:
${configV2rayProtocol}://${v2rayPassUrl}@${configSSLDomain}:${configV2rayPortShowInfo}?encryption=none&security=${configV2rayIsTlsShowInfo}&type=ws&path=%2f${configV2rayWebSocketPath}&host=${configSSLDomain}&headerType=none#${configSSLDomain}+ws%E5%8D%8F%E8%AE%AE

导入链接 Vmess:
vmess://${base64VmessLink2}


=========== ${promptInfoXrayInstall} gRPC 客户端配置参数 =============
{
    协议: ${configV2rayProtocol},
    地址: ${configSSLDomain},
    端口: ${configV2rayPortGRPCShowInfo},
    uuid: ${v2rayPassword1},
    额外id: 0,  // AlterID 如果是Vless协议则不需要该项
    加密方式: aes-128-gcm,  // 如果是Vless协议则为none
    传输协议: gRPC,
    gRPC serviceName: ${configV2rayGRPCServiceName},
    底层传输协议:${configV2rayIsTlsShowInfo},
    别名:自己起个任意名称
}

导入链接 Vless (grpc导入链接可能不正常, 导入后可能需要手动修改):
${configV2rayProtocol}://${v2rayPassUrl}@${configSSLDomain}:${configV2rayPortGRPCShowInfo}?encryption=none&security=${configV2rayIsTlsShowInfo}&type=grpc&serviceName=${configV2rayGRPCServiceName}&host=${configSSLDomain}&headerType=none#${configSSLDomain}+gRPC%E5%8D%8F%E8%AE%AE

EOF

    else
        cat > ${configV2rayPath}/clientConfig.json <<-EOF
=========== ${promptInfoXrayInstall}客户端配置参数 =============
{
    协议: ${configV2rayProtocol},
    地址: ${configSSLDomain},
    端口: ${configV2rayPortShowInfo},
    uuid: ${v2rayPassword1},
    额外id: 0,  // AlterID 如果是Vless协议则不需要该项
    加密方式: aes-128-gcm,  // 如果是Vless协议则为none
    传输协议: websocket,
    websocket路径:/${configV2rayWebSocketPath},
    底层传输协议:${configV2rayIsTlsShowInfo},
    别名:自己起个任意名称
}

导入链接 Vless:
${configV2rayProtocol}://${v2rayPassUrl}@${configSSLDomain}:${configV2rayPortShowInfo}?encryption=none&security=${configV2rayIsTlsShowInfo}&type=ws&path=%2f${configV2rayWebSocketPath}&host=${configSSLDomain}&headerType=none#${configSSLDomain}+ws%E5%8D%8F%E8%AE%AE

导入链接 Vmess:
vmess://${base64VmessLink2}

EOF

    fi





    if [[ "$configV2rayVlessMode" == "vmessws" ]]; then

        base64VmessLink=$(echo -n '{"port":"'${configV2rayPort}'","ps":'${configSSLDomain}',"tls":"tls","id":'"${v2rayPassword1}"',"aid":"1","v":"2","host":"'${configSSLDomain}'","type":"none","path":"/'${configV2rayWebSocketPath}'","net":"ws","add":"'${configSSLDomain}'","allowInsecure":0,"method":"none","peer":"'${configSSLDomain}'"}' | sed 's#/#\\\/#g' | base64)
        base64VmessLink2=$(echo ${base64VmessLink} | sed 's/ //g')

        base64VmessLinkTCP=$(echo -n '{"port":"'${configV2rayPort}'","ps":'${configSSLDomain}',"tls":"tls","id":'"${v2rayPassword1}"',"aid":"1","v":"2","host":"'${configSSLDomain}'","type":"none","path":"/tcp'${configV2rayWebSocketPath}'","net":"tcp","add":"'${configSSLDomain}'","allowInsecure":0,"method":"none","peer":"'${configSSLDomain}'"}' | sed 's#/#\\\/#g' | base64)
        base64VmessLinkTCP2=$(echo ${base64VmessLinkTCP} | sed 's/ //g')


        cat > ${configV2rayPath}/clientConfig.json <<-EOF

只安装v2ray VLess运行在443端口 (VLess-TCP-TLS) + (VMess-TCP-TLS) + (VMess-WS-TLS)  支持CDN, 不安装nginx

=========== ${promptInfoXrayInstall}客户端 VLess-TCP-TLS 配置参数 =============
{
    协议: VLess,
    地址: ${configSSLDomain},
    端口: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    额外id: 0,  // AlterID 如果是Vless协议则不需要该项
    加密方式: none,  // 如果是Vless协议则为none
    传输协议: tcp ,
    websocket路径:无,
    底层传输:tls,
    别名:自己起个任意名称
}

导入链接:
vless://${v2rayPassUrl}@${configSSLDomain}:${configV2rayPort}?encryption=none&security=tls&type=tcp&host=${configSSLDomain}&headerType=none#${configSSLDomain}


=========== ${promptInfoXrayInstall}客户端 VMess-WS-TLS 配置参数 支持CDN =============
{
    协议: VMess,
    地址: ${configSSLDomain},
    端口: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    额外id: 0,  // AlterID 如果是Vless协议则不需要该项
    加密方式: auto,  // 如果是Vless协议则为none
    传输协议: websocket,
    websocket路径:/${configV2rayWebSocketPath},
    底层传输:tls,
    别名:自己起个任意名称
}

导入链接 Vmess:
vmess://${base64VmessLink2}

导入链接新版:
vmess://${v2rayPassUrl}@${configSSLDomain}:${configV2rayPort}?encryption=auto&security=tls&type=ws&host=${configSSLDomain}&path=%2f${configV2rayWebSocketPath}#${configSSLDomain}+ws%E5%8D%8F%E8%AE%AE



=========== ${promptInfoXrayInstall}客户端 VMess-TCP-TLS 配置参数 支持CDN =============
{
    协议: VMess,
    地址: ${configSSLDomain},
    端口: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    额外id: 0,  // AlterID 如果是Vless协议则不需要该项
    加密方式: auto,  // 如果是Vless协议则为none
    传输协议: tcp,
    路径:/tcp${configV2rayWebSocketPath},
    底层传输:tls,
    别名:自己起个任意名称
}

导入链接 Vmess:
vmess://${base64VmessLinkTCP2}

导入链接新版:
vmess://${v2rayPassUrl}@${configSSLDomain}:${configV2rayPort}?encryption=auto&security=tls&type=tcp&host=${configSSLDomain}&path=%2ftcp${configV2rayWebSocketPath}#${configSSLDomain}


EOF
    fi



    if [[ "$configV2rayVlessMode" == "vlessws" ]]; then

    cat > ${configV2rayPath}/clientConfig.json <<-EOF
只安装v2ray VLess运行在443端口 (VLess-TCP-TLS) + (VLess-WS-TLS) 支持CDN, 不安装nginx

=========== ${promptInfoXrayInstall}客户端 VLess-TCP-TLS 配置参数 =============
{
    协议: VLess,
    地址: ${configSSLDomain},
    端口: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    额外id: 0,  // AlterID 如果是Vless协议则不需要该项
    流控flow: 空
    加密方式: none, 
    传输协议: tcp ,
    websocket路径:无,
    底层传输协议:tls,   
    别名:自己起个任意名称
}

导入链接:
vless://${v2rayPassUrl}@${configSSLDomain}:${configV2rayPort}?encryption=none&security=tls&type=tcp&host=${configSSLDomain}&headerType=none#${configSSLDomain}


=========== ${promptInfoXrayInstall}客户端 VLess-WS-TLS 配置参数 支持CDN =============
{
    协议: VLess,
    地址: ${configSSLDomain},
    端口: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    额外id: 0,  // AlterID 如果是Vless协议则不需要该项
    流控flow: 空,
    加密方式: none,  
    传输协议: websocket,
    websocket路径:/${configV2rayWebSocketPath},
    底层传输:tls,     
    别名:自己起个任意名称
}

导入链接:
vless://${v2rayPassUrl}@${configSSLDomain}:${configV2rayPort}?encryption=none&security=tls&type=ws&host=${configSSLDomain}&path=%2f${configV2rayWebSocketPath}#${configSSLDomain}+ws%E5%8D%8F%E8%AE%AE

EOF
    fi



    if [[ "$configV2rayVlessMode" == "vlessgrpc" ]]; then

    cat > ${configV2rayPath}/clientConfig.json <<-EOF
只安装v2ray VLess运行在443端口 (VLess-gRPC-TLS) 支持CDN, 不安装nginx

=========== ${promptInfoXrayInstall}客户端 VLess-gRPC-TLS 配置参数 支持CDN =============
{
    协议: VLess,
    地址: ${configSSLDomain},
    端口: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    额外id: 0,  // AlterID 如果是Vless协议则不需要该项
    流控flow:  空,
    加密方式: none,  
    传输协议: gRPC,
    gRPC serviceName: ${configV2rayGRPCServiceName},
    底层传输:tls,     
    别名:自己起个任意名称
}


导入链接 Vless (grpc导入链接可能不正常, 导入后可能需要手动修改):
vless://${v2rayPassUrl}@${configSSLDomain}:${configV2rayPort}?encryption=none&security=tls&type=grpc&serviceName=${configV2rayGRPCServiceName}&host=${configSSLDomain}#${configSSLDomain}+gRPC%E5%8D%8F%E8%AE%AE


EOF
    fi




    if [[ "$configV2rayVlessMode" == "vlessxtlsws" ]] || [[ "$configV2rayVlessMode" == "trojan" ]]; then
        cat > ${configV2rayPath}/clientConfig.json <<-EOF
=========== ${promptInfoXrayInstall}客户端 VLess-TCP-TLS 配置参数 =============
{
    协议: VLess,
    地址: ${configSSLDomain},
    端口: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    额外id: 0,  // AlterID 如果是Vless协议则不需要该项
    流控flow: xtls-rprx-direct
    加密方式: none,  // 如果是Vless协议则为none
    传输协议: tcp ,
    websocket路径:无,
    底层传输协议:xtls, 
    别名:自己起个任意名称
}

导入链接:
vless://${v2rayPassUrl}@${configSSLDomain}:${configV2rayPort}?encryption=none&security=xtls&type=tcp&host=${configSSLDomain}&headerType=none&flow=xtls-rprx-direct#${configSSLDomain}


=========== ${promptInfoXrayInstall}客户端 VLess-WS-TLS 配置参数 支持CDN =============
{
    协议: VLess,
    地址: ${configSSLDomain},
    端口: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    额外id: 0,  // AlterID 如果是Vless协议则不需要该项
    流控flow: 空
    加密方式: none,  // 如果是Vless协议则为none
    传输协议: websocket,
    websocket路径:/${configV2rayWebSocketPath},
    底层传输:tls,     
    别名:自己起个任意名称
}

导入链接:
vless://${v2rayPassUrl}@${configSSLDomain}:${configV2rayPort}?encryption=none&security=tls&type=ws&host=${configSSLDomain}&path=%2f${configV2rayWebSocketPath}#${configSSLDomain}+ws%E5%8D%8F%E8%AE%AE

EOF
    fi



    if [[ "$configV2rayVlessMode" == "vlessxtlstrojan" ]]; then
    cat > ${configV2rayPath}/clientConfig.json <<-EOF
=========== ${promptInfoXrayInstall}客户端 VLess-TCP-TLS 配置参数 =============
{
    协议: VLess,
    地址: ${configSSLDomain},
    端口: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    额外id: 0,  // AlterID 如果是Vless协议则不需要该项
    流控flow: xtls-rprx-direct
    加密方式: none,  
    传输协议: tcp ,
    websocket路径:无,
    底层传输协议:xtls, 
    别名:自己起个任意名称
}

导入链接:
vless://${v2rayPassUrl}@${configSSLDomain}:${configV2rayPort}?encryption=none&security=xtls&type=tcp&host=${configSSLDomain}&headerType=none&flow=xtls-rprx-direct#${configSSLDomain}


=========== ${promptInfoXrayInstall}客户端 VLess-WS-TLS 配置参数 支持CDN =============
{
    协议: VLess,
    地址: ${configSSLDomain},
    端口: ${configV2rayPort},
    uuid: ${v2rayPassword1},
    额外id: 0,  // AlterID 如果是Vless协议则不需要该项
    流控flow: 空, 
    加密方式: none,  
    传输协议: websocket,
    websocket路径:/${configV2rayWebSocketPath},
    底层传输:tls,     
    别名:自己起个任意名称
}

导入链接:
vless://${v2rayPassUrl}@${configSSLDomain}:${configV2rayPort}?encryption=none&security=tls&type=ws&host=${configSSLDomain}&path=%2f${configV2rayWebSocketPath}#${configSSLDomain}+ws%E5%8D%8F%E8%AE%AE



Trojan${promptInfoTrojanName}服务器地址: ${configSSLDomain}  端口: $configV2rayTrojanPort

密码1: ${trojanPassword1}
密码2: ${trojanPassword2}
密码3: ${trojanPassword3}
密码4: ${trojanPassword4}
密码5: ${trojanPassword5}
密码6: ${trojanPassword6}
密码7: ${trojanPassword7}
密码8: ${trojanPassword8}
密码9: ${trojanPassword9}
密码10: ${trojanPassword10}
您指定前缀的密码共20个: 从 ${configTrojanPasswordPrefixInput}202001 到 ${configTrojanPasswordPrefixInput}202020 都可以使用
例如: 密码:${configTrojanPasswordPrefixInput}202002 或 密码:${configTrojanPasswordPrefixInput}202019 都可以使用


小火箭链接:
trojan://${trojanPassword1}@${configSSLDomain}:${configV2rayTrojanPort}?peer=${configSSLDomain}&sni=${configSSLDomain}#${configSSLDomain}_trojan

二维码 Trojan${promptInfoTrojanName}
https://api.qrserver.com/v1/create-qr-code/?size=400x400&data=trojan%3a%2f%2f${trojanPassword1}%40${configSSLDomain}%3a${configV2rayTrojanPort}%3fpeer%3d${configSSLDomain}%26sni%3d${configSSLDomain}%23${configSSLDomain}_trojan


EOF
    fi



    # 设置 cron 定时任务
    # https://stackoverflow.com/questions/610839/how-can-i-programmatically-create-a-new-cron-job

    (crontab -l ; echo "20 4 * * 0,1,2,3,4,5,6 systemctl restart ${promptInfoXrayName}.service") | sort - | uniq - | crontab -


    green "======================================================================"
    green "    ${promptInfoXrayInstall} Version: ${promptInfoXrayVersion} 安装成功 !"

    if [[ ${isInstallNginx} == "true" ]]; then
        green "    伪装站点为 https://${configSSLDomain}!"
	    green "    伪装站点的静态html内容放置在目录 ${configWebsitePath}, 可自行更换网站内容!"
    fi
	
	red "    ${promptInfoXrayInstall} 服务器端配置路径 ${configV2rayPath}/config.json !"
	green "    ${promptInfoXrayInstall} 访问日志 ${configV2rayAccessLogFilePath} !"
	green "    ${promptInfoXrayInstall} 错误日志 ${configV2rayErrorLogFilePath} ! "
	green "    ${promptInfoXrayInstall} 查看日志命令: journalctl -n 50 -u ${promptInfoXrayName}.service "
	green "    ${promptInfoXrayInstall} 停止命令: systemctl stop ${promptInfoXrayName}.service  启动命令: systemctl start ${promptInfoXrayName}.service  重启命令: systemctl restart ${promptInfoXrayName}.service"
	green "    ${promptInfoXrayInstall} 查看运行状态命令:  systemctl status ${promptInfoXrayName}.service "
	green "    ${promptInfoXrayInstall} 服务器 每天会自动重启, 防止内存泄漏. 运行 crontab -l 命令 查看定时重启命令 !"
	green "======================================================================"
	echo ""
	yellow "${promptInfoXrayInstall} 配置信息如下, 请自行复制保存, 密码任选其一 (密码即用户ID或UUID) !!"
	yellow "服务器地址: ${configSSLDomain}  端口: ${configV2rayPortShowInfo}"
	yellow "用户ID或密码1: ${v2rayPassword1}"
	yellow "用户ID或密码2: ${v2rayPassword2}"
	yellow "用户ID或密码3: ${v2rayPassword3}"
	yellow "用户ID或密码4: ${v2rayPassword4}"
	yellow "用户ID或密码5: ${v2rayPassword5}"
	yellow "用户ID或密码6: ${v2rayPassword6}"
	yellow "用户ID或密码7: ${v2rayPassword7}"
	yellow "用户ID或密码8: ${v2rayPassword8}"
	yellow "用户ID或密码9: ${v2rayPassword9}"
	yellow "用户ID或密码10: ${v2rayPassword10}"
    echo ""
	cat "${configV2rayPath}/clientConfig.json"
	echo ""
    green "======================================================================"
    green "请下载相应的 ${promptInfoXrayName} 客户端:"
    yellow "1 Windows 客户端V2rayN下载：http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/v2ray-windows.zip"
    yellow "2 MacOS 客户端下载：http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/v2ray-mac.zip"
    yellow "3 Android 客户端下载 https://github.com/2dust/v2rayNG/releases"
    #yellow "3 Android 客户端下载 http://${configSSLDomain}/download/${configTrojanWindowsCliPrefixPath}/v2ray-android.zip"
    yellow "4 iOS 客户端 请安装小火箭 https://shadowsockshelp.github.io/ios/ "
    yellow "  iOS 请安装小火箭另一个地址 https://lueyingpro.github.io/shadowrocket/index.html "
    yellow "  iOS 安装小火箭遇到问题 教程 https://github.com/shadowrocketHelp/help/ "
    yellow "其他客户端程序请看 https://www.v2fly.org/awesome/tools.html "
    green "======================================================================"

    cat >> ${configReadme} <<-EOF




${promptInfoXrayInstall} Version: ${promptInfoXrayVersion} 安装成功 ! 
${promptInfoXrayInstall} 服务器端配置路径 ${configV2rayPath}/config.json 

${promptInfoXrayInstall} 访问日志 ${configV2rayAccessLogFilePath}
${promptInfoXrayInstall} 错误日志 ${configV2rayErrorLogFilePath}

${promptInfoXrayInstall} 查看日志命令: journalctl -n 50 -u ${promptInfoXrayName}.service

${promptInfoXrayInstall} 启动命令: systemctl start ${promptInfoXrayName}.service  
${promptInfoXrayInstall} 停止命令: systemctl stop ${promptInfoXrayName}.service  
${promptInfoXrayInstall} 重启命令: systemctl restart ${promptInfoXrayName}.service
${promptInfoXrayInstall} 查看运行状态命令:  systemctl status ${promptInfoXrayName}.service 

${promptInfoXrayInstall} 配置信息如下, 请自行复制保存, 密码任选其一 (密码即用户ID或UUID) !

服务器地址: ${configSSLDomain}  
端口: ${configV2rayPortShowInfo}
用户ID或密码1: ${v2rayPassword1}
用户ID或密码2: ${v2rayPassword2}
用户ID或密码3: ${v2rayPassword3}
用户ID或密码4: ${v2rayPassword4}
用户ID或密码5: ${v2rayPassword5}
用户ID或密码6: ${v2rayPassword6}
用户ID或密码7: ${v2rayPassword7}
用户ID或密码8: ${v2rayPassword8}
用户ID或密码9: ${v2rayPassword9}
用户ID或密码10: ${v2rayPassword10}



EOF

    cat "${configV2rayPath}/clientConfig.json" >> ${configReadme}
}
    

function removeV2ray(){
    if [ -f "${configV2rayPath}/xray" ]; then
        promptInfoXrayName="xray"
        isXray="yes"
    fi

    echo
    green " ================================================== "
    red " 准备卸载已安装 ${promptInfoXrayName} "
    green " ================================================== "
    echo

    ${sudoCmd} systemctl stop ${promptInfoXrayName}.service
    ${sudoCmd} systemctl disable ${promptInfoXrayName}.service


    rm -rf ${configV2rayPath}
    rm -f ${osSystemMdPath}${promptInfoXrayName}.service
    rm -f ${configV2rayAccessLogFilePath}
    rm -f ${configV2rayErrorLogFilePath}

    echo
    green " ================================================== "
    green "  ${promptInfoXrayName} 卸载完毕 !"
    green " ================================================== "
    echo
}


function upgradeV2ray(){
    if [ -f "${configV2rayPath}/xray" ]; then
        promptInfoXrayName="xray"
        isXray="yes"
    fi

    if [ "$isXray" = "no" ] ; then
        getTrojanAndV2rayVersion "v2ray"
        green " =================================================="
        green "       开始升级 V2ray Version: ${versionV2ray} !"
        green " =================================================="
    else
        getTrojanAndV2rayVersion "xray"
        green " =================================================="
        green "       开始升级 Xray Version: ${versionXray} !"
        green " =================================================="
    fi



    ${sudoCmd} systemctl stop ${promptInfoXrayName}.service

    mkdir -p ${configDownloadTempPath}/upgrade/${promptInfoXrayName}

    if [ "$isXray" = "no" ] ; then
        downloadAndUnzip "https://github.com/v2fly/v2ray-core/releases/download/v${versionV2ray}/${downloadFilenameV2ray}" "${configDownloadTempPath}/upgrade/${promptInfoXrayName}" "${downloadFilenameV2ray}"
        mv -f ${configDownloadTempPath}/upgrade/${promptInfoXrayName}/v2ctl ${configV2rayPath}
    else
        downloadAndUnzip "https://github.com/XTLS/Xray-core/releases/download/v${versionXray}/${downloadFilenameXray}" "${configDownloadTempPath}/upgrade/${promptInfoXrayName}" "${downloadFilenameXray}"
    fi

    mv -f ${configDownloadTempPath}/upgrade/${promptInfoXrayName}/${promptInfoXrayName} ${configV2rayPath}
    mv -f ${configDownloadTempPath}/upgrade/${promptInfoXrayName}/geoip.dat ${configV2rayPath}
    mv -f ${configDownloadTempPath}/upgrade/${promptInfoXrayName}/geosite.dat ${configV2rayPath}

    ${sudoCmd} chmod +x ${configV2rayPath}/${promptInfoXrayName}
    ${sudoCmd} systemctl start ${promptInfoXrayName}.service


    if [ "$isXray" = "no" ] ; then
        green " ================================================== "
        green "     升级成功 V2ray Version: ${versionV2ray} !"
        green " ================================================== "
    else
        getTrojanAndV2rayVersion "xray"
        green " =================================================="
        green "     升级成功 Xray Version: ${versionXray} !"
        green " =================================================="
    fi
}













































function installTrojanWeb(){
    # wget -O trojan-web_install.sh -N --no-check-certificate "https://raw.githubusercontent.com/Jrohy/trojan/master/install.sh" && chmod +x trojan-web_install.sh && ./trojan-web_install.sh

    if [ -f "${configTrojanWebPath}/trojan-web" ] ; then
        green " =================================================="
        green "  已安装过 Trojan-web 可视化管理面板, 退出安装 !"
        green " =================================================="
        exit
    fi

    stopServiceNginx
    testLinuxPortUsage
    installPackage

    green " ================================================== "
    yellow " 请输入绑定到本VPS的域名 例如www.xxx.com: (此步骤请关闭CDN后安装)"
    green " ================================================== "

    read configSSLDomain
    if compareRealIpWithLocalIp "${configSSLDomain}" ; then

        getTrojanAndV2rayVersion "trojan-web"
        green " =================================================="
        green "    开始安装 Trojan-web 可视化管理面板: ${versionTrojanWeb} !"
        green " =================================================="


        mkdir -p ${configTrojanWebPath}
        wget -O ${configTrojanWebPath}/trojan-web --no-check-certificate "https://github.com/Jrohy/trojan/releases/download/v${versionTrojanWeb}/${downloadFilenameTrojanWeb}"
        chmod +x ${configTrojanWebPath}/trojan-web


        # 增加启动脚本
        cat > ${osSystemMdPath}trojan-web.service <<-EOF
[Unit]
Description=trojan-web
Documentation=https://github.com/Jrohy/trojan
After=network.target network-online.target nss-lookup.target mysql.service mariadb.service mysqld.service docker.service

[Service]
Type=simple
StandardError=journal
ExecStart=${configTrojanWebPath}/trojan-web web -p ${configTrojanWebPort}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF

        ${sudoCmd} systemctl daemon-reload
        ${sudoCmd} systemctl enable trojan-web.service
        ${sudoCmd} systemctl start trojan-web.service

        green " =================================================="
        green " Trojan-web 可视化管理面板: ${versionTrojanWeb} 安装成功!"
        green " Trojan可视化管理面板地址 https://${configSSLDomain}/${configTrojanWebNginxPath}"
        green " 开始运行命令 ${configTrojanWebPath}/trojan-web 进行初始化设置."
        green " =================================================="



        ${configTrojanWebPath}/trojan-web

        installWebServerNginx "trojan-web"

        # 命令补全环境变量
        echo "export PATH=$PATH:${configTrojanWebPath}" >> ${HOME}/.${osSystemShell}rc

        # (crontab -l ; echo '25 0 * * * "${configSSLAcmeScriptPath}"/acme.sh --cron --home "${configSSLAcmeScriptPath}" > /dev/null') | sort - | uniq - | crontab -
        (crontab -l ; echo "30 4 * * 0,1,2,3,4,5,6 systemctl restart trojan-web.service") | sort - | uniq - | crontab -

    else
        exit
    fi
}


function removeTrojanWeb(){
    # wget -O trojan-web_install.sh -N --no-check-certificate "https://raw.githubusercontent.com/Jrohy/trojan/master/install.sh" && chmod +x trojan-web_install.sh && ./trojan-web_install.sh --remove

    green " ================================================== "
    red " 准备卸载已安装 Trojan-web "
    green " ================================================== "

    ${sudoCmd} systemctl stop trojan.service
    ${sudoCmd} systemctl stop trojan-web.service
    ${sudoCmd} systemctl disable trojan-web.service
    

    # 移除trojan
    rm -rf /usr/bin/trojan
    rm -rf /usr/local/etc/trojan
    rm -f ${osSystemMdPath}trojan.service
    rm -f /etc/systemd/system/trojan.service
    rm -f /usr/local/etc/trojan/config.json


    # 移除trojan web 管理程序 
    # rm -f /usr/local/bin/trojan
    rm -rf ${configTrojanWebPath}
    rm -f ${osSystemMdPath}trojan-web.service
    rm -rf /var/lib/trojan-manager

    ${sudoCmd} systemctl daemon-reload


    # 移除trojan的专用数据库
    docker rm -f trojan-mysql
    docker rm -f trojan-mariadb
    rm -rf /home/mysql
    rm -rf /home/mariadb


    # 移除环境变量
    sed -i '/trojan/d' ${HOME}/.${osSystemShell}rc
    # source ${HOME}/.${osSystemShell}rc

    crontab -r

    green " ================================================== "
    green "  Trojan-web 卸载完毕 !"
    green " ================================================== "
}

function upgradeTrojanWeb(){
    getTrojanAndV2rayVersion "trojan-web"
    green " =================================================="
    green "    开始升级 Trojan-web 可视化管理面板: ${versionTrojanWeb} !"
    green " =================================================="

    ${sudoCmd} systemctl stop trojan-web.service

    mkdir -p ${configDownloadTempPath}/upgrade/trojan-web

    wget -O ${configDownloadTempPath}/upgrade/trojan-web/trojan-web "https://github.com/Jrohy/trojan/releases/download/v${versionTrojanWeb}/${downloadFilenameTrojanWeb}"
    mv -f ${configDownloadTempPath}/upgrade/trojan-web/trojan-web ${configTrojanWebPath}
    chmod +x ${configTrojanWebPath}/trojan-web

    ${sudoCmd} systemctl start trojan-web.service
    ${sudoCmd} systemctl restart trojan.service


    green " ================================================== "
    green "     升级成功 Trojan-web 可视化管理面板: ${versionTrojanWeb} !"
    green " ================================================== "
}
function runTrojanWebSSL(){
    ${sudoCmd} systemctl stop trojan-web.service
    ${sudoCmd} systemctl stop nginx.service
    ${sudoCmd} systemctl stop trojan.service
    ${configTrojanWebPath}/trojan-web tls
    ${sudoCmd} systemctl start trojan-web.service
    ${sudoCmd} systemctl start nginx.service
    ${sudoCmd} systemctl restart trojan.service
}
function runTrojanWebLog(){
    ${configTrojanWebPath}/trojan-web
}








function installV2rayUI(){

    stopServiceNginx
    testLinuxPortUsage
    installPackage

    green " ================================================== "
    yellow " 请输入绑定到本VPS的域名 例如www.xxx.com: (此步骤请关闭CDN后安装)"
    green " ================================================== "

    read configSSLDomain
    if compareRealIpWithLocalIp "${configSSLDomain}" ; then

        green " =================================================="
        green "    开始安装 V2ray-UI 可视化管理面板 !"
        green " =================================================="

        wget -O v2_ui_install.sh -N --no-check-certificate "https://raw.githubusercontent.com/sprov065/v2-ui/master/install.sh" && chmod +x v2_ui_install.sh && ./v2_ui_install.sh

        green " V2ray-UI 可视化管理面板地址 http://${configSSLDomain}:65432"
        green " 请确保 65432 端口已经放行, 例如检查linux防火墙或VPS防火墙 65432 端口是否开启"
        green " V2ray-UI 可视化管理面板 默认管理员用户 admin 密码 admin, 为保证安全,请登陆后尽快修改默认密码 "
        green " =================================================="

    else
        exit
    fi
}
function removeV2rayUI(){
    green " =================================================="
    /usr/bin/v2-ui
}
function upgradeV2rayUI(){
    green " =================================================="
    /usr/bin/v2-ui
}















function getHTTPSNoNgix(){
    #stopServiceNginx
    #testLinuxPortUsage

    installPackage

    green " ================================================== "
    yellow " 请输入绑定到本VPS的域名 例如www.xxx.com: (此步骤请关闭CDN后和nginx后安装 避免80端口占用导致申请证书失败)"
    green " ================================================== "

    read configSSLDomain

    read -p "是否申请证书? 默认为自动申请证书,如果二次安装或已有证书可以选否 请输入[Y/n]:" isDomainSSLRequestInput
    isDomainSSLRequestInput=${isDomainSSLRequestInput:-Y}

    isInstallNginx="false"

    if compareRealIpWithLocalIp "${configSSLDomain}" ; then
        if [[ $isDomainSSLRequestInput == [Yy] ]]; then
            getHTTPSCertificate "standalone"

        else
            green " =================================================="
            green "   不申请域名的证书, 请把证书放到如下目录, 或自行修改trojan或v2ray配置!"
            green " ${configSSLDomain} 域名证书内容文件路径 ${configSSLCertPath}/$configSSLCertFullchainFilename "
            green " ${configSSLDomain} 域名证书私钥文件路径 ${configSSLCertPath}/$configSSLCertKeyFilename "
            green " =================================================="
        fi
    else
        exit
    fi


    if test -s ${configSSLCertPath}/$configSSLCertFullchainFilename; then
        green " =================================================="
        green "   域名SSL证书申请成功 !"
        green " ${configSSLDomain} 域名证书内容文件路径 ${configSSLCertPath}/$configSSLCertFullchainFilename "
        green " ${configSSLDomain} 域名证书私钥文件路径 ${configSSLCertPath}/$configSSLCertKeyFilename "
        green " =================================================="

        if [[ $1 == "trojan" ]] ; then
            installTrojanServer

        elif [[ $1 == "both" ]] ; then
            installV2ray
            installTrojanServer
        else
            installV2ray
        fi        

    else
        red " ================================================== "
        red " https证书没有申请成功，安装失败!"
        red " 请检查域名和DNS是否生效, 同一域名请不要一天内多次申请!"
        red " 请检查80和443端口是否开启, VPS服务商可能需要添加额外防火墙规则，例如阿里云、谷歌云等!"
        red " 重启VPS, 重新执行脚本, 可重新选择该项再次申请证书 ! "
        red " ================================================== "
        exit
    fi



}


osInfo=""
osRelease=""
osReleaseVersion=""
osReleaseVersionNo=""
osReleaseVersionCodeName="CodeName"
osSystemPackage=""
osSystemMdPath=""
osSystemShell="bash"

osKernelVersionFull=$(uname -r)
osKernelVersionBackup=$(uname -r | awk -F "-" '{print $1}')
osKernelVersionShort=$(uname -r | cut -d- -f1 | awk -F "." '{print $1"."$2}')
osKernelBBRStatus=""
systemBBRRunningStatus="no"
systemBBRRunningStatusText=""



virt_check(){
	# if hash ifconfig 2>/dev/null; then
		# eth=$(ifconfig)
	# fi

	virtualx=$(dmesg) 2>/dev/null

    if  [ $(which dmidecode) ]; then
		sys_manu=$(dmidecode -s system-manufacturer) 2>/dev/null
		sys_product=$(dmidecode -s system-product-name) 2>/dev/null
		sys_ver=$(dmidecode -s system-version) 2>/dev/null
	else
		sys_manu=""
		sys_product=""
		sys_ver=""
	fi
	
	if grep docker /proc/1/cgroup -qa; then
	    virtual="Docker"
	elif grep lxc /proc/1/cgroup -qa; then
		virtual="Lxc"
	elif grep -qa container=lxc /proc/1/environ; then
		virtual="Lxc"
	elif [[ -f /proc/user_beancounters ]]; then
		virtual="OpenVZ"
	elif [[ "$virtualx" == *kvm-clock* ]]; then
		virtual="KVM"
	elif [[ "$cname" == *KVM* ]]; then
		virtual="KVM"
	elif [[ "$cname" == *QEMU* ]]; then
		virtual="KVM"
	elif [[ "$virtualx" == *"VMware Virtual Platform"* ]]; then
		virtual="VMware"
	elif [[ "$virtualx" == *"Parallels Software International"* ]]; then
		virtual="Parallels"
	elif [[ "$virtualx" == *VirtualBox* ]]; then
		virtual="VirtualBox"
	elif [[ -e /proc/xen ]]; then
		virtual="Xen"
	elif [[ "$sys_manu" == *"Microsoft Corporation"* ]]; then
		if [[ "$sys_product" == *"Virtual Machine"* ]]; then
			if [[ "$sys_ver" == *"7.0"* || "$sys_ver" == *"Hyper-V" ]]; then
				virtual="Hyper-V"
			else
				virtual="Microsoft Virtual Machine"
			fi
		fi
	else
		virtual="Dedicated母鸡"
	fi
}




function installSoftDownload(){
	if [[ "${osRelease}" == "debian" || "${osRelease}" == "ubuntu" ]]; then
        if [[ "${osRelease}" == "debian" ]]; then
            echo "deb http://deb.debian.org/debian buster-backports main contrib non-free" > /etc/apt/sources.list.d/buster-backports.list
            echo "deb-src http://deb.debian.org/debian buster-backports main contrib non-free" >> /etc/apt/sources.list.d/buster-backports.list
            ${sudoCmd} apt update
        fi

		if ! dpkg -l | grep -qw wget; then
			${osSystemPackage} -y install wget curl git
		fi

        if ! dpkg -l | grep -qw bc; then
			${osSystemPackage} -y install bc
            # https://stackoverflow.com/questions/11116704/check-if-vt-x-is-activated-without-having-to-reboot-in-linux
            ${osSystemPackage} -y install cpu-checker
		fi

        if ! dpkg -l | grep -qw ca-certificates; then
			${osSystemPackage} -y install ca-certificates dmidecode
            update-ca-certificates
		fi        

	elif [[ "${osRelease}" == "centos" ]]; then
		if ! rpm -qa | grep -qw wget; then
			${osSystemPackage} -y install wget curl git bc
		fi

        if ! rpm -qa | grep -qw bc; then
			${osSystemPackage} -y install bc
		fi

        # 处理ca证书
        if ! rpm -qa | grep -qw ca-certificates; then
			${osSystemPackage} -y install ca-certificates dmidecode
            update-ca-trust force-enable
		fi
	fi
    
}


function rebootSystem(){

    if [ -z $1 ]; then

        red "请检查上面的信息 是否有新内核版本, 老内核版本 ${osKernelVersionBackup} 是否已经卸载!"
        echo
        red "请注意检查 是否把新内核也误删卸载了, 无新内核 ${linuxKernelToInstallVersionFull} 不要重启, 可重新安装内核后再重启! "

    fi

    echo
	read -p "是否立即重启? 请输入[Y/n]?" isRebootInput
	isRebootInput=${isRebootInput:-Y}

	if [[ $isRebootInput == [Yy] ]]; then
		${sudoCmd} reboot
	else 
		exit
	fi
}

function promptContinueOpeartion(){
	read -p "是否继续操作? 直接回车默认继续操作, 请输入[Y/n]:" isContinueInput
	isContinueInput=${isContinueInput:-Y}

	if [[ $isContinueInput == [Yy] ]]; then
		echo ""
	else 
		exit
	fi
}

# https://stackoverflow.com/questions/4023830/how-to-compare-two-strings-in-dot-separated-version-format-in-bash
versionCompare () {
    if [[ $1 == $2 ]]; then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

versionCompareWithOp () {
    versionCompare $1 $2
    case $? in
        0) op='=';;
        1) op='>';;
        2) op='<';;
    esac
    if [[ $op != $3 ]]; then
        # echo "Version Number Compare Fail: Expected '$3', Actual '$op', Arg1 '$1', Arg2 '$2'"
        return 1
    else
        # echo "Version Number Compare Pass: '$1 $op $2'"
        return 0
    fi
}


function listAvailableLinuxKernel(){
    echo
    green " =================================================="
    green " 状态显示--当前可以被安装的 Linux 内核: "
    if [[ "${osRelease}" == "centos" ]]; then
		${sudoCmd} yum --disablerepo="*" --enablerepo="elrepo-kernel" list available | grep kernel
	else   
        if [ -z $1 ]; then
            ${sudoCmd} apt-cache search linux-image
        else
            ${sudoCmd} apt-cache search linux-image | grep $1
        fi
	fi
    
    green " =================================================="
    echo
}

function listInstalledLinuxKernel(){
    echo
    green " =================================================="
    green " 状态显示--当前已安装的 Linux 内核: "
    echo

	if [[ "${osRelease}" == "debian" || "${osRelease}" == "ubuntu" ]]; then
        dpkg --get-selections | grep linux-
		# dpkg -l | grep linux-
        # dpkg-query -l | grep linux-
        # apt list --installed | grep linux-
        echo
        red " 如安装内核遇到kernel linux-image linux-headers 版本不一致问题, 请手动卸载已安装的kernel" 
        red " 卸载内核命令 apt remove -y --purge linux-xxx名称"         

	elif [[ "${osRelease}" == "centos" ]]; then
        ${sudoCmd} rpm -qa | grep kernel
        echo
        red " 如安装内核遇到kernel kernel-headers kernel-devel版本不一致问题, 请手动卸载已安装的kernel" 
        red " 卸载内核命令 rpm --nodeps -e kernel-xxx名称" 
	fi
    green " =================================================="
    echo
}

function showLinuxKernelInfoNoDisplay(){

    isKernelSupportBBRVersion="4.9"

    if versionCompareWithOp "${isKernelSupportBBRVersion}" "${osKernelVersionShort}" ">"; then
        echo
    else 
        osKernelBBRStatus="BBR"
    fi

    if [[ ${osKernelVersionFull} == *bbrplus* ]]; then
        osKernelBBRStatus="BBR Plus"
    elif [[ ${osKernelVersionFull} == *xanmod* ]]; then
        osKernelBBRStatus="BBR 和 BBR2"
    fi

	net_congestion_control=`cat /proc/sys/net/ipv4/tcp_congestion_control | awk '{print $1}'`
	net_qdisc=`cat /proc/sys/net/core/default_qdisc | awk '{print $1}'`
	net_ecn=`cat /proc/sys/net/ipv4/tcp_ecn | awk '{print $1}'`

    if [[ ${osKernelVersionBackup} == *4.14.129* ]]; then
        # isBBREnabled=$(grep "net.ipv4.tcp_congestion_control" /etc/sysctl.conf | awk -F "=" '{print $2}')
        # isBBREnabled=$(sysctl net.ipv4.tcp_available_congestion_control | awk -F "=" '{print $2}')

        isBBRTcpEnabled=$(lsmod | grep "bbr" | awk '{print $1}')
        isBBRPlusTcpEnabled=$(lsmod | grep "bbrplus" | awk '{print $1}')
        isBBR2TcpEnabled=$(lsmod | grep "bbr2" | awk '{print $1}')
    else
        isBBRTcpEnabled=$(sysctl net.ipv4.tcp_congestion_control | grep "bbr" | awk -F "=" '{print $2}' | awk '{$1=$1;print}')
        isBBRPlusTcpEnabled=$(sysctl net.ipv4.tcp_congestion_control | grep "bbrplus" | awk -F "=" '{print $2}' | awk '{$1=$1;print}')
        isBBR2TcpEnabled=$(sysctl net.ipv4.tcp_congestion_control | grep "bbr2" | awk -F "=" '{print $2}' | awk '{$1=$1;print}')
    fi

    if [[ ${net_ecn} == "1" ]]; then
        systemECNStatusText="已开启"      
    elif [[ ${net_ecn} == "0" ]]; then
        systemECNStatusText="已关闭"   
    elif [[ ${net_ecn} == "2" ]]; then
        systemECNStatusText="只对入站请求开启(默认值)"       
    else
        systemECNStatusText="" 
    fi

    if [[ ${net_congestion_control} == "bbr" ]]; then
        
        if [[ ${isBBRTcpEnabled} == *"bbr"* ]]; then
            systemBBRRunningStatus="bbr"
            systemBBRRunningStatusText="BBR 已启动成功"            
        else 
            systemBBRRunningStatusText="BBR 启动失败"
        fi

    elif [[ ${net_congestion_control} == "bbrplus" ]]; then

        if [[ ${isBBRPlusTcpEnabled} == *"bbrplus"* ]]; then
            systemBBRRunningStatus="bbrplus"
            systemBBRRunningStatusText="BBR Plus 已启动成功"            
        else 
            systemBBRRunningStatusText="BBR Plus 启动失败"
        fi

    elif [[ ${net_congestion_control} == "bbr2" ]]; then

        if [[ ${isBBR2TcpEnabled} == *"bbr2"* ]]; then
            systemBBRRunningStatus="bbr2"
            systemBBRRunningStatusText="BBR2 已启动成功"            
        else 
            systemBBRRunningStatusText="BBR2 启动失败"
        fi
                
    else 
        systemBBRRunningStatusText="未启动加速模块"
    fi

}

function showLinuxKernelInfo(){
    
    # https://stackoverflow.com/questions/8654051/how-to-compare-two-floating-point-numbers-in-bash
    # https://stackoverflow.com/questions/229551/how-to-check-if-a-string-contains-a-substring-in-bash

    isKernelSupportBBRVersion="4.9"

    green " =================================================="
    green " 状态显示--当前Linux 内核版本: ${osKernelVersionShort} , $(uname -r) "

    if versionCompareWithOp "${isKernelSupportBBRVersion}" "${osKernelVersionShort}" ">"; then
        green "           当前系统内核低于4.9, 不支持开启 BBR "   
    else
        green "           当前系统内核高于4.9, 支持开启 BBR, ${systemBBRRunningStatusText}"
    fi

    if [[ ${osKernelVersionFull} == *xanmod* ]]; then
        green "           当前系统内核已支持开启 BBR2, ${systemBBRRunningStatusText}"
    else
        green "           当前系统内核不支持开启 BBR2"
    fi

    if [[ ${osKernelVersionFull} == *bbrplus* ]]; then
        green "           当前系统内核已支持开启 BBR Plus, ${systemBBRRunningStatusText}"
    else
        green "           当前系统内核不支持开启 BBR Plus"
    fi
    # sysctl net.ipv4.tcp_available_congestion_control 返回值 net.ipv4.tcp_available_congestion_control = bbr cubic reno 或 reno cubic bbr
    # sysctl net.ipv4.tcp_congestion_control 返回值 net.ipv4.tcp_congestion_control = bbr
    # sysctl net.core.default_qdisc 返回值 net.core.default_qdisc = fq
    # lsmod | grep bbr 返回值 tcp_bbr     20480  3  或 tcp_bbr                20480  1   注意：并不是所有的 VPS 都会有此返回值，若没有也属正常。

    # isFlagBbr=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')

    # if [[ (${isFlagBbr} == *"bbr"*)  &&  (${isFlagBbr} != *"bbrplus"*) && (${isFlagBbr} != *"bbr2"*) ]]; then
    #     green " 状态显示--是否开启BBR: 已开启 "
    # else
    #     green " 状态显示--是否开启BBR: 未开启 "
    # fi

    # if [[ ${isFlagBbr} == *"bbrplus"* ]]; then
    #     green " 状态显示--是否开启BBR Plus: 已开启 "
    # else
    #     green " 状态显示--是否开启BBR Plus: 未开启 "
    # fi
    
    # if [[ ${isFlagBbr} == *"bbr2"* ]]; then
    #     green " 状态显示--是否开启BBR2: 已开启 "
    # else
    #     green " 状态显示--是否开启BBR2: 未开启 "
    # fi

    green " =================================================="
    echo
}


function enableBBRSysctlConfig(){
    # https://hostloc.com/thread-644985-1-1.html
    # 优质线路用5.5+cake和原版bbr带宽跑的更足，不过cake的话就算高峰也不会像原版bbr那样跑不动，相比plus能慢些，但是区别不大，
    # bbr plus的话美西或者一些延迟高的，用起来更好，锐速针对丢包高的有奇效
    # 带宽大，并且延迟低不丢包的话5.5+cake在我这比较好，延迟高用plus更好，丢包多锐速最好. 一般130ms以下用cake不错，以上的话用plus更好些

    # https://github.com/xanmod/linux/issues/26
    # 说白了 bbrplus 就是改了点东西，然后那部分修改在 5.1 内核里合并进去了, 5.1 及以上的内核里自带的 bbr 已经包含了所谓的 bbrplus 的修改。
    # PS：bbr 是一直在修改的，比如说 5.0 内核的 bbr，4.15 内核的 bbr 和 4.9 内核的 bbr 其实都是不一样的

    # https://sysctl-explorer.net/net/ipv4/tcp_ecn/


    removeBbrSysctlConfig
    currentBBRText="bbr"
    currentQueueText="fq"
    currentECNValue="2"
    currentECNText=""

    if [ $1 = "bbrplus" ]; then
        currentBBRText="bbrplus"
        currentQueueText="fq"
    else
        echo
        echo " 请选择开启 (1) BBR 还是 (2) BBR2 网络加速 "
        red " 选择 1 BBR 需要内核在 4.9 以上"
        red " 选择 2 BBR2 需要内核为 XanMod "
        read -p "请选择? 直接回车默认选1 BBR, 请输入[1/2]:" BBRTcpInput
        BBRTcpInput=${BBRTcpInput:-1}
        if [[ $BBRTcpInput == [2] ]]; then
            if [[ ${osKernelVersionFull} == *xanmod* ]]; then
                currentBBRText="bbr2"

                echo
                echo " 请选择是否开启 ECN, (1) 关闭 (2) 开启 (3) 仅对入站请求开启 "
                red " 注意: 开启 ECN 可能会造成网络设备无法访问"
                read -p "请选择? 直接回车默认选1 关闭ECN, 请输入[1/2]:" ECNTcpInput
                ECNTcpInput=${ECNTcpInput:-1}
                if [[ $ECNTcpInput == [2] ]]; then
                    currentECNValue="1"
                    currentECNText="+ ECN"
                elif [[ $ECNTcpInput == [3] ]]; then
                    currentECNValue="2"
                else
                    currentECNValue="0"
                fi
                
            else
                echo
                red " 当前系统内核没有安装 XanMod 内核, 无法开启BBR2, 改为开启BBR"
                echo
                currentBBRText="bbr"
            fi
            
        else
            currentBBRText="bbr"
        fi
    fi


    echo "net.core.default_qdisc=${currentQueueText}" >> /etc/sysctl.conf
	echo "net.ipv4.tcp_congestion_control=${currentBBRText}" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_ecn=${currentECNValue}" >> /etc/sysctl.conf

    isSysctlText=$(sysctl -p 2>&1 | grep "No such file") 

    echo
    if [[ -z "$isSysctlText" ]]; then
		green " 已成功开启 ${currentBBRText} + ${currentQueueText} ${currentECNText} "
	else
        green " 已成功开启 ${currentBBRText} ${currentECNText}"
        red " 但当前内核版本过低, 开启队列算法 ${currentQueueText} 失败! " 
        red "请重新运行脚本, 选择'2 开启 BBR 加速'后, 务必再选择 (1)FQ 队列算法 !"
    fi
    echo
    

    read -p "是否优化系统网络配置? 直接回车默认优化, 请输入[Y/n]:" isOptimizingSystemInput
    isOptimizingSystemInput=${isOptimizingSystemInput:-Y}

    if [[ $isOptimizingSystemInput == [Yy] ]]; then
        addOptimizingSystemConfig
    else
    	sysctl -p
    fi
    sleep 2s
    start_menu
}

# 卸载 bbr+锐速 配置
function removeBbrSysctlConfig(){
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf

	sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf
		
	if [[ -e /appex/bin/lotServer.sh ]]; then
		bash <(wget --no-check-certificate -qO- https://git.io/lotServerInstall.sh) uninstall
	fi
}


function removeOptimizingSystemConfig(){
    removeBbrSysctlConfig

    sed -i '/fs.file-max/d' /etc/sysctl.conf
	sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.conf

	sed -i '/net.ipv4.tcp_syncookies/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
	sed -i '/net.ipv4.ip_local_port_range/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
	sed -i '/net.ipv4.route.gc_timeout/d' /etc/sysctl.conf

	sed -i '/net.ipv4.tcp_syn_retries/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_synack_retries/d' /etc/sysctl.conf
	sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
	sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_timestamps/d' /etc/sysctl.conf
	sed -i '/net.ipv4.tcp_max_orphans/d' /etc/sysctl.conf

	sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf


    sed -i '/1000000/d' /etc/security/limits.conf
    sed -i '/1000000/d' /etc/profile

    echo
    green " 已删除当前系统的网络优化配置 "
    echo
}

function addOptimizingSystemConfig(){

    # https://ustack.io/2019-11-21-Linux%E5%87%A0%E4%B8%AA%E9%87%8D%E8%A6%81%E7%9A%84%E5%86%85%E6%A0%B8%E9%85%8D%E7%BD%AE.html
    # https://www.cnblogs.com/xkus/p/7463135.html

    # 优化系统配置

    if grep -q "1000000" "/etc/profile"; then
        echo
        green " 系统网络配置 已经优化过, 不需要再次优化 "
        echo
        sysctl -p
        echo
        sleep 2s
        start_menu
    fi

    removeOptimizingSystemConfig

    echo
    green " 开始准备 优化系统网络配置 "

    cat >> /etc/sysctl.conf <<-EOF
fs.file-max = 1000000
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_max_tw_buckets = 6000
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_synack_retries = 1
net.core.somaxconn = 32768
net.core.netdev_max_backlog = 32768
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_max_orphans = 32768
# forward ipv4
net.ipv4.ip_forward = 1
EOF



    cat >> /etc/security/limits.conf <<-EOF
*               soft    nofile          1000000
*               hard    nofile          1000000
EOF


	echo "ulimit -SHn 1000000" >> /etc/profile
    source /etc/profile


    echo
	sysctl -p

    echo
    green " 已完成 系统网络配置的优化 "
    echo
    sleep 2s
    start_menu
}



function startIpv4(){

    cat >> /etc/sysctl.conf <<-EOF
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_slow_start_after_idle = 0
# forward ipv4
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF


}





































isInstallFromRepo="no"
userHomePath="${HOME}/linux_kernel"
linuxKernelByUser="elrepo"
linuxKernelToBBRType=""
linuxKernelToInstallVersion="5.10"
linuxKernelToInstallVersionFull=""

elrepo_kernel_name="kernel-ml"
elrepo_kernel_version="5.4.110"

altarch_kernel_name="kernel"
altarch_kernel_version="5.4.105"



function downloadFile(){

    tempUrl=$1
    tempFilename=$(echo "${tempUrl##*/}")

    echo "${userHomePath}/${linuxKernelToInstallVersionFull}/${tempFilename}"
    if [ -f "${userHomePath}/${linuxKernelToInstallVersionFull}/${tempFilename}" ]; then
        green "文件已存在, 不需要下载, 文件原下载地址: $1 "
    else 
        green "文件下载中... 下载地址: $1 "
        wget -N --no-check-certificate -P ${userHomePath}/${linuxKernelToInstallVersionFull} $1 
    fi 
    echo
}


function installKernel(){

    if [ "${linuxKernelToInstallVersion}" = "5.10" ]; then 
        bbrplusKernelVersion="5.10.28-1"
        
    elif [ "${linuxKernelToInstallVersion}" = "5.9" ]; then 
        bbrplusKernelVersion="5.9.16-1"
        
    elif [ "${linuxKernelToInstallVersion}" = "5.4" ]; then 
        bbrplusKernelVersion="5.4.110-1"

    elif [ "${linuxKernelToInstallVersion}" = "4.19" ]; then 
        bbrplusKernelVersion="4.19.185-1"

    elif [ "${linuxKernelToInstallVersion}" = "4.14" ]; then 
        bbrplusKernelVersion="4.14.229-1"

    elif [ "${linuxKernelToInstallVersion}" = "4.9" ]; then 
        bbrplusKernelVersion="4.9.265-1"
    fi    



	if [[ "${osRelease}" == "debian" || "${osRelease}" == "ubuntu" ]]; then
		
        installDebianUbuntuKernel

	elif [[ "${osRelease}" == "centos" ]]; then
        rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
        
        if [ "${linuxKernelToBBRType}" = "xanmod" ]; then 
            red " xanmod 内核不支持 Centos 系统安装"
            exit 255
        fi

        if [ "${isInstallFromRepo}" = "yes" ]; then 
            getLatestCentosKernelVersion
            installCentosKernelFromRepo
        else
            if [ "${linuxKernelToBBRType}" = "bbrplus" ]; then 
                echo
            else
                getLatestCentosKernelVersion "manual"
            fi
            
            installCentosKernelManual
        fi
	fi
}


function getLatestCentosKernelVersion(){

    # https://stackoverflow.com/questions/4988155/is-there-a-bash-command-that-can-tell-the-size-of-a-shell-variable

    elrepo_kernel_version_lt_array=($(wget -qO- https://elrepo.org/linux/kernel/el8/x86_64/RPMS | awk -F'\"kernel-lt-' '/>kernel-lt-[4-9]./{print $2}' | cut -d- -f1 | sort -V))

    # echo ${elrepo_kernel_version_lt_array[@]}

    echo
    if [ ${#elrepo_kernel_version_lt_array[@]} -eq 0 ]; then
        red " 无法获取到 Centos elrepo 源的最新的Linux 内核 kernel-lt 版本号 "
    else
        # echo ${elrepo_kernel_version_lt_array[${#elrepo_kernel_version_lt_array[@]} - 1]}
        elrepo_kernel_version_lt=${elrepo_kernel_version_lt_array[${#elrepo_kernel_version_lt_array[@]} - 1]}
        green "Centos elrepo 源的最新的Linux 内核 kernel-lt 版本号为 ${elrepo_kernel_version_lt}" 
    fi

    if [ -z $1 ]; then
        elrepo_kernel_version_ml_array=($(wget -qO- https://elrepo.org/linux/kernel/el8/x86_64/RPMS | awk -F'>kernel-ml-' '/>kernel-ml-[4-9]./{print $2}' | cut -d- -f1 | sort -V))
        
        if [ ${#elrepo_kernel_version_ml_array[@]} -eq 0 ]; then
            red " 无法获取到 Centos elrepo 源的最新的Linux 内核 kernel-ml 版本号 "
        else
            elrepo_kernel_version_ml=${elrepo_kernel_version_ml_array[-1]}
            green "Centos elrepo 源的最新的Linux 内核 kernel-ml 版本号为 ${elrepo_kernel_version_ml}" 
        fi
    else
        elrepo_kernel_version_ml2_array=($(wget -qO- https://fr1.teddyvps.com/kernel/el8 | awk -F'>kernel-ml-' '/>kernel-ml-[4-9]./{print $2}' | cut -d- -f1 | sort -V))
       
        if [ ${#elrepo_kernel_version_ml2_array[@]} -eq 0 ]; then
            red " 无法获取到由 Teddysun 编译的 Centos 最新的Linux 5.10 内核 kernel-ml 版本号 "
        else
            for ver in ${elrepo_kernel_version_ml2_array[@]}; do
                
                if [[ ${ver} == *"5.10"* ]]; then
                    # echo "符合所选版本的Linux 内核版本: ${ver}"
                    elrepo_kernel_version_ml_Teddysun510=${ver}
                fi

                if [[ ${ver} == *"5.11"* ]]; then
                    # echo "符合所选版本的Linux 内核版本: ${ver}"
                    elrepo_kernel_version_ml_Teddysun511=${ver}
                fi
            done

            elrepo_kernel_version_ml_TeddysunLatest=${elrepo_kernel_version_ml2_array[-1]}
            green "Centos elrepo 源的最新的Linux 内核 kernel-ml 版本号为 ${elrepo_kernel_version_ml_TeddysunLatest}" 
            green "由 Teddysun 编译的 Centos 最新的Linux 5.10 内核 kernel-ml 版本号为 ${elrepo_kernel_version_ml_Teddysun510}" 
            
        fi
    fi
    echo
}


function installCentosKernelFromRepo(){

    green " =================================================="
    green "    开始通过 elrepo 源安装 linux 内核, 不支持Centos6 "
    green " =================================================="

    if [ -n "${osReleaseVersionNo}" ]; then 
    
        if [ "${linuxKernelToInstallVersion}" = "5.4" ]; then 
            elrepo_kernel_name="kernel-lt"
            elrepo_kernel_version=${elrepo_kernel_version_lt}

        else
            elrepo_kernel_name="kernel-ml"
            elrepo_kernel_version=${elrepo_kernel_version_ml}
        fi

        if [ "${osKernelVersionBackup}" = "${elrepo_kernel_version}" ]; then 
            red "当前系统内核版本已经是 ${osKernelVersionBackup} 无需安装! "
            promptContinueOpeartion
        fi
        
        linuxKernelToInstallVersionFull=${elrepo_kernel_version}
        
        if [ "${osReleaseVersionNo}" -eq 7 ]; then
            # https://computingforgeeks.com/install-linux-kernel-5-on-centos-7/

            # https://elrepo.org/linux/kernel/
            # https://elrepo.org/linux/kernel/el7/x86_64/RPMS/
            
            ${sudoCmd} yum install -y yum-plugin-fastestmirror 
            ${sudoCmd} yum install -y https://www.elrepo.org/elrepo-release-7.el7.elrepo.noarch.rpm
   
        elif [ "${osReleaseVersionNo}" -eq 8 ]; then
            # https://elrepo.org/linux/kernel/el8/x86_64/RPMS/
            
            ${sudoCmd} yum install -y yum-plugin-fastestmirror 
            ${sudoCmd} yum install -y https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm

        else
            green " =================================================="
            red "    不支持 Centos 7和8 以外的其他版本 安装 linux 内核"
            green " =================================================="
            exit 255
        fi

        removeCentosKernelMulti
        listAvailableLinuxKernel
        echo
        green " 开始安装 linux 内核版本: ${linuxKernelToInstallVersionFull}"
        echo
        ${sudoCmd} yum -y --enablerepo=elrepo-kernel install ${elrepo_kernel_name}
        ${sudoCmd} yum -y --enablerepo=elrepo-kernel install ${elrepo_kernel_name}-{devel,headers,tools,tools-libs}

        green " =================================================="
        green "    安装 linux 内核 ${linuxKernelToInstallVersionFull} 成功! "
        red "    请根据以下信息 检查新内核是否安装成功，无新内核不要重启! "
        green " =================================================="
        echo

        showLinuxKernelInfo
        listInstalledLinuxKernel
        removeCentosKernelMulti "kernel"
        listInstalledLinuxKernel
        rebootSystem
    fi
}




function installCentosKernelManual(){

    green " =================================================="
    green "    开始手动安装 linux 内核, 不支持Centos6 "
    green " =================================================="
    echo

    yum install -y linux-firmware
    
    mkdir -p ${userHomePath}
    cd ${userHomePath}

    kernelVersionFirstletter=${linuxKernelToInstallVersion:0:1}

    echo
    if [ "${linuxKernelToBBRType}" = "bbrplus" ]; then 
        linuxKernelByUser="UJX6N"
        if [ "${linuxKernelToInstallVersion}" = "4.14.129" ]; then 
            linuxKernelByUser="cx9208"
        fi
        green " 准备从 ${linuxKernelByUser} github 网站下载 bbr plus 的linux内核并安装 "
    else
        if [ "${kernelVersionFirstletter}" = "5" ]; then 
            linuxKernelByUser="elrepo"
        else
            linuxKernelByUser="altarch"
        fi
        green " 准备从 ${linuxKernelByUser} 网站下载linux内核并安装 "
    fi
    echo

    if [ "${linuxKernelByUser}" = "elrepo" ]; then 
        # elrepo 

        if [ "${linuxKernelToInstallVersion}" = "5.4" ]; then 
            elrepo_kernel_name="kernel-lt"
            elrepo_kernel_version=${elrepo_kernel_version_lt}
            elrepo_kernel_filename="elrepo."
            ELREPODownloadUrl="https://elrepo.org/linux/kernel/el${osReleaseVersionNo}/x86_64/RPMS"

            # https://elrepo.org/linux/kernel/el7/x86_64/RPMS/
            # https://elrepo.org/linux/kernel/el7/x86_64/RPMS/kernel-lt-5.4.105-1.el7.elrepo.x86_64.rpm
            # https://elrepo.org/linux/kernel/el7/x86_64/RPMS/kernel-lt-tools-5.4.109-1.el7.elrepo.x86_64.rpm
            # https://elrepo.org/linux/kernel/el7/x86_64/RPMS/kernel-lt-tools-libs-5.4.109-1.el7.elrepo.x86_64.rpm

        elif [ "${linuxKernelToInstallVersion}" = "5.10" ]; then 
            elrepo_kernel_name="kernel-ml"
            elrepo_kernel_version=${elrepo_kernel_version_ml_Teddysun510}
            elrepo_kernel_filename=""
            ELREPODownloadUrl="https://dl.lamp.sh/kernel/el${osReleaseVersionNo}"

            # https://dl.lamp.sh/kernel/el7/kernel-ml-5.10.23-1.el7.x86_64.rpm
            # https://dl.lamp.sh/kernel/el7/kernel-ml-5.10.37-1.el7.x86_64.rpm
            # https://dl.lamp.sh/kernel/el8/kernel-ml-5.10.27-1.el8.x86_64.rpm
            # https://dl.lamp.sh/kernel/el8/kernel-ml-5.10.27-1.el8.x86_64.rpm

        elif [ "${linuxKernelToInstallVersion}" = "5.11" ]; then 
            elrepo_kernel_name="kernel-ml"
            elrepo_kernel_version=${elrepo_kernel_version_ml_Teddysun511}
            elrepo_kernel_filename="elrepo."
            ELREPODownloadUrl="https://fr1.teddyvps.com/kernel/el${osReleaseVersionNo}"       

            # https://fr1.teddyvps.com/kernel/el8/kernel-ml-devel-5.11.13-1.el8.elrepo.x86_64.rpm 

        elif [ "${linuxKernelToInstallVersion}" = "5.12" ]; then 
            elrepo_kernel_name="kernel-ml"
            elrepo_kernel_version=${elrepo_kernel_version_ml_TeddysunLatest}
            elrepo_kernel_filename="elrepo."
            ELREPODownloadUrl="https://fr1.teddyvps.com/kernel/el${osReleaseVersionNo}"       

            # https://fr1.teddyvps.com/kernel/el7/kernel-ml-5.12.4-1.el7.elrepo.x86_64.rpm
        fi

        linuxKernelToInstallVersionFull=${elrepo_kernel_version}

        mkdir -p ${userHomePath}/${linuxKernelToInstallVersionFull}
        cd ${userHomePath}/${linuxKernelToInstallVersionFull}

        if [ "${osReleaseVersionNo}" -eq 7 ]; then
            downloadFile ${ELREPODownloadUrl}/${elrepo_kernel_name}-${elrepo_kernel_version}-1.el7.${elrepo_kernel_filename}x86_64.rpm
            downloadFile ${ELREPODownloadUrl}/${elrepo_kernel_name}-devel-${elrepo_kernel_version}-1.el7.${elrepo_kernel_filename}x86_64.rpm
            downloadFile ${ELREPODownloadUrl}/${elrepo_kernel_name}-headers-${elrepo_kernel_version}-1.el7.${elrepo_kernel_filename}x86_64.rpm
            downloadFile ${ELREPODownloadUrl}/${elrepo_kernel_name}-tools-${elrepo_kernel_version}-1.el7.${elrepo_kernel_filename}x86_64.rpm
            downloadFile ${ELREPODownloadUrl}/${elrepo_kernel_name}-tools-libs-${elrepo_kernel_version}-1.el7.${elrepo_kernel_filename}x86_64.rpm
        else 
            downloadFile ${ELREPODownloadUrl}/${elrepo_kernel_name}-${elrepo_kernel_version}-1.el8.${elrepo_kernel_filename}x86_64.rpm
            downloadFile ${ELREPODownloadUrl}/${elrepo_kernel_name}-devel-${elrepo_kernel_version}-1.el8.${elrepo_kernel_filename}x86_64.rpm
            downloadFile ${ELREPODownloadUrl}/${elrepo_kernel_name}-headers-${elrepo_kernel_version}-1.el8.${elrepo_kernel_filename}x86_64.rpm
            downloadFile ${ELREPODownloadUrl}/${elrepo_kernel_name}-core-${elrepo_kernel_version}-1.el8.${elrepo_kernel_filename}x86_64.rpm
            downloadFile ${ELREPODownloadUrl}/${elrepo_kernel_name}-modules-${elrepo_kernel_version}-1.el8.${elrepo_kernel_filename}x86_64.rpm
            downloadFile ${ELREPODownloadUrl}/${elrepo_kernel_name}-tools-${elrepo_kernel_version}-1.el8.${elrepo_kernel_filename}x86_64.rpm
            downloadFile ${ELREPODownloadUrl}/${elrepo_kernel_name}-tools-libs-${elrepo_kernel_version}-1.el8.${elrepo_kernel_filename}x86_64.rpm
        fi

        removeCentosKernelMulti
        echo
        green " 开始安装 linux 内核版本: ${linuxKernelToInstallVersionFull}"
        echo        

        if [ "${osReleaseVersionNo}" -eq 8 ]; then
            rpm -ivh --force --nodeps ${elrepo_kernel_name}-core-${elrepo_kernel_version}-*.rpm
        fi
        
        rpm -ivh --force --nodeps ${elrepo_kernel_name}-${elrepo_kernel_version}-*.rpm
        rpm -ivh --force --nodeps ${elrepo_kernel_name}-*.rpm


    elif [ "${linuxKernelByUser}" = "altarch" ]; then 
        # altarch

        if [ "${linuxKernelToInstallVersion}" = "4.14" ]; then 
            altarch_kernel_version="4.14.119-200"
            altarchDownloadUrl="https://vault.centos.org/altarch/7.6.1810/kernel/x86_64/Packages"

            # https://vault.centos.org/altarch/7.6.1810/kernel/x86_64/Packages/kernel-4.14.119-200.el7.x86_64.rpm
        elif [ "${linuxKernelToInstallVersion}" = "4.19" ]; then 
            altarch_kernel_version="4.19.113-300"
            altarchDownloadUrl="https://vault.centos.org/altarch/7.8.2003/kernel/x86_64/Packages"

            # https://vault.centos.org/altarch/7.8.2003/kernel/x86_64/Packages/kernel-4.19.113-300.el7.x86_64.rpm
        else
            altarch_kernel_version="5.4.105"
            altarchDownloadUrl="http://mirror.centos.org/altarch/7/kernel/x86_64/Packages"

            # http://mirror.centos.org/altarch/7/kernel/x86_64/Packages/kernel-5.4.96-200.el7.x86_64.rpm
        fi

        linuxKernelToInstallVersionFull=$(echo ${altarch_kernel_version} | cut -d- -f1)

        mkdir -p ${userHomePath}/${linuxKernelToInstallVersionFull}
        cd ${userHomePath}/${linuxKernelToInstallVersionFull}

        if [ "${osReleaseVersionNo}" -eq 7 ]; then
            
            if [ "$kernelVersionFirstletter" = "5" ]; then 
                # http://mirror.centos.org/altarch/7/kernel/x86_64/Packages/

                downloadFile ${altarchDownloadUrl}/${altarch_kernel_name}-${altarch_kernel_version}-200.el7.x86_64.rpm
                downloadFile ${altarchDownloadUrl}/${altarch_kernel_name}-core-${altarch_kernel_version}-200.el7.x86_64.rpm
                downloadFile ${altarchDownloadUrl}/${altarch_kernel_name}-devel-${altarch_kernel_version}-200.el7.x86_64.rpm
                downloadFile ${altarchDownloadUrl}/${altarch_kernel_name}-headers-${altarch_kernel_version}-200.el7.x86_64.rpm
                downloadFile ${altarchDownloadUrl}/${altarch_kernel_name}-modules-${altarch_kernel_version}-200.el7.x86_64.rpm
                downloadFile ${altarchDownloadUrl}/${altarch_kernel_name}-tools-${altarch_kernel_version}-200.el7.x86_64.rpm
                downloadFile ${altarchDownloadUrl}/${altarch_kernel_name}-tools-libs-${altarch_kernel_version}-200.el7.x86_64.rpm

            else 
                # https://vault.centos.org/altarch/7.6.1810/kernel/x86_64/Packages/
                # https://vault.centos.org/altarch/7.6.1810/kernel/x86_64/Packages/kernel-4.14.119-200.el7.x86_64.rpm

                # https://vault.centos.org/altarch/7.8.2003/kernel/x86_64/Packages/
                # https://vault.centos.org/altarch/7.8.2003/kernel/i386/Packages/kernel-4.19.113-300.el7.i686.rpm
                # https://vault.centos.org/altarch/7.8.2003/kernel/x86_64/Packages/kernel-4.19.113-300.el7.x86_64.rpm
                # http://ftp.iij.ad.jp/pub/linux/centos-vault/altarch/7.8.2003/kernel/i386/Packages/kernel-4.19.113-300.el7.i686.rpm

                downloadFile ${altarchDownloadUrl}/${altarch_kernel_name}-${altarch_kernel_version}.el7.x86_64.rpm
                downloadFile ${altarchDownloadUrl}/${altarch_kernel_name}-core-${altarch_kernel_version}.el7.x86_64.rpm
                downloadFile ${altarchDownloadUrl}/${altarch_kernel_name}-devel-${altarch_kernel_version}.el7.x86_64.rpm
                downloadFile ${altarchDownloadUrl}/${altarch_kernel_name}-headers-${altarch_kernel_version}.el7.x86_64.rpm
                downloadFile ${altarchDownloadUrl}/${altarch_kernel_name}-modules-${altarch_kernel_version}.el7.x86_64.rpm
                downloadFile ${altarchDownloadUrl}/${altarch_kernel_name}-tools-${altarch_kernel_version}.el7.x86_64.rpm
                downloadFile ${altarchDownloadUrl}/${altarch_kernel_name}-tools-libs-${altarch_kernel_version}.el7.x86_64.rpm

            fi

        else 
            red "从 altarch 源没有找到 Centos 8 的 ${linuxKernelToInstallVersion} Kernel "
            exit 255
        fi

        removeCentosKernelMulti
        echo
        green " 开始安装 linux 内核版本: ${linuxKernelToInstallVersionFull}"
        echo        
        rpm -ivh --force --nodeps ${altarch_kernel_name}-core-${altarch_kernel_version}*
        rpm -ivh --force --nodeps ${altarch_kernel_name}-*
        # yum install -y kernel-*


    elif [ "${linuxKernelByUser}" = "cx9208" ]; then 

        linuxKernelToInstallVersionFull="4.14.129-bbrplus"

        if [ "${osReleaseVersionNo}" -eq 7 ]; then
            mkdir -p ${userHomePath}/${linuxKernelToInstallVersionFull}
            cd ${userHomePath}/${linuxKernelToInstallVersionFull}

            # https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/bbrplus/centos/7/kernel-4.14.129-bbrplus.rpm
            # https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/bbrplus/centos/7/kernel-headers-4.14.129-bbrplus.rpm

            bbrplusDownloadUrl="https://raw.githubusercontent.com/cx9208/Linux-NetSpeed/master/bbrplus/centos/7"

            downloadFile ${bbrplusDownloadUrl}/kernel-${linuxKernelToInstallVersionFull}.rpm
            downloadFile ${bbrplusDownloadUrl}/kernel-headers-${linuxKernelToInstallVersionFull}.rpm

            removeCentosKernelMulti
            echo
            green " 开始安装 linux 内核版本: ${linuxKernelToInstallVersionFull}"
            echo            
            rpm -ivh --force --nodeps kernel-${linuxKernelToInstallVersionFull}.rpm
            rpm -ivh --force --nodeps kernel-headers-${linuxKernelToInstallVersionFull}.rpm
        else 
            red "从 cx9208 的 github 网站没有找到 Centos 8 的 ${linuxKernelToInstallVersion} Kernel "
            exit 255
        fi

    elif [ "${linuxKernelByUser}" = "UJX6N" ]; then 
        
        linuxKernelToInstallSubVersion=$(echo ${bbrplusKernelVersion} | cut -d- -f1)
        linuxKernelToInstallVersionFull="${linuxKernelToInstallSubVersion}-bbrplus"

        mkdir -p ${userHomePath}/${linuxKernelToInstallVersionFull}
        cd ${userHomePath}/${linuxKernelToInstallVersionFull}

        if [ "${linuxKernelToInstallVersion}" = "4.14" ]; then 
            bbrplusDownloadUrl="https://github.com/UJX6N/bbrplus/releases/download/${linuxKernelToInstallVersionFull}"

        else
            bbrplusDownloadUrl="https://github.com/UJX6N/bbrplus-${linuxKernelToInstallVersion}/releases/download/${linuxKernelToInstallVersionFull}"
        fi
        


        if [ "${osReleaseVersionNo}" -eq 7 ]; then

            # https://github.com/UJX6N/bbrplus-5.10/releases/download/5.10.27-bbrplus/CentOS-7_Required_kernel-bbrplus-5.10.27-1.bbrplus.el7.x86_64.rpm
            # https://github.com/UJX6N/bbrplus-5.10/releases/download/5.10.27-bbrplus/CentOS-7_Optional_kernel-bbrplus-devel-5.10.27-1.bbrplus.el7.x86_64.rpm
            # https://github.com/UJX6N/bbrplus-5.10/releases/download/5.10.27-bbrplus/CentOS-7_Optional_kernel-bbrplus-headers-5.10.27-1.bbrplus.el7.x86_64.rpm
            
            
            # https://github.com/UJX6N/bbrplus-5.9/releases/download/5.9.16-bbrplus/CentOS-7_Required_kernel-bbrplus-5.9.16-1.bbrplus.el7.x86_64.rpm
            # https://github.com/UJX6N/bbrplus-5.9/releases/download/5.9.16-bbrplus/CentOS-7_Optional_kernel-bbrplus-devel-5.9.16-1.bbrplus.el7.x86_64.rpm
            # https://github.com/UJX6N/bbrplus-5.4/releases/download/5.4.109-bbrplus/CentOS-7_Required_kernel-bbrplus-5.4.109-1.bbrplus.el7.x86_64.rpm
            # https://github.com/UJX6N/bbrplus-4.19/releases/download/4.19.184-bbrplus/CentOS-7_Required_kernel-bbrplus-4.19.184-1.bbrplus.el7.x86_64.rpm
            # https://github.com/UJX6N/bbrplus/releases/download/4.14.228-bbrplus/CentOS-7_Required_kernel-bbrplus-4.14.228-1.bbrplus.el7.x86_64.rpm
            # https://github.com/UJX6N/bbrplus-4.9/releases/download/4.9.264-bbrplus/CentOS-7_Required_kernel-bbrplus-4.9.264-1.bbrplus.el7.x86_64.rpm

            downloadFile ${bbrplusDownloadUrl}/CentOS-7_Required_kernel-bbrplus-${bbrplusKernelVersion}.bbrplus.el7.x86_64.rpm
            downloadFile ${bbrplusDownloadUrl}/CentOS-7_Optional_kernel-bbrplus-devel-${bbrplusKernelVersion}.bbrplus.el7.x86_64.rpm
            downloadFile ${bbrplusDownloadUrl}/CentOS-7_Optional_kernel-bbrplus-headers-${bbrplusKernelVersion}.bbrplus.el7.x86_64.rpm

            removeCentosKernelMulti
            echo
            green " 开始安装 linux 内核版本: ${linuxKernelToInstallVersionFull}"
            echo                
            rpm -ivh --force --nodeps CentOS-7_Required_kernel-bbrplus-${bbrplusKernelVersion}.bbrplus.el7.x86_64.rpm
            rpm -ivh --force --nodeps *.rpm
        else 
            
            if [ "${kernelVersionFirstletter}" = "5" ]; then 
                echo
            else
                red "从 UJX6N 的 github 网站没有找到 Centos 8 的 ${linuxKernelToInstallVersion} Kernel "
                exit 255
            fi

            # https://github.com/UJX6N/bbrplus-5.10/releases/download/5.10.27-bbrplus/CentOS-8_Required_kernel-bbrplus-core-5.10.27-1.bbrplus.el8.x86_64.rpm
            # https://github.com/UJX6N/bbrplus-5.10/releases/download/5.10.27-bbrplus/CentOS-8_Optional_kernel-bbrplus-5.10.27-1.bbrplus.el8.x86_64.rpm
            # https://github.com/UJX6N/bbrplus-5.10/releases/download/5.10.27-bbrplus/CentOS-8_Optional_kernel-bbrplus-devel-5.10.27-1.bbrplus.el8.x86_64.rpm
            # https://github.com/UJX6N/bbrplus-5.10/releases/download/5.10.27-bbrplus/CentOS-8_Optional_kernel-bbrplus-headers-5.10.27-1.bbrplus.el8.x86_64.rpm
            # https://github.com/UJX6N/bbrplus-5.10/releases/download/5.10.27-bbrplus/CentOS-8_Optional_kernel-bbrplus-modules-5.10.27-1.bbrplus.el8.x86_64.rpm
            # https://github.com/UJX6N/bbrplus-5.10/releases/download/5.10.27-bbrplus/CentOS-8_Optional_kernel-bbrplus-modules-extra-5.10.27-1.bbrplus.el8.x86_64.rpm

            
            downloadFile ${bbrplusDownloadUrl}/CentOS-8_Required_kernel-bbrplus-core-${bbrplusKernelVersion}.bbrplus.el8.x86_64.rpm
            downloadFile ${bbrplusDownloadUrl}/CentOS-8_Optional_kernel-bbrplus-${bbrplusKernelVersion}.bbrplus.el8.x86_64.rpm
            downloadFile ${bbrplusDownloadUrl}/CentOS-8_Optional_kernel-bbrplus-devel-${bbrplusKernelVersion}.bbrplus.el8.x86_64.rpm
            downloadFile ${bbrplusDownloadUrl}/CentOS-8_Optional_kernel-bbrplus-headers-${bbrplusKernelVersion}.bbrplus.el8.x86_64.rpm
            downloadFile ${bbrplusDownloadUrl}/CentOS-8_Optional_kernel-bbrplus-modules-${bbrplusKernelVersion}.bbrplus.el8.x86_64.rpm
            downloadFile ${bbrplusDownloadUrl}/CentOS-8_Optional_kernel-bbrplus-modules-extra-${bbrplusKernelVersion}.bbrplus.el8.x86_64.rpm

            removeCentosKernelMulti
            echo
            green " 开始安装 linux 内核版本: ${linuxKernelToInstallVersionFull}"
            echo                
            rpm -ivh --force --nodeps CentOS-8_Required_kernel-bbrplus-core-${bbrplusKernelVersion}.bbrplus.el8.x86_64.rpm
            rpm -ivh --force --nodeps *.rpm

        fi

    fi;

    updateGrubConfig

    green " =================================================="
    green "    安装 linux 内核 ${linuxKernelToInstallVersionFull} 成功! "
    red "    请根据以下信息 检查新内核是否安装成功，无新内核不要重启! "
    green " =================================================="
    echo

    showLinuxKernelInfo
    removeCentosKernelMulti "kernel"
    listInstalledLinuxKernel
    rebootSystem
}



function removeCentosKernelMulti(){
    listInstalledLinuxKernel

    if [ -z $1 ]; then
        red " 开始准备删除 kernel-header kernel-devel kernel-tools kernel-tools-libs 内核, 建议删除 "
    else
        red " 开始准备删除 kernel 内核, 建议删除 "
    fi

    red " 注意: 删除内核有风险, 可能会导致VPS无法启动, 请先做好备份! "
    read -p "是否删除内核? 直接回车默认删除内核, 请输入[Y/n]:" isContinueDelKernelInput
	isContinueDelKernelInput=${isContinueDelKernelInput:-Y}
    
    echo

	if [[ $isContinueDelKernelInput == [Yy] ]]; then

        if [ -z $1 ]; then
            removeCentosKernel "kernel-devel"
            removeCentosKernel "kernel-header"
            removeCentosKernel "kernel-tools"

            removeCentosKernel "kernel-ml-devel"
            removeCentosKernel "kernel-ml-header"
            removeCentosKernel "kernel-ml-tools"

            removeCentosKernel "kernel-lt-devel"
            removeCentosKernel "kernel-lt-header"
            removeCentosKernel "kernel-lt-tools"

            removeCentosKernel "kernel-bbrplus-devel"  
            removeCentosKernel "kernel-bbrplus-headers" 
            removeCentosKernel "kernel-bbrplus-modules" 
        else
            removeCentosKernel "kernel"  
        fi 
	fi
    echo
}

function removeCentosKernel(){

    # 嗯嗯，用的yum localinstall kernel-ml-* 后，再指定顺序， 用那个 rpm -ivh 包名不行，提示kernel-headers冲突，
    # 输入rpm -e --nodeps kernel-headers 提示无法加载到此包，

    # 此时需要指定已安装的完整的 rpm 包名。
    # rpm -qa | grep kernel
    # 可以查看。比如：kernel-ml-headers-5.10.16-1.el7.elrepo.x86_64
    # 那么强制删除，则命令为：rpm -e --nodeps kernel-ml-headers-5.10.16-1.el7.elrepo.x86_64

    # ${sudoCmd} yum remove kernel-ml kernel-ml-{devel,headers,perf}
    # ${sudoCmd} rpm -e --nodeps kernel-headers
    # ${sudoCmd} rpm -e --nodeps kernel-ml-headers-${elrepo_kernel_version}-1.el7.elrepo.x86_64

    removeKernelNameText="kernel"
    removeKernelNameText=$1
    grepExcludelinuxKernelVersion=$(echo ${linuxKernelToInstallVersionFull} | cut -d- -f1)

    
    # echo "rpm -qa | grep ${removeKernelNameText} | grep -v ${grepExcludelinuxKernelVersion} | grep -v noarch | wc -l"
    rpmOldKernelNumber=$(rpm -qa | grep "${removeKernelNameText}" | grep -v "${grepExcludelinuxKernelVersion}" | grep -v "noarch" | wc -l)
    rpmOLdKernelNameList=$(rpm -qa | grep "${removeKernelNameText}" | grep -v "${grepExcludelinuxKernelVersion}" | grep -v "noarch")
    # echo "${rpmOLdKernelNameList}"

    # https://stackoverflow.com/questions/29269259/extract-value-of-column-from-a-line-variable


    if [ "${rpmOldKernelNumber}" -gt "0" ]; then

        yellow "========== 准备开始删除旧内核 ${removeKernelNameText} ${osKernelVersionBackup}, 当前要安装新内核版本为: ${grepExcludelinuxKernelVersion}"
        red " 当前系统的旧内核 ${removeKernelNameText} ${osKernelVersionBackup} 有 ${rpmOldKernelNumber} 个需要删除"
        echo
        for((integer = 1; integer <= ${rpmOldKernelNumber}; integer++)); do   
            rpmOLdKernelName=$(awk "NR==${integer}" <<< "${rpmOLdKernelNameList}")
            green " 开始卸载第 ${integer} 个内核: ${rpmOLdKernelName}. 命令: rpm --nodeps -e ${rpmOLdKernelName}"
            rpm --nodeps -e ${rpmOLdKernelName}
            green " 已卸载第 ${integer} 个内核 ${rpmOLdKernelName}"
            echo
        done
        yellow "========== 共 ${rpmOldKernelNumber} 个旧内核 ${removeKernelNameText} ${osKernelVersionBackup} 已经卸载完成"
    else
        red " 当前需要卸载的系统旧内核 ${removeKernelNameText} ${osKernelVersionBackup} 数量为0 !" 
    fi

    echo
}



# 更新引导文件 grub.conf
updateGrubConfig(){
	if [[ "${osRelease}" == "centos" ]]; then

        # if [ ! -f "/boot/grub/grub.conf" ]; then
        #     red "File '/boot/grub/grub.conf' not found, 没找到该文件"  
        # else 
        #     sed -i 's/^default=.*/default=0/g' /boot/grub/grub.conf
        #     grub2-set-default 0

        #     awk -F\' '$1=="menuentry " {print i++ " : " $2}' /boot/grub2/grub.cfg
        #     egrep ^menuentry /etc/grub2.cfg | cut -f 2 -d \'

        #     grub2-editenv list
        # fi
        
        # https://blog.51cto.com/foxhound/2551477
        # 看看最新的 5.10.16 是否排在第一，也就是第 0 位。 如果是，执行：grub2-set-default 0,  然后再看看：grub2-editenv list

        green " =================================================="
        echo

        if [[ ${osReleaseVersionNo} = "6" ]]; then
            red " 不支持 Centos 6"
            exit 255
        else
			if [ -f "/boot/grub2/grub.cfg" ]; then
				grub2-mkconfig -o /boot/grub2/grub.cfg
				grub2-set-default 0
			elif [ -f "/boot/efi/EFI/centos/grub.cfg" ]; then
				grub2-mkconfig -o /boot/efi/EFI/centos/grub.cfg
				grub2-set-default 0
			elif [ -f "/boot/efi/EFI/redhat/grub.cfg" ]; then
				grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg
				grub2-set-default 0	
			else
				red " /boot/grub2/grub.cfg 没找到该文件，请检查."
				exit
			fi

            echo
            green "    查看当前 grub 菜单启动项列表, 确保新安装的内核 ${linuxKernelToInstallVersionFull} 是否在第一项 "
            # grubby --info=ALL|awk -F= '$1=="kernel" {print i++ " : " $2}'
            awk -F\' '$1=="menuentry " {print i++ " : " $2}' /boot/grub2/grub.cfg

            echo
            green "    查看当前 grub 启动顺序是否已设置为第一项 "
            echo "grub2-editenv list" 
            grub2-editenv list
            green " =================================================="
            echo    
        fi

    elif [[ "${osRelease}" == "debian" || "${osRelease}" == "ubuntu" ]]; then
        echo
        echo "/usr/sbin/update-grub" 
        /usr/sbin/update-grub
    fi
}
































function getLatestUbuntuKernelVersion(){
    ubuntuKernelLatestVersionArray=($(wget -qO- https://kernel.ubuntu.com/~kernel-ppa/mainline/ | awk -F'\"v' '/v[4-9]\./{print $2}' | cut -d/ -f1 | grep -v - | sort -V))
    ubuntuKernelLatestVersion=${ubuntuKernelLatestVersionArray[${#ubuntuKernelLatestVersionArray[@]} - 1]}
    echo
    green "Ubuntu mainline 最新的Linux 内核 kernel 版本号为 ${ubuntuKernelLatestVersion}" 
    
    for ver in ${ubuntuKernelLatestVersionArray[@]}; do
        
        if [[ ${ver} == *"${linuxKernelToInstallVersion}"* ]]; then
            # echo "符合所选版本的Linux 内核版本: ${ver}"
            ubuntuKernelVersion=${ver}
        fi
    done
    
    green "即将安装的内核版本: ${ubuntuKernelVersion}"
    ubuntuDownloadUrl="https://kernel.ubuntu.com/~kernel-ppa/mainline/v${ubuntuKernelVersion}/amd64"
    echo
    echo "wget -qO- ${ubuntuDownloadUrl} | awk -F'>' '/-[4-9]\./{print \$7}' | cut -d'<' -f1 | grep -v lowlatency"
    ubuntuKernelDownloadUrlArray=($(wget -qO- ${ubuntuDownloadUrl} | awk -F'>' '/-[4-9]\./{print $7}' | cut -d'<' -f1 | grep -v lowlatency ))

    # echo "${ubuntuKernelDownloadUrlArray[*]}" 
    echo

}

function installDebianUbuntuKernel(){


    # https://kernel.ubuntu.com/~kernel-ppa/mainline/

    # https://unix.stackexchange.com/questions/545601/how-to-upgrade-the-debian-10-kernel-from-backports-without-recompiling-it-from-s

    # https://askubuntu.com/questions/119080/how-to-update-kernel-to-the-latest-mainline-version-without-any-distro-upgrade

    # https://sypalo.com/how-to-upgrade-ubuntu
    
    if [ "${isInstallFromRepo}" = "yes" ]; then 

        if [ "${linuxKernelToBBRType}" = "xanmod" ]; then 

            green " =================================================="
            green "    开始通过 XanMod 官方源安装 linux 内核 ${linuxKernelToInstallVersion}"
            green " =================================================="

            # https://xanmod.org/

            echo 'deb http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-kernel.list
            wget -qO - https://dl.xanmod.org/gpg.key | sudo apt-key --keyring /etc/apt/trusted.gpg.d/xanmod-kernel.gpg add -
            ${sudoCmd} apt update

            listAvailableLinuxKernel "xanmod"

            echo
            green " 开始安装 linux 内核版本: ${linuxKernelToInstallVersionFull}"
            echo

            if [ "${linuxKernelToInstallVersion}" = "5.11" ]; then 
                ${sudoCmd} apt install -y linux-xanmod
            elif [ "${linuxKernelToInstallVersion}" = "5.10" ]; then 
                ${sudoCmd} apt install -y linux-xanmod-lts
            fi

            rebootSystem
        else

            debianKernelVersion="5.10.0"

            green " =================================================="
            green "    开始通过 Debian 官方源安装 linux 内核 ${debianKernelVersion}"
            green " =================================================="

            if [ "${osKernelVersionBackup}" = "${debianKernelVersion}" ]; then 
                red "当前系统内核版本已经是 ${osKernelVersionBackup} 无需安装! "
                promptContinueOpeartion
            fi

            linuxKernelToInstallVersionFull=${debianKernelVersion}

            echo "deb http://deb.debian.org/debian buster-backports main contrib non-free" > /etc/apt/sources.list.d/buster-backports.list
            echo "deb-src http://deb.debian.org/debian buster-backports main contrib non-free" >> /etc/apt/sources.list.d/buster-backports.list
            ${sudoCmd} apt update

            listAvailableLinuxKernel
            
            ${sudoCmd} apt install -y -t buster-backports linux-image-amd64
            ${sudoCmd} apt install -y -t buster-backports firmware-linux firmware-linux-nonfree

            echo
            echo "dpkg --get-selections | grep linux-image-${debianKernelVersion} | awk '/linux-image-[4-9]./{print \$1}' | awk -F'linux-image-' '{print \$2}' "
            debianKernelVersionPackageName=$(dpkg --get-selections | grep "${debianKernelVersion}" | awk '/linux-image-[4-9]./{print $1}' | awk -F'linux-image-' '{print $2}')
            
            echo
            green " Debian 官方源安装 linux 内核版本: ${debianKernelVersionPackageName}"
            green " 开始安装 linux-headers  命令为:  apt install -y linux-headers-${debianKernelVersionPackageName}"
            echo
            ${sudoCmd} apt install -y linux-headers-${debianKernelVersionPackageName}
            # ${sudoCmd} apt-get -y dist-upgrade

        fi

    else

        green " =================================================="
        green "    开始手动安装 linux 内核 "
        green " =================================================="
        echo

        mkdir -p ${userHomePath}
        cd ${userHomePath}

        linuxKernelByUser=""

        if [ "${linuxKernelToBBRType}" = "bbrplus" ]; then 
            linuxKernelByUser="UJX6N"
            if [ "${linuxKernelToInstallVersion}" = "4.14.129" ]; then 
                linuxKernelByUser="cx9208"
            fi
            green " 准备从 ${linuxKernelByUser} github 网站下载 bbr plus 的linux内核并安装 "
        else
            green " 准备从 Ubuntu kernel-ppa mainline 网站下载linux内核并安装 "
        fi
        echo

        if [[ "${osRelease}" == "ubuntu" && ${osReleaseVersionNo} == "16.04" ]]; then 
            wget -P ${userHomePath} http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_amd64.deb
            ${sudoCmd} dpkg -i libssl1.1_1.1.0g-2ubuntu4_amd64.deb 
        fi



        if [ "${linuxKernelByUser}" = "" ]; then 

            # https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.11.12/amd64/
            # https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.11.12/amd64/linux-image-unsigned-5.11.12-051112-generic_5.11.12-051112.202104071432_amd64.deb
            # https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.11.12/amd64/linux-modules-5.11.12-051112-generic_5.11.12-051112.202104071432_amd64.deb

            getLatestUbuntuKernelVersion

            linuxKernelToInstallVersionFull=${ubuntuKernelVersion}

            mkdir -p ${userHomePath}/${linuxKernelToInstallVersionFull}
            cd ${userHomePath}/${linuxKernelToInstallVersionFull}


            for file in ${ubuntuKernelDownloadUrlArray[@]}; do
                downloadFile ${ubuntuDownloadUrl}/${file}
            done

        elif [ "${linuxKernelByUser}" = "cx9208" ]; then 

            linuxKernelToInstallVersionFull="4.14.129-bbrplus"

            mkdir -p ${userHomePath}/${linuxKernelToInstallVersionFull}
            cd ${userHomePath}/${linuxKernelToInstallVersionFull}

            # https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/bbrplus/debian-ubuntu/x64/linux-headers-4.14.129-bbrplus.deb
            # https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/bbrplus/debian-ubuntu/x64/linux-image-4.14.129-bbrplus.deb

            # https://github.com/cx9208/Linux-NetSpeed/raw/master/bbrplus/debian-ubuntu/x64/linux-headers-4.14.129-bbrplus.deb
            # https://github.com/cx9208/Linux-NetSpeed/raw/master/bbrplus/debian-ubuntu/x64/linux-image-4.14.129-bbrplus.deb

            # https://raw.githubusercontent.com/cx9208/Linux-NetSpeed/master/bbrplus/debian-ubuntu/x64/linux-headers-4.14.129-bbrplus.deb
            # https://raw.githubusercontent.com/cx9208/Linux-NetSpeed/master/bbrplus/debian-ubuntu/x64/linux-image-4.14.129-bbrplus.deb

            bbrplusDownloadUrl="https://raw.githubusercontent.com/cx9208/Linux-NetSpeed/master/bbrplus/debian-ubuntu/x64"

            downloadFile ${bbrplusDownloadUrl}/linux-image-${linuxKernelToInstallVersionFull}.deb
            downloadFile ${bbrplusDownloadUrl}/linux-headers-${linuxKernelToInstallVersionFull}.deb

        elif [ "${linuxKernelByUser}" = "UJX6N" ]; then 
        
            linuxKernelToInstallSubVersion=$(echo ${bbrplusKernelVersion} | cut -d- -f1)
            linuxKernelToInstallVersionFull="${linuxKernelToInstallSubVersion}-bbrplus"

            mkdir -p ${userHomePath}/${linuxKernelToInstallVersionFull}
            cd ${userHomePath}/${linuxKernelToInstallVersionFull}

            if [ "${linuxKernelToInstallVersion}" = "4.14" ]; then 
                bbrplusDownloadUrl="https://github.com/UJX6N/bbrplus/releases/download/${linuxKernelToInstallVersionFull}"
                downloadFile ${bbrplusDownloadUrl}/Debian-Ubuntu_Required_linux-image-${linuxKernelToInstallSubVersion}-bbrplus_${linuxKernelToInstallSubVersion}-bbrplus-1_amd64.deb
                downloadFile ${bbrplusDownloadUrl}/Debian-Ubuntu_Required_linux-headers-${linuxKernelToInstallSubVersion}-bbrplus_${linuxKernelToInstallSubVersion}-bbrplus-1_amd64.deb
            else
                bbrplusDownloadUrl="https://github.com/UJX6N/bbrplus-${linuxKernelToInstallVersion}/releases/download/${linuxKernelToInstallVersionFull}"

                downloadFile ${bbrplusDownloadUrl}/Debian-Ubuntu_Required_linux-image-${linuxKernelToInstallSubVersion}-bbrplus_${linuxKernelToInstallSubVersion}-bbrplus-1_amd64.deb
                downloadFile ${bbrplusDownloadUrl}/Debian-Ubuntu_Required_linux-headers-${linuxKernelToInstallSubVersion}-bbrplus_${linuxKernelToInstallSubVersion}-bbrplus-1_amd64.deb
            fi
    
            # https://github.com/UJX6N/bbrplus-5.10/releases/download/5.10.27-bbrplus/Debian-Ubuntu_Required_linux-image-5.10.27-bbrplus_5.10.27-bbrplus-1_amd64.deb
            # https://github.com/UJX6N/bbrplus-5.10/releases/download/5.10.27-bbrplus/Debian-Ubuntu_Required_linux-headers-5.10.27-bbrplus_5.10.27-bbrplus-1_amd64.deb

            # https://github.com/UJX6N/bbrplus-5.9/releases/download/5.9.16-bbrplus/Debian-Ubuntu_Required_linux-image-5.9.16-bbrplus_5.9.16-bbrplus-1_amd64.deb
            # https://github.com/UJX6N/bbrplus-5.4/releases/download/5.4.109-bbrplus/Debian-Ubuntu_Required_linux-image-5.4.109-bbrplus_5.4.109-bbrplus-1_amd64.deb
            # https://github.com/UJX6N/bbrplus-4.19/releases/download/4.19.184-bbrplus/Debian-Ubuntu_Required_linux-image-4.19.184-bbrplus_4.19.184-bbrplus-1_amd64.deb

        fi


        removeDebianKernelMulti
        echo
        green " 开始安装 linux 内核版本: ${linuxKernelToInstallVersionFull}"
        echo
        ${sudoCmd} dpkg -i *.deb 

        updateGrubConfig

    fi

    echo
    green " =================================================="
    green "    安装 linux 内核 ${linuxKernelToInstallVersionFull} 成功! "
    red "    请根据以下信息 检查新内核是否安装成功，无新内核不要重启! "
    green " =================================================="
    echo

    showLinuxKernelInfo
    removeDebianKernelMulti "linux-image"
    listInstalledLinuxKernel
    rebootSystem

}




function removeDebianKernelMulti(){
    listInstalledLinuxKernel

    if [ -z $1 ]; then
        red " 开始准备删除 linux-headers linux-modules 内核, 建议删除 "
    else
        red " 开始准备删除 linux-image 内核, 建议删除 "
    fi

    red " 注意: 删除内核有风险, 可能会导致VPS无法启动, 请先做好备份! "
    read -p "是否删除内核? 直接回车默认删除内核, 请输入[Y/n]:" isContinueDelKernelInput
	isContinueDelKernelInput=${isContinueDelKernelInput:-Y}
    echo
    
	if [[ $isContinueDelKernelInput == [Yy] ]]; then

        if [ -z $1 ]; then
            removeDebianKernel "linux-modules-extra"
            removeDebianKernel "linux-headers"
            # removeDebianKernel "linux-kbuild"
            # removeDebianKernel "linux-compiler"
            # removeDebianKernel "linux-libc"
        else
            removeDebianKernel "linux-image"
            removeDebianKernel "linux-modules-extra"
            removeDebianKernel "linux-modules"
            removeDebianKernel "linux-headers"
            # ${sudoCmd} apt -y --purge autoremove
        fi

    fi
    echo
}

function removeDebianKernel(){

    removeKernelNameText="linux-image"
    removeKernelNameText=$1
    grepExcludelinuxKernelVersion=$(echo ${linuxKernelToInstallVersionFull} | cut -d- -f1)

    
    # echo "dpkg --get-selections | grep ${removeKernelNameText} | grep -Ev '${grepExcludelinuxKernelVersion}|${removeKernelNameText}-amd64' | awk '{print \$1}' "
    rpmOldKernelNumber=$(dpkg --get-selections | grep "${removeKernelNameText}" | grep -Ev "${grepExcludelinuxKernelVersion}|${removeKernelNameText}-amd64" | wc -l)
    rpmOLdKernelNameList=$(dpkg --get-selections | grep "${removeKernelNameText}" | grep -Ev "${grepExcludelinuxKernelVersion}|${removeKernelNameText}-amd64" | awk '{print $1}' )
    # echo "$rpmOLdKernelNameList"

    # https://stackoverflow.com/questions/16212656/grep-exclude-multiple-strings
    # https://stackoverflow.com/questions/29269259/extract-value-of-column-from-a-line-variable

    
    if [ "${rpmOldKernelNumber}" -gt "0" ]; then
        yellow "========== 准备开始删除旧内核 ${removeKernelNameText} ${osKernelVersionBackup}, 当前要安装新内核版本为: ${grepExcludelinuxKernelVersion}"
        red " 当前系统的旧内核 ${removeKernelNameText} ${osKernelVersionBackup} 有 ${rpmOldKernelNumber} 个需要删除"
        echo
        for((integer = 1; integer <= ${rpmOldKernelNumber}; integer++)); do   
            rpmOLdKernelName=$(awk "NR==${integer}" <<< "${rpmOLdKernelNameList}")
            green " 开始卸载第 ${integer} 个内核: ${rpmOLdKernelName}. 命令: apt remove --purge ${rpmOLdKernelName}"
            ${sudoCmd} apt remove -y --purge ${rpmOLdKernelName}
            green " 已卸载第 ${integer} 个内核 ${rpmOLdKernelName}"
            echo
        done
        yellow "========== 共 ${rpmOldKernelNumber} 个旧内核 ${removeKernelNameText} ${osKernelVersionBackup} 已经卸载完成"
    else
        red " 当前需要卸载的系统旧内核 ${removeKernelNameText} ${osKernelVersionBackup} 数量为0 !" 
    fi
    
    echo
}






































function getGithubLatestReleaseVersion(){
    # https://github.com/p4gefau1t/trojan-go/issues/63
    wget --no-check-certificate -qO- https://api.github.com/repos/$1/tags | grep 'name' | cut -d\" -f4 | head -1 | cut -b 2-
}






# https://unix.stackexchange.com/questions/8656/usr-bin-vs-usr-local-bin-on-linux

versionWgcf="2.2.3"
downloadFilenameWgcf="wgcf_${versionWgcf}_linux_amd64"
configWgcfBinPath="/usr/local/bin"
configWgcfConfigFolderPath="${HOME}/wireguard"
configWgcfAccountFilePath="${configWgcfConfigFolderPath}/wgcf-account.toml"
configWgcfProfileFilePath="${configWgcfConfigFolderPath}/wgcf-profile.conf"
configWireGuardConfigFileFolder="/etc/wireguard"
configWireGuardConfigFilePath="/etc/wireguard/wgcf.conf"

function installWireguard(){

    versionWgcf=$(getGithubLatestReleaseVersion "ViRb3/wgcf")
    downloadFilenameWgcf="wgcf_${versionWgcf}_linux_amd64"

    if [[ -f "${configWireGuardConfigFilePath}" ]]; then
        green " =================================================="
        green "  已安装过 Wireguard, 如需重装 可以选择卸载 Wireguard 后重新安装! "
        green " =================================================="
        exit
    fi



    isKernelSupportWireGuardVersion="5.6"
    isKernelBuildInWireGuardModule="no"

    if versionCompareWithOp "${isKernelSupportWireGuardVersion}" "${osKernelVersionShort}" ">"; then
        red " 当前系统内核为 ${osKernelVersionShort}, 低于5.6的系统内核没有内置 WireGuard Module !"
        isKernelBuildInWireGuardModule="no"
    else
        green " 当前系统内核为 ${osKernelVersionShort}, 系统内核已内置 WireGuard Module"
        isKernelBuildInWireGuardModule="yes"
    fi


    if [[ "${osRelease}" == "debian" || "${osRelease}" == "ubuntu" ]]; then
            ${sudoCmd} apt-get update
            ${sudoCmd} apt install -y openresolv
	    ${sudoCmd} apt install -y curl
            # ${sudoCmd} apt install -y resolvconf
            ${sudoCmd} apt install net-tools iproute2 dnsutils
            echo
            if [[ ${isKernelBuildInWireGuardModule} == "yes" ]]; then
                green " 当前系统内核版本高于5.6, 直接安装 wireguard-tools "
                ${sudoCmd} apt install -y wireguard-tools 
            else
                # 安装 wireguard-dkms 后 ubuntu 20 系统 会同时安装 5.4.0-71   内核
                green " 当前系统内核版本低于5.6,  直接安装 wireguard wireguard"
                ${sudoCmd} apt install -y wireguard
                # ${sudoCmd} apt install -y wireguard-tools 
            fi

            # if [[ ! -L "/usr/local/bin/resolvconf" ]]; then
            #     ln -s /usr/bin/resolvectl /usr/local/bin/resolvconf
            # fi
            
            ${sudoCmd} systemctl enable systemd-resolved.service
            ${sudoCmd} systemctl start systemd-resolved.service

    elif [[ "${osRelease}" == "centos" ]]; then
        ${sudoCmd} yum install -y epel-release elrepo-release 
        ${sudoCmd} yum install -y net-tools
        ${sudoCmd} yum install -y iproute

        echo
        if [[ ${isKernelBuildInWireGuardModule} == "yes" ]]; then

            green " 当前系统内核版本高于5.6, 直接安装 wireguard-tools "

            if [ "${osReleaseVersionNo}" -eq 7 ]; then
                ${sudoCmd} yum install -y yum-plugin-elrepo
            fi

            ${sudoCmd} yum install -y wireguard-tools
        else 
            
            if [ "${osReleaseVersionNo}" -eq 7 ]; then
                if [[ ${osKernelVersionBackup} == *"3.10."* ]]; then
                    green " 当前系统内核版本为原版Centos 7 ${osKernelVersionBackup} , 直接安装 kmod-wireguard "
                    ${sudoCmd} yum install -y yum-plugin-elrepo
                    ${sudoCmd} yum install -y kmod-wireguard wireguard-tools
                else
                    green " 当前系统内核版本低于5.6, 安装 wireguard-dkms "
                    ${sudoCmd} yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
                    ${sudoCmd} curl -o /etc/yum.repos.d/jdoss-wireguard-epel-7.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
                    ${sudoCmd} yum install -y wireguard-dkms wireguard-tools
                fi
            else
                if [[ ${osKernelVersionBackup} == *"4.18."* ]]; then
                    green " 当前系统内核版本为原版Centos 8 ${osKernelVersionBackup} , 直接安装 kmod-wireguard "
                    ${sudoCmd} yum install -y kmod-wireguard wireguard-tools
                else
                    green " 当前系统内核版本低于5.6, 安装 wireguard-dkms "
                    ${sudoCmd} yum config-manager --set-enabled PowerTools
                    ${sudoCmd} yum copr enable jdoss/wireguard
                    ${sudoCmd} yum install -y wireguard-dkms wireguard-tools
                fi

            fi
        fi
    fi


    echo
    green " =================================================="
    green " 开始安装 Cloudflare Warp 命令行工具 Wgcf "
    echo

    mkdir -p ${configWgcfConfigFolderPath}
    mkdir -p ${configWgcfBinPath}
    mkdir -p ${configWireGuardConfigFileFolder}

    cd ${configWgcfConfigFolderPath}

    # https://github.com/ViRb3/wgcf/releases/download/v2.2.2/wgcf_2.2.2_linux_amd64
    wget -O ${configWgcfConfigFolderPath}/wgcf --no-check-certificate "https://github.com/ViRb3/wgcf/releases/download/v${versionWgcf}/${downloadFilenameWgcf}"
    

    if [[ -f ${configWgcfConfigFolderPath}/wgcf ]]; then
        green " Cloudflare Warp 命令行工具 Wgcf ${versionWgcf} 下载成功!"
        echo
    else
        red "  Wgcf ${versionWgcf} 下载失败!"
        exit 255
    fi

    ${sudoCmd} chmod +x ${configWgcfConfigFolderPath}/wgcf
    cp ${configWgcfConfigFolderPath}/wgcf ${configWgcfBinPath}
    
    # ${configWgcfConfigFolderPath}/wgcf register --config "${configWgcfAccountFilePath}"

    ${configWgcfConfigFolderPath}/wgcf register 
    ${configWgcfConfigFolderPath}/wgcf generate 

    cp ${configWgcfProfileFilePath} ${configWireGuardConfigFilePath}

    enableWireguardIPV6OrIPV4

    echo 
    green " 开始临时启动 Wireguard, 用于测试是否启动正常, 运行命令: wg-quick up wgcf"
    ${sudoCmd} wg-quick up wgcf

    echo 
    green " 开始验证 Wireguard 是否启动正常, 检测是否使用 CLOUDFLARE 的 ipv6 访问 !"
    echo
    echo "curl -6 ip.p3terx.com"
    curl -6 ip.p3terx.com 
    echo
    isWireguardIpv6Working=$(curl -6 ip.p3terx.com | grep CLOUDFLARENET )
    echo

	if [[ -n "$isWireguardIpv6Working" ]]; then	
		green " Wireguard 启动正常, 已成功通过 CLOUDFLARE Warp 提供的 IPv6 访问网络! "
	else 
		green " ================================================== "
		red " Wireguard 通过 curl -6 ip.p3terx.com, 检测使用CLOUDFLARENET的IPV6 访问失败"
        red " 请检查linux 内核安装是否正确"
        red " 安装会继续运行, 也有可能安装成功, 只是IPV6 没有使用"
        red " 检查 WireGuard 是否启动成功, 可运行查看运行状态命令: systemctl status wg-quick@wgcf"
        red " 如果 WireGuard 启动失败, 可运行查看日志命令 寻找原因: journalctl -n 50 -u wg-quick@wgcf"
        red " 如遇到 WireGuard 启动失败, 建议重做新系统后, 不要更换其他内核, 直接安装WireGuard"
		green " ================================================== "
	fi

    echo
    green " 关闭临时启动用于测试的 Wireguard, 运行命令: wg-quick down wgcf "
    ${sudoCmd} wg-quick down wgcf
    echo

    ${sudoCmd} systemctl daemon-reload
    
    # 设置开机启动
    ${sudoCmd} systemctl enable wg-quick@wgcf

    # 启用守护进程
    ${sudoCmd} systemctl start wg-quick@wgcf

    checkWireguardBootStatus

    echo
    green " ================================================== "
    green "  Wireguard 和 Cloudflare Warp 命令行工具 Wgcf ${versionWgcf} 安装成功 !"
    green "  Cloudflare Warp 申请的账户配置文件路径: ${configWgcfAccountFilePath} "
    green "  Cloudflare Warp 生成的 Wireguard 配置文件路径: ${configWireGuardConfigFilePath} "
    echo
    green "  Wireguard 停止命令: systemctl stop wg-quick@wgcf  启动命令: systemctl start wg-quick@wgcf  重启命令: systemctl restart wg-quick@wgcf"
    green "  Wireguard 查看日志: journalctl -n 50 -u wg-quick@wgcf"
    green "  Wireguard 查看运行状态: systemctl status wg-quick@wgcf"
    echo
    green "  用本脚本安装v2ray或xray 可以选择是否 解锁 Netflix 限制 和 避免弹出 Google reCAPTCHA 人机验证 !"
    echo
    green "  其他脚本安装的v2ray或xray 请自行替换 v2ray或xray 配置文件!"
    green "  可参考 如何使用 IPv6 访问 Netflix 的教程 https://ybfl.xyz/111.html 或 https://toutyrater.github.io/app/netflix.html!"
    green " ================================================== "
    
}

function enableWireguardIPV6OrIPV4(){
    # https://p3terx.com/archives/use-cloudflare-warp-to-add-extra-ipv4-or-ipv6-network-support-to-vps-servers-for-free.html
    
    
    ${sudoCmd} systemctl stop wg-quick@wgcf

    sed -i '/nameserver 2a00\:1098\:2b\:\:1/d' /etc/resolv.conf

    sed -i '/nameserver 8\.8/d' /etc/resolv.conf
    sed -i '/nameserver 9\.9/d' /etc/resolv.conf
    sed -i '/nameserver 1\.1\.1\.1/d' /etc/resolv.conf

    echo
    green " ================================================== "
    yellow " 请选择为服务器添加 IPv6 网络 还是 IPv4 网络支持: "
    echo
    green " 1 添加 IPv6 网络 (用于解锁 Netflix 限制 和避免弹出 Google reCAPTCHA 人机验证)"
    green " 2 添加 IPv4 网络 (用于给只有 IPv6 的 VPS主机添加 IPv4 网络支持)"
    echo
    read -p "请选择添加 IPv6 还是 IPv4 网络支持? 直接回车默认选1 , 请输入[1/2]:" isAddNetworkIPv6Input
	isAddNetworkIPv6Input=${isAddNetworkIPv6Input:-1}

	if [[ ${isAddNetworkIPv6Input} == [2] ]]; then

        # 为 IPv6 Only 服务器添加 IPv4 网络支持

        sed -i 's/^AllowedIPs = \:\:\/0/# AllowedIPs = \:\:\/0/g' ${configWireGuardConfigFilePath}
        sed -i 's/# AllowedIPs = 0\.0\.0\.0/AllowedIPs = 0\.0\.0\.0/g' ${configWireGuardConfigFilePath}

        sed -i 's/engage\.cloudflareclient\.com/\[2606\:4700\:d0\:\:a29f\:c001\]/g' ${configWireGuardConfigFilePath}
        sed -i 's/162\.159\.192\.1/\[2606\:4700\:d0\:\:a29f\:c001\]/g' ${configWireGuardConfigFilePath}

        sed -i 's/^DNS = 1\.1\.1\.1/DNS = 2620:fe\:\:10,2001\:4860\:4860\:\:8888,2606\:4700\:4700\:\:1111/g'  ${configWireGuardConfigFilePath}
        sed -i 's/^DNS = 8\.8\.8\.8,1\.1\.1\.1,9\.9\.9\.10/DNS = 2620:fe\:\:10,2001\:4860\:4860\:\:8888,2606\:4700\:4700\:\:1111/g'  ${configWireGuardConfigFilePath}
        
        echo "nameserver 2a00:1098:2b::1" >> /etc/resolv.conf
        
        echo
        green " Wireguard 已成功切换到 对VPS服务器的 IPv4 网络支持"

    else

        # 为 IPv4 Only 服务器添加 IPv6 网络支持
        sed -i 's/^AllowedIPs = 0\.0\.0\.0/# AllowedIPs = 0\.0\.0\.0/g' ${configWireGuardConfigFilePath}
        sed -i 's/# AllowedIPs = \:\:\/0/AllowedIPs = \:\:\/0/g' ${configWireGuardConfigFilePath}

        sed -i 's/engage\.cloudflareclient\.com/162\.159\.192\.1/g' ${configWireGuardConfigFilePath}
        sed -i 's/\[2606\:4700\:d0\:\:a29f\:c001\]/162\.159\.192\.1/g' ${configWireGuardConfigFilePath}
        
        sed -i 's/^DNS = 1\.1\.1\.1/DNS = 8\.8\.8\.8,1\.1\.1\.1,9\.9\.9\.10/g' ${configWireGuardConfigFilePath}
        sed -i 's/^DNS = 2620:fe\:\:10,2001\:4860\:4860\:\:8888,2606\:4700\:4700\:\:1111/DNS = 8\.8\.8\.8,1\.1\.1\.1,9\.9\.9\.10/g' ${configWireGuardConfigFilePath}

        echo "nameserver 8.8.8.8" >> /etc/resolv.conf
        echo "nameserver 8.8.4.4" >> /etc/resolv.conf
        echo "nameserver 1.1.1.1" >> /etc/resolv.conf
        echo "nameserver 9.9.9.9" >> /etc/resolv.conf
        echo "nameserver 9.9.9.10" >> /etc/resolv.conf

        echo
        green " Wireguard 已成功切换到 对VPS服务器的 IPv6 网络支持"
    fi
    
    green " ================================================== "
    echo
    green " Wireguard 配置信息如下 配置文件路径: ${configWireGuardConfigFilePath} "
    cat ${configWireGuardConfigFilePath}
    green " ================================================== "
    echo

    # -n 不为空
    if [[ -n $1 ]]; then
        ${sudoCmd} systemctl start wg-quick@wgcf
    else
        preferIPV4
    fi
}


function preferIPV4(){

    if [[ -f "/etc/gai.conf" ]]; then
        sed -i '/^precedence \:\:ffff\:0\:0/d' /etc/gai.conf
        sed -i '/^label 2002\:\:\/16/d' /etc/gai.conf
    fi

    # -z 为空
    if [[ -z $1 ]]; then
        
        echo "precedence ::ffff:0:0/96  100" >> /etc/gai.conf

        echo
        green " VPS服务器已成功设置为 IPv4 优先访问网络"

    else

        # 设置 IPv6 优先
        echo "label 2002::/16   2" >> /etc/gai.conf

        echo
        green " VPS服务器已成功设置为 IPv6 优先访问网络 "


        green " ================================================== "
        echo
        yellow " 验证 IPv4 或 IPv6 访问网络优先级测试, 命令: curl ip.p3terx.com " 
        echo  
        curl ip.p3terx.com
        echo
        green " 上面信息显示 如果是IPv4地址 则VPS服务器已设置为 IPv4优先访问. 如果是IPv6地址则已设置为 IPv6优先访问 "   
        green " ================================================== "

    fi
    echo

}

function removeWireguard(){
    green " ================================================== "
    red " 准备卸载已安装 Wireguard 和 Cloudflare Warp 命令行工具 Wgcf "
    green " ================================================== "

    if [[ -f "${configWgcfBinPath}/wgcf" || -f "${configWgcfConfigFolderPath}/wgcf" || -f "/wgcf" ]]; then
        ${sudoCmd} systemctl stop wg-quick@wgcf.service
        ${sudoCmd} systemctl disable wg-quick@wgcf.service

        ${sudoCmd} wg-quick down wgcf
        ${sudoCmd} wg-quick disable wgcf
    else 
        red " 系统没有安装 Wireguard 和 Wgcf, 退出卸载"
        echo
        exit
    fi

    $osSystemPackage -y remove kmod-wireguard
    $osSystemPackage -y remove wireguard-dkms
    $osSystemPackage -y remove wireguard-tools
    $osSystemPackage -y remove wireguard

    rm -f ${configWgcfBinPath}/wgcf
    rm -rf ${configWgcfConfigFolderPath}
    rm -rf ${configWireGuardConfigFileFolder}

    rm -f ${osSystemMdPath}wg-quick@wgcf.service

    rm -f /usr/bin/wg
    rm -f /usr/bin/wg-quick
    rm -f /usr/share/man/man8/wg.8
    rm -f /usr/share/man/man8/wg-quick.8

    [ -d "/etc/wireguard" ] && ("rm -rf /etc/wireguard")

    sed -i '/nameserver 8\.8\.8\.8/d' /etc/resolv.conf
    sed -i '/nameserver 8\.8\.4\.4/d' /etc/resolv.conf
    sed -i '/nameserver 1\.1\.1\.1/d' /etc/resolv.conf
    sed -i '/nameserver 9\.9\.9\.9/d' /etc/resolv.conf
    sed -i '/nameserver 9\.9\.9\.10/d' /etc/resolv.conf


    modprobe -r wireguard

    green " ================================================== "
    green "  Wireguard 和 Cloudflare Warp 命令行工具 Wgcf 卸载完毕 !"
    green " ================================================== "

  
}


function checkWireguardBootStatus(){
    echo
    isWireguardBootSuccess=$(systemctl status wg-quick@wgcf | grep -E "Active: active")
    if [[ -z "${isWireguardBootSuccess}" ]]; then
        green " 状态显示-- Wireguard 已启动失败! 请查看 Wireguard 运行日志, 寻找错误后重启 Wireguard "
    else
        green " 状态显示-- Wireguard 已启动成功! "
    fi
}

function checkWireguard(){
    echo
    green " =================================================="
    echo
    green " 1. 查看当前系统内核版本, 检查是否装了多个版本内核导致 Wireguard 启动失败"
    green " 2. 查看 Wireguard 运行状态"
    green " 3. 查看 Wireguard 运行日志, 如果 Wireguard 启动失败 请用此项查找问题"
    green " 4. 启动 Wireguard "
    green " 5. 停止 Wireguard "
    green " 6. 重启 Wireguard "
    green " 7. 查看 Wireguard 配置文件 ${configWireGuardConfigFilePath} "
    green " 8. 用VI 编辑 Wireguard 配置文件 ${configWireGuardConfigFilePath} "
    echo
    green " =================================================="
    green " 0. 退出脚本"
    echo
    read -p "请输入数字:" menuNumberInput
    case "$menuNumberInput" in
        1 )
            showLinuxKernelInfo
            listInstalledLinuxKernel
        ;;   
        2 )
            echo
            echo "systemctl status wg-quick@wgcf"
            systemctl status wg-quick@wgcf
            red " 请查看上面 Active: 一行信息, 如果文字是绿色 active 则为启动正常, 否则启动失败"
            checkWireguardBootStatus
        ;;
        3 )
            echo
            echo "journalctl -n 50 -u wg-quick@wgcf"
            journalctl -n 50 -u wg-quick@wgcf
            red " 请查看上面包含 Error 的信息行, 查找启动失败的原因 "
        ;;        
        4 )
            echo
            echo "systemctl start wg-quick@wgcf"
            systemctl start wg-quick@wgcf
            green " Wireguard 已启动 !"
            checkWireguardBootStatus
        ;;        
        5 )
            echo
            echo "systemctl stop wg-quick@wgcf"
            systemctl stop wg-quick@wgcf
            green " Wireguard 已停止 !"
        ;;       
        6 )
            echo
            echo "systemctl restart wg-quick@wgcf"
            systemctl restart wg-quick@wgcf
            green " Wireguard 已重启 !"
            checkWireguardBootStatus
        ;;       
        7 )
            echo
            echo "cat ${configWireGuardConfigFilePath}"
            cat ${configWireGuardConfigFilePath}
        ;;       
        8 )
            echo
            echo "vi ${configWireGuardConfigFilePath}"
            vi ${configWireGuardConfigFilePath}
        ;; 
        0 )
            exit 1
        ;;
        * )
            clear
            red "请输入正确数字 !"
            sleep 2s
            checkWireguard
        ;;
    esac


}





































function startMenuOther(){
    clear
    green " =================================================="
    green " 1. 安装 trojan-web (trojan 和 trojan-go 可视化管理面板) 和 nginx 伪装网站"
    green " 2. 升级 trojan-web 到最新版本"
    green " 3. 重新申请证书"
    green " 4. 查看日志, 管理用户, 查看配置等功能"
    red " 5. 卸载 trojan-web 和 nginx "
    echo
    green " 6. 安装 v2ray 可视化管理面板V2ray UI 可以同时支持trojan"
    green " 7. 升级 v2ray UI 到最新版本"
    red " 8. 卸载 v2ray UI"
    echo
    red " 安装上面2个可视化管理面板 之前不能用本脚本或其他脚本安装过trojan或v2ray! 2个管理面板也无法同时安装"

    green " =================================================="
    green " 11. 单独申请域名SSL证书"
    green " 12. 只安装trojan 运行在443端口, 不安装nginx, 请确保443端口没有被nginx占用"
    green " 13. 只安装trojan-go 运行在443端口, 不支持CDN, 不开启websocket, 不安装nginx. 请确保80端口有监听,否则trojan-go无法启动"
    green " 14. 只安装trojan-go 运行在443端口, 支持CDN, 开启websocket, 不安装nginx. 请确保80端口有监听,否则trojan-go无法启动"    
    echo
    green " 15. 只安装V2ray或Xray (VLess或VMess协议) 开启websocket, 支持CDN, (VLess/VMess + WS) 不安装nginx,无TLS加密,方便与现有网站或宝塔面板集成"
    green " 16. 只安装V2ray或Xray (VLess或VMess协议) 开启grpc, 支持cloudflare的CDN需要指定443端口, (VLess/VMess + grpc) 不安装nginx,无TLS加密,方便与现有网站或宝塔面板集成"
    echo
    green " 17. 只安装V2ray VLess运行在443端口 (VLess-gRPC-TLS) 支持CDN, 不安装nginx"
    green " 18. 只安装V2ray VLess运行在443端口 (VLess-TCP-TLS) + (VLess-WS-TLS) 支持CDN, 不安装nginx"
    green " 19. 只安装V2ray VLess运行在443端口 (VLess-TCP-TLS) + (VMess-TCP-TLS) + (VMess-WS-TLS) 支持CDN, 不安装nginx"
    echo
    green " 21. 只安装Xray VLess运行在443端口 (VLess-TCP-XTLS direct) + (VLess-WS-TLS) 支持CDN, 不安装nginx" 
    green " 22. 只安装Xray VLess运行在443端口 (VLess-TCP-XTLS direct) + (VLess-WS-TLS) + trojan, 支持VLess的CDN, 不安装nginx"    
    green " 23. 只安装Xray VLess运行在443端口 (VLess-TCP-XTLS direct) + (VLess-WS-TLS) + trojan-go, 支持VLess的CDN, 不安装nginx"   
    green " 24. 只安装Xray VLess运行在443端口 (VLess-TCP-XTLS direct) + (VLess-WS-TLS) + trojan-go, 支持VLess的CDN和trojan-go的CDN, 不安装nginx"   
    green " 25. 只安装Xray VLess运行在443端口 (VLess-TCP-XTLS direct) + (VLess-WS-TLS) + xray自带的trojan, 支持VLess的CDN, 不安装nginx"    

    red " 27. 卸载 trojan"    
    red " 28. 卸载 trojan-go"   
    red " 29. 卸载 v2ray或Xray"   
    green " =================================================="
    red " 以下是 VPS 测网速工具, 脚本测速会消耗大量 VPS 流量，请悉知！"
    green " 41. superspeed 三网纯测速 （全国各地三大运营商部分节点全面测速）"
    green " 42. 由teddysun 编写的Bench 综合测试 （包含系统信息 IO 测试 多处数据中心的节点测试 ）"
	green " 43. testrace 回程路由测试 （四网路由测试）"
	green " 44. LemonBench 快速全方位测试 （包含CPU内存性能、回程、速度）"
    green " 45. ZBench 综合网速测试 （包含节点测速, Ping 以及 路由测试）"
    echo
    green " 51. 测试VPS 是否支持Netflix, 检测IP解锁范围及对应所在的地区"
    echo
    green " 61. 安装 官方宝塔面板"
    green " 62. 安装 宝塔面板破解版 by fenhao.me"
    green " 63. 安装 宝塔面板 7.4.5 纯净版 by hostcli.com"
    echo
    green " 9. 返回上级菜单"
    green " 0. 退出脚本"
    echo
    read -p "请输入数字:" menuNumberInput
    case "$menuNumberInput" in
        1 )
            setLinuxDateZone
            installTrojanWeb
        ;;
        2 )
            upgradeTrojanWeb
        ;;
        3 )
            runTrojanWebSSL
        ;;
        4 )
            runTrojanWebLog
        ;;
        5 )
            removeNginx
            removeTrojanWeb
        ;;
        6 )
            setLinuxDateZone
            installV2rayUI
        ;;
        7 )
            upgradeV2rayUI
        ;;
        8 )
            # removeNginx
            removeV2rayUI
        ;;
        11 )
            getHTTPSNoNgix
        ;;
        12 )
            getHTTPSNoNgix "trojan"
        ;;
        13 )
            isTrojanGo="yes"
            getHTTPSNoNgix "trojan"
        ;;
        14 )
            isTrojanGo="yes"
            isTrojanGoSupportWebsocket="true"
            getHTTPSNoNgix "trojan"
        ;;          
        15 )
            configV2rayWSorGrpc="ws"
            getHTTPSNoNgix "v2ray"
        ;;
        16 )
            configV2rayWSorGrpc="grpc"
            getHTTPSNoNgix "v2ray"
            
        ;;                
        17 )
            configV2rayVlessMode="vlessgrpc"
            getHTTPSNoNgix "v2ray"
        ;; 
        18 )
            configV2rayVlessMode="vlessws"
            getHTTPSNoNgix "v2ray"
        ;; 
        19 )
            configV2rayVlessMode="vmessws"
            getHTTPSNoNgix "v2ray"
        ;;    

        21 )
            configV2rayVlessMode="vlessxtlsws"
            getHTTPSNoNgix "v2ray"
        ;; 
        22 )
            configV2rayVlessMode="trojan"
            getHTTPSNoNgix "both"
        ;;
        23 )
            configV2rayVlessMode="trojan"
            isTrojanGo="yes"
            getHTTPSNoNgix "both"
        ;;    
        24 )
            configV2rayVlessMode="trojan"
            isTrojanGo="yes"
            isTrojanGoSupportWebsocket="true"
            getHTTPSNoNgix "both"
        ;;
        25 )
            configV2rayVlessMode="vlessxtlstrojan"
            getHTTPSNoNgix "v2ray"
        ;;          
        27 )
            removeTrojan
        ;;    
        28 )
            isTrojanGo="yes"
            removeTrojan
        ;;
        29 )
            removeV2ray
        ;;  
                                                     
        41 )
            vps_superspeed
        ;;
        42 )
            vps_bench
        ;;        
        43 )
            vps_testrace
        ;;
        44 )
            vps_LemonBench
        ;;
        45 )
            vps_zbench
        ;;
        51 )
            installPackage
            vps_netflix
        ;;                    
        61 )
            installBTPanel
        ;;
        62 )
            installBTPanelCrack
        ;;                              
        62 )
            installBTPanelCrack2
        ;;                              
        81 )
            installBBR
        ;;
        82 )
            installBBR2
        ;;                              
        9)
            start_menu
        ;;
        0 )
            exit 1
        ;;
        * )
            clear
            red "请输入正确数字 !"
            sleep 2s
            startMenuOther
        ;;
    esac
}

























function start_menu(){

    getLinuxOSRelease
    installSoftDownload


    read -p "是否替换内核? 请输入[Y/n]:" osTimezoneInput
    osTimezoneInput=${osTimezoneInput:-Y}

    if [[ $osTimezoneInput == [Yy] ]]; then
             #替换5.10内核
         linuxKernelToInstallVersion="5.10"
         linuxKernelToBBRType="bbrplus"
         installKernel
	 sleep 2s
    fi
    
    read -p "是否开启bbrplus? 请输入[Y/n]:" osTimezoneInput
    osTimezoneInput=${osTimezoneInput:-Y}

    if [[ $osTimezoneInput == [Yy] ]]; then
          #开启bbrplus
          enableBBRSysctlConfig "bbrplus"
	  sleep 2s
    fi

    read -p "是否安装Wireguard? 请输入[Y/n]:" osTimezoneInput
    osTimezoneInput=${osTimezoneInput:-Y}

    if [[ $osTimezoneInput == [Yy] ]]; then
          #安装Wireguard
          installWireguard
	  sleep 2s
    fi 

    read -p "是否安装xray? 请输入[Y/n]:" osTimezoneInput
    osTimezoneInput=${osTimezoneInput:-Y}

    if [[ $osTimezoneInput == [Yy] ]]; then
          configV2rayVlessMode="vlessxtlstrojan"
          installTrojanV2rayWithNginx "v2ray"
    fi 

}


