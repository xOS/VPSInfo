RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
SKYBLUE='\033[0;36m'
PLAIN='\033[0m'

cancel() {
	echo ""
	next;
	echo " Abort ..."
	echo " Cleanup ..."
	cleanup;
	echo " Done"
	exit
}

trap cancel SIGINT

benchinit() {
	if [ -f /etc/redhat-release ]; then
	    release="centos"
	elif cat /etc/issue | grep -Eqi "debian"; then
	    release="debian"
	elif cat /etc/issue | grep -Eqi "ubuntu"; then
	    release="ubuntu"
	elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
	    release="centos"
	elif cat /proc/version | grep -Eqi "debian"; then
	    release="debian"
	elif cat /proc/version | grep -Eqi "ubuntu"; then
	    release="ubuntu"
	elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
	    release="centos"
	fi

	[[ $EUID -ne 0 ]] && echo -e "${RED}Error:${PLAIN} This script must be run as root!" && exit 1

	if  [ ! -e '/usr/bin/python3' ]; then
	        echo " Installing Python ..."
	            if [ "${release}" == "centos" ]; then
	            		yum update > /dev/null 2>&1
	                    yum -y install python3 > /dev/null 2>&1
	                else
	                	apt-get update > /dev/null 2>&1
	                    apt-get -y install python3 > /dev/null 2>&1
	                fi
	        
	fi

	if  [ ! -e '/usr/bin/curl' ]; then
	        echo " Installing Curl ..."
	            if [ "${release}" == "centos" ]; then
	                yum update > /dev/null 2>&1
	                yum -y install curl > /dev/null 2>&1
	            else
	                apt-get update > /dev/null 2>&1
	                apt-get -y install curl > /dev/null 2>&1
	            fi
	fi
	
	if  [ ! -e '/usr/bin/jq' ]; then
	        echo " Installing jq ..."
	            if [ "${release}" == "centos" ]; then
	                yum update > /dev/null 2>&1
	                yum -y install jq > /dev/null 2>&1
	            else
	                apt-get update > /dev/null 2>&1
	                apt-get -y install jq > /dev/null 2>&1
	            fi
	fi

	if  [ ! -e '/usr/bin/wget' ]; then
	        echo " Installing Wget ..."
	            if [ "${release}" == "centos" ]; then
	                yum update > /dev/null 2>&1
	                yum -y install wget > /dev/null 2>&1
	            else
	                apt-get update > /dev/null 2>&1
	                apt-get -y install wget > /dev/null 2>&1
	            fi
	fi

	if  [ ! -e 'tools.py' ]; then
		echo " Installing tools.py ..."
		curl -s https://purge.jsdelivr.net/gh/xOS/VPSInfo@master/tools.py > /dev/null 2>&1
		wget --no-check-certificate https://cdn.jsdelivr.net/gh/xOS/VPSInfo@master/tools.py > /dev/null 2>&1
	fi
	chmod a+rx tools.py

	start=$(date +%s) 
}

get_opsy() {
    [ -f /etc/redhat-release ] && awk '{print ($1,$3~/^[0-9]/?$3:$4)}' /etc/redhat-release && return
    [ -f /etc/os-release ] && awk -F'[= "]' '/PRETTY_NAME/{print $3,$4,$5}' /etc/os-release && return
    [ -f /etc/lsb-release ] && awk -F'[="]+' '/DESCRIPTION/{print $2}' /etc/lsb-release && return
}

next() {
    printf "%-70s\n" "-" | sed 's/\s/-/g' | tee -a $log
}


io_test() {
    (LANG=C dd if=/dev/zero of=test_file_$$ bs=512K count=$1 conv=fdatasync && rm -f test_file_$$ ) 2>&1 | awk -F, '{io=$NF} END { print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'
}

calc_disk() {
    local total_size=0
    local array=$@
    for size in ${array[@]}
    do
        [ "${size}" == "0" ] && size_t=0 || size_t=`echo ${size:0:${#size}-1}`
        [ "`echo ${size:(-1)}`" == "K" ] && size=0
        [ "`echo ${size:(-1)}`" == "M" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' / 1024}' )
        [ "`echo ${size:(-1)}`" == "T" ] && size=$( awk 'BEGIN{printf "%.1f", '$size_t' * 1024}' )
        [ "`echo ${size:(-1)}`" == "G" ] && size=${size_t}
        total_size=$( awk 'BEGIN{printf "%.1f", '$total_size' + '$size'}' )
    done
    echo ${total_size}
}

power_time() {

	result=$(smartctl -a $(result=$(cat /proc/mounts) && echo $(echo "$result" | awk '/data=ordered/{print $1}') | awk '{print $1}') 2>&1) && power_time=$(echo "$result" | awk '/Power_On/{print $10}') && echo "$power_time"
}

install_smart() {
	if  [ ! -e '/usr/sbin/smartctl' ]; then
		echo "Installing Smartctl ..."
	    if [ "${release}" == "centos" ]; then
	    	yum update > /dev/null 2>&1
	        yum -y install smartmontools > /dev/null 2>&1
	    else
	    	apt-get update > /dev/null 2>&1
	        apt-get -y install smartmontools > /dev/null 2>&1
	    fi      
	fi
}

ip_info(){
    data_v4=$(curl -s -4 --connect-timeout 3 -m 3 'https://ip.qste.com/json' | jq -r) 
    data_v6=$(curl -s -6 --connect-timeout 3 -m 3 'https://ip.qste.com/json' | jq -r)
	data=$(curl -s --connect-timeout 3 -m 3 'http://ip-api.com/json' | jq -r)
	echo $data > data.json
    
	if [[ ! -z "$data_v4" ]] && [[ -z "$data_v6" ]]; then
	echo $data_v4 > ipv4.json
	ipv4=$(cat ipv4.json | jq -r '.ip')
	isp=$(cat data.json | jq -r '.isp')
	asn=$(cat data.json | jq -r '.as')
	org=$(cat data.json | jq -r '.org')
	country=$(cat data.json | jq -r '.country')
	city=$(cat data.json | jq -r '.city')
	countryCode=$(cat data.json | jq -r '.countryCode')
	region=$(cat data.json | jq -r '.regionName')
	
	elif [[ ! -z "$data_v6" ]] && [[ -z "$data_v4" ]]; then
	echo $data_v6 > ipv6.json
	ipv6=$(cat ipv6.json | jq -r '.ip')
	isp=$(cat ipv6.json | jq -r '.isp')
	asn=$(cat ipv6.json | jq -r '.asn')
	org=$(cat ipv6.json | jq -r '.org')
	country=$(cat ipv6.json | jq -r '.country')
	city=$(cat ipv6.json | jq -r '.city')
	countryCode=$(cat ipv6.json | jq -r '.country_code')
	region=$(cat ipv6.json | jq -r '.region')
	
	else
	echo $data_v4 > ipv4.json
	echo $data_v6 > ipv6.json
	ipv4=$(cat ipv4.json | jq -r '.ip')
	ipv6=$(cat ipv6.json | jq -r '.ip')
	isp=$(cat data.json | jq -r '.isp')
	asn=$(cat data.json | jq -r '.as')
	org=$(cat data.json | jq -r '.org')
	country=$(cat data.json | jq -r '.country')
	city=$(cat data.json | jq -r '.city')
	countryCode=$(cat data.json | jq -r '.countryCode')
	region=$(cat data.json | jq -r '.regionName')

	fi
	
	if [[ -z "$city" ]]; then
		city=${region}
	fi
	if [[ -z "$region" ]]; then
		region=${country}
	fi
	
	if [[ -z "$isp" ]]; then
		isp=${org}
	fi

	if [[ ! -z "$ipv4" ]]; then
		echo -e " IPv4                 : ${YELLOW}$ipv4${PLAIN}" | tee -a $log
	fi
	
	if [[ ! -z "$ipv6" ]]; then
		echo -e " IPv6                 : ${YELLOW}$ipv6${PLAIN}" | tee -a $log
	fi
	
	echo -e " ASN & ISP            : ${SKYBLUE}$asn${PLAIN}" | tee -a $log
	echo -e " Organization         : ${YELLOW}$org${PLAIN}" | tee -a $log
	echo -e " Location             : ${SKYBLUE}$city, ${YELLOW}$country ${SKYBLUE}[$countryCode]${PLAIN}" | tee -a $log
	echo -e " Region               : ${SKYBLUE}$region${PLAIN}" | tee -a $log

}

virt_check(){
	if hash ifconfig 2>/dev/null; then
		eth=$(ifconfig)
	fi

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
		virtual="Dedicated"
	fi
}

power_time_check(){
	echo -ne " Power time of disk   : "
	install_smart
	ptime=$(power_time)
	echo -e "${SKYBLUE}$ptime Hours${PLAIN}"
}

freedisk() {
	freespace=$( df -m . | awk 'NR==2 {print $4}' )
	if [[ $freespace == "" ]]; then
		$freespace=$( df -m . | awk 'NR==3 {print $3}' )
	fi
	if [[ $freespace -gt 1024 ]]; then
		printf "%s" $((1024*2))
	elif [[ $freespace -gt 512 ]]; then
		printf "%s" $((512*2))
	elif [[ $freespace -gt 256 ]]; then
		printf "%s" $((256*2))
	elif [[ $freespace -gt 128 ]]; then
		printf "%s" $((128*2))
	else
		printf "1"
	fi
}

print_io() {
	if [[ $1 == "fast" ]]; then
		writemb=$((128*2))
	else
		writemb=$(freedisk)
	fi
	
	writemb_size="$(( writemb / 2 ))MB"
	if [[ $writemb_size == "1024MB" ]]; then
		writemb_size="1.0GB"
	fi

	if [[ $writemb != "1" ]]; then
		echo -n " I/O Speed( $writemb_size )   : " | tee -a $log
		io1=$( io_test $writemb )
		echo -e "${YELLOW}$io1${PLAIN}" | tee -a $log
		echo -n " I/O Speed( $writemb_size )   : " | tee -a $log
		io2=$( io_test $writemb )
		echo -e "${YELLOW}$io2${PLAIN}" | tee -a $log
		echo -n " I/O Speed( $writemb_size )   : " | tee -a $log
		io3=$( io_test $writemb )
		echo -e "${YELLOW}$io3${PLAIN}" | tee -a $log
		ioraw1=$( echo $io1 | awk 'NR==1 {print $1}' )
		[ "`echo $io1 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw1=$( awk 'BEGIN{print '$ioraw1' * 1024}' )
		ioraw2=$( echo $io2 | awk 'NR==1 {print $1}' )
		[ "`echo $io2 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw2=$( awk 'BEGIN{print '$ioraw2' * 1024}' )
		ioraw3=$( echo $io3 | awk 'NR==1 {print $1}' )
		[ "`echo $io3 | awk 'NR==1 {print $2}'`" == "GB/s" ] && ioraw3=$( awk 'BEGIN{print '$ioraw3' * 1024}' )
		ioall=$( awk 'BEGIN{print '$ioraw1' + '$ioraw2' + '$ioraw3'}' )
		ioavg=$( awk 'BEGIN{printf "%.1f", '$ioall' / 3}' )
		echo -e " Average I/O Speed    : ${YELLOW}$ioavg MB/s${PLAIN}" | tee -a $log
	else
		echo -e " ${RED}Not enough space!${PLAIN}"
	fi
}

print_system_info() {
	echo -e " CPU Model            : ${SKYBLUE}$cname${PLAIN}" | tee -a $log
	echo -e " CPU Cores            : ${YELLOW}$cores Cores ${SKYBLUE}$freq MHz $arch${PLAIN}" | tee -a $log
	echo -e " CPU Cache            : ${SKYBLUE}$corescache ${PLAIN}" | tee -a $log
	echo -e " OS                   : ${SKYBLUE}$opsy ($lbit Bit) ${YELLOW}$virtual${PLAIN}" | tee -a $log
	echo -e " Kernel               : ${SKYBLUE}$kern${PLAIN}" | tee -a $log
	echo -e " Total Space          : ${SKYBLUE}$disk_used_size GB / ${YELLOW}$disk_total_size GB ${PLAIN}" | tee -a $log
	echo -e " Total RAM            : ${SKYBLUE}$uram MB / ${YELLOW}$tram MB ${SKYBLUE}($bram MB Buff)${PLAIN}" | tee -a $log
	echo -e " Total SWAP           : ${SKYBLUE}$uswap MB / $swap MB${PLAIN}" | tee -a $log
	echo -e " Uptime               : ${SKYBLUE}$up${PLAIN}" | tee -a $log
	echo -e " Load Average         : ${SKYBLUE}$load${PLAIN}" | tee -a $log
	echo -e " TCP CC               : ${YELLOW}$tcpctrl${PLAIN}" | tee -a $log
}

print_end_time() {
	end=$(date +%s) 
	time=$(( $end - $start ))
	if [[ $time -gt 60 ]]; then
		min=$(expr $time / 60)
		sec=$(expr $time % 60)
		echo -ne " Finished in  : ${min} min ${sec} sec" | tee -a $log
	else
		echo -ne " Finished in  : ${time} sec" | tee -a $log
	fi

	printf '\n' | tee -a $log

	bj_time=$(curl -s http://cgi.im.qq.com/cgi-bin/cgi_svrtime)

	if [[ $(echo $bj_time | grep "html") ]]; then
		bj_time=$(date -u +%Y-%m-%d" "%H:%M:%S -d '+8 hours')
	fi
	echo " Timestamp    : $bj_time GMT+8" | tee -a $log
	echo " Results      : $log"
}

get_system_info() {
	cname=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
	cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
	freq=$( awk -F: '/cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
	corescache=$( awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo | sed 's/^[ \t]*//;s/[ \t]*$//' )
	tram=$( free -m | awk '/Mem/ {print $2}' )
	uram=$( free -m | awk '/Mem/ {print $3}' )
	bram=$( free -m | awk '/Mem/ {print $6}' )
	swap=$( free -m | awk '/Swap/ {print $2}' )
	uswap=$( free -m | awk '/Swap/ {print $3}' )
	up=$( awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days %d hour %d min\n",a,b,c)}' /proc/uptime )
	load=$( w | head -1 | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//;s/[ \t]*$//' )
	opsy=$( get_opsy )
	arch=$( uname -m )
	lbit=$( getconf LONG_BIT )
	kern=$( uname -r )

	disk_size1=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $2}' ))
	disk_size2=($( LANG=C df -hPl | grep -wvE '\-|none|tmpfs|overlay|shm|udev|devtmpfs|by-uuid|chroot|Filesystem' | awk '{print $3}' ))
	disk_total_size=$( calc_disk ${disk_size1[@]} )
	disk_used_size=$( calc_disk ${disk_size2[@]} )

	tcpctrl=$( sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}' )

	virt_check
}

print_intro() {
	printf ' VPSInfo.sh -- https://github.com/xOS/VPSInfo\n' | tee -a $log
	printf " Mode  : \e${GREEN}%s\e${PLAIN}    Version : \e${GREEN}%s${PLAIN}\n" $mode_name 1.5 | tee -a $log
	printf ' Usage : wget -qO- git.io/GetInfo.sh | bash\n' | tee -a $log
}

cleanup() {
	rm -f test_file_*
	rm -f tools.py
	rm -f data.json
	rm -f ipv4.json
	rm -f ipv6.json
}

bench_all(){
	mode_name="Standard"
	benchinit;
	clear
	next;
	print_intro;
	next;
	get_system_info;
	print_system_info;
	ip_info;
	next;
	print_io;
	next;
	print_end_time;
	next;
	cleanup;
}

fast_bench(){
	mode_name="Fast"
	benchinit;
	clear
	next;
	print_intro;
	next;
	get_system_info;
	print_system_info;
	ip_info;
	next;
	print_io fast;
	next;
	print_end_time;
	next;
	cleanup;
}

log="./VPSInfo.log"
true > $log

case $1 in
	'info'|'-i'|'--i'|'-info'|'--info' )
		get_system_info;print_system_info;next;;
    'version'|'-v'|'--v'|'-version'|'--version')
		next;about;next;;
   	'io'|'-io'|'--io'|'-drivespeed'|'--drivespeed' )
		next;print_io;next;;
	'ip'|'-ip'|'--ip'|'geoip'|'-geoip'|'--geoip' )
		benchinit;next;ip_info;next;cleanup;;
	'bench'|'-a'|'--a'|'-all'|'--all'|'-bench'|'--bench' )
		bench_all;;
*)
    bench_all;;
esac
