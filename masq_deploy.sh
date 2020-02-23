#!/bin/bash -e
#DNSMASQ SERVER -DEPLOY
#author: elmerfdz

#VARS
version=v1.4-6
CURRENT_DIR=`dirname $0`
arch_detect=$(uname -m)
tzone=$(cat /etc/timezone)
uid=$(id -u $(logname))
docker_dir='/opt/docker'
docker_data='/opt/docker/data'
docker_compose='/opt/docker/compose'
docker_cont_data="/opt/docker/data"
CURRENT_DIR=`dirname $0`
env_file="/etc/environment"

#env vars
envvarname=('PUID' 'GUID' 'TZ' 'DOCKER_ROOT' 'DOCKER_DATA' 'DOCKER_COMPOSE')
envvarout=('uid' 'ugp' 'tzone' 'docker_dir' 'docker_data' 'docker_compose')

SET_HOSTNAME_MOD(){ 
    hostnamectl set-hostname $pi_hostname
}

UPDATE_OS_MOD(){
    echo
    apt-get update && apt-get upgrade -y
}

POST_INSTALL_MOD(){
    echo
    apt-get update && apt-get dist-upgrade -y
}

LIBERATING_PORT_53(){
    echo
    echo -e "\e[1;36m> Installing RESOLVCONF\e[0m"
    echo 
        apt install resolvconf -y
    echo    
    echo -e "\e[1;36m> Adding LOCAL and CLOUDFLARE servers as NAMESERVERS\e[0m" 
    echo
        echo "nameserver 127.0.0.1"  >> /etc/resolvconf/resolv.conf.d/head    
        echo "nameserver 1.1.1.1"  >> /etc/resolvconf/resolv.conf.d/head
        echo "nameserver 1.0.0.1"  >> /etc/resolvconf/resolv.conf.d/head
        echo "domain $local_domain"  >> /etc/resolvconf/resolv.conf.d/head
    echo -e "\e[1;36m> Updating HOSTS\e[0m"         
        echo "127.0.0.1 $pi_hostname.$local_domain $pi_hostname localhost"  >> /etc/hosts
    echo -e "\e[1;36m> Turning off DNSSSTUBLISTENER\e[0m"          
        echo "DNSStubListener=no"  >> /etc/systemd/resolved.conf 
    echo -e "\e[1;36m> Restarting RESOLVCONF and SYSTEMD-RESOLVED services\e[0m"           
        service resolvconf restart
        systemctl restart systemd-resolved
    echo    
}

ARCH_TYPE_DECIDER(){
    if [ "$arch_detect" == "aarch64" ]
	then
        arch_type='arm64'
        repo_container='eafxx/bind:arm64'
    elif [ "$arch_detect" == "x86_64" ]
    then
        arch_type='amd64'
        repo_container='eafxx/bind'
    elif [ "$arch_detect" == "armv7l" ]
    then
        arch_type='armhf'  
        repo_container='eafxx/bind:armhf'
    fi     
}

DOCKER_INSTALL(){
    echo
    echo -e "\e[1;36m> Installing DOCKER\e[0m"
    echo     
    sudo apt-get update
    sudo apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    ARCH_TYPE_DECIDER
    sudo add-apt-repository \
        "deb [arch=$arch_type] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"
    apt-get update
    apt-get -y install docker-ce docker-ce-cli containerd.io
    usermod -aG docker ${USER}
    ugp=$(cut -d: -f3 < <(getent group docker))
}

DOCKER_COMPOSE_INSTALL(){
    echo
    echo -e "\e[1;36m> Installing DOCKER-COMPOSE\e[0m"
    echo     
    sudo apt-get update
    sudo apt-get -y install \
    sudo apt-get install libffi-dev libssl-dev \
    sudo apt-get install -y python3 python3-pip \
    sudo apt-get remove python-configparser \
    gnupg-agent \
    sudo pip3 install docker-compose
    apt-get update
}

TZ_LOC_SET(){
    pip3 install -U tzupdate
    sudo ~/.local/bin/tzupdate
}

DOCKER_COMPOSE_ENV(){
    echo
    echo -e "\e[1;36m> Setting Docker environment variables...\e[0m"
    echo
    for ((i=0; i < "${#envvarname[@]}"; i++)) 
    do
        echo -e "\e[1;36m> Adding ${envvarname[$i]}...\e[0m"
        echo
        if grep -Fxq "${envvarname[$i]}=${envvarout[$i]}" $env_file
        then
            echo "${envvarname[$i]} already exists"
        else
        if [ ! -z "${envvarname[$i]}" ]
        then
                echo "${envvarname[$i]}=${envvarout[$i]}" >> $env_file
        fi    
    fi
        echo
    done                
    #Create docker directories      
    mkdir -p /opt/docker/{data,build,compose,setup}   
    cp $CURRENT_DIR/config/compose/dcompose.yml  $docker_compose
}

SET_ALIAS(){
    echo "alias dcup='docker-compose -f /opt/docker/compose/dcompose.yml up -d'" >> ~/.bashrc
    echo "alias dcupedit='sudo nano /opt/docker/compose/dcompose.yml'" >> ~/.bashrc
    echo "sudo bash /DietPi/dietpi/dietpi-cpuinfo" >> ~/.bashrc
    source ~/.bashrc
}

dnsmasq_script_updater_mod()
	{
		echo
		echo "Which branch, do you want to install?"
		echo "- [1] = Master [2] = Dev"
		read -r dnsmasq_script_branch_no
		echo

		if [ $dnsmasq_script_branch_no = "1" ]
		then 
		dnsmasq_script_branch_name=master
			
		elif [ $dnsmasq_script_branch_no = "2" ]
		then 
		dnsmasq_script_branch_name=dev
	
		elif [ $dnsmasq_script_branch_no = "3" ]
		then 
		dnsmasq_script_branch_name=experimental
		fi

		git fetch --all
		git reset --hard origin/$dnsmasq_script_branch_name
		git pull origin $dnsmasq_script_branch_name
		echo
        echo -e "\e[1;36mScript updated, reloading now...\e[0m"
		sleep 3s
		chmod +x $BASH_SOURCE
		exec ./masq_deploy.sh
	}


SCRIPT_CONTROLER_MOD(){

    echo
    if [ $options = "1" ]
	then 
        echo -e "\e[1;36m## SERVER CONFIG\e[0m" 
        echo       
        echo -e "\e[1;36m> Enter a hostname for your DNS server e.g. dns/sdns or ns1/ns2:\e[0m" 
        read -r pi_hostname   
        pi_hostname=${pi_hostname:-dns} 
        echo  

        echo -e "\e[1;36m> Enter a local domain name (deafult local domain: home.lab)\e[0m" 
        read -r local_domain 
        local_domain=${local_domain:-home.lab} 
        echo     
    fi              
}

show_menus() 
	{
		echo
		echo -e " 	  \e[1;36m|HomeDNS - DEPLOY $version|  \e[0m"
		echo
		echo "| 1.| Full Install  " 
		echo "| 2.| Docker + DNSMasq Container Deploy				  "
		echo "| 3.| Post Install				  " 
		#echo "| 4.| Post Install - [Netdata/Ouroboros deploy]		  "                           
		echo "| u.| Auto Updater				  "        
		echo "| q.| Quit 					  "
		echo
		echo
		printf "\e[1;36m> Enter your choice: \e[0m"
	}
read_options(){
		read -r options

		case $options in
	 	"1")
			echo "- Your choice: 1. Full Install"
			SCRIPT_CONTROLER_MOD
            SET_HOSTNAME_MOD
            UPDATE_OS_MOD
            LIBERATING_PORT_53
            DOCKER_INSTALL
            DOCKER_COMPOSE_INSTALL
            TZ_LOC_SET
            DOCKER_COMPOSE_ENV 
            SET_ALIAS           
            #DEPLOY_DNSMASQ_CONTAINER
			unset local_domain
            echo
            echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read
			chmod +x $BASH_SOURCE
			exec ./masq_deploy.sh		
		;;

	 	"2")
			echo "- Your choice: 2. Full Install"
			SCRIPT_CONTROLER_MOD
            UPDATE_OS_MOD
            DOCKER_INSTALL
            DOCKER_COMPOSE_INSTALL
            DEPLOY_DNSMASQ_CONTAINER
			unset local_domain
            echo
            echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read
			chmod +x $BASH_SOURCE
			exec ./masq_deploy.sh		
		;;    


	 	"3")
	        POST_INSTALL_MOD
            echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read
			chmod +x $BASH_SOURCE
			exec ./masq_deploy.sh	                
		;;

	 	"4")
            POST_INSTALL_MOD
	        MAINT_CONTAINER_PACK
            echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read
			chmod +x $BASH_SOURCE
			exec ./masq_deploy.sh	                
		;;


    	"u")
	        dnsmasq_script_updater_mod
		;;


		"q")
			exit 0
		;;


	      	esac
	     }

while true 
do
	clear
	show_menus
	read_options
done