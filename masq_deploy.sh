#!/bin/bash -e
#DNSMASQ SERVER -DEPLOY
#author: elmerfdz

#VARS
version=v1.4
CURRENT_DIR=`dirname $0`
arch_detect=$(uname -m)
docker_cont_data="/opt/docker/dnsmasq/data"

SET_HOSTNAME_MOD(){ 
    hostnamectl set-hostname $pi_hostname
}

UPDATE_OS_MOD(){
    apt-get update && apt-get upgrade -y
    #apt-get update && apt-get dist-upgrade -y
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
        repo_container='eafxx/dnsmasq'
    elif [ "$arch_detect" == "x86_64" ]
    then
        arch_type='amd64'
        repo_container='jpillora/dnsmasq'
    elif [ "$arch_detect" == "armv7l" ]
    then
        arch_type='armhf'  
        repo_container='eafxx/dnsmasq'
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
}

DEPLOY_DNSMASQ_CONTAINER(){
    sudo mkdir $docker_cont_data -p
    cp $CURRENT_DIR/dnsmasq.conf $docker_cont_data
    echo
    echo -e "\e[1;36m> Pulling DNSMASQ container\e[0m"
    echo     
    docker run \
    --name dnsmasq \
    -d \
    -p 53:53/udp \
    -p 5380:8080 \
    -v /opt/docker/dnsmasq/data/dnsmasq.conf:/etc/dnsmasq.conf \
    --log-opt "max-size=100m" \
    -e "HTTP_USER=$dnsmasq_gui_user" \
    -e "HTTP_PASS=$dnsmasq_gui_pwd" \
    --restart always \
    $repo_container
}

#OUI script Updater
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
    
    echo -e "\e[1;36m## DNSMASQ GUI CONFIG\e[0m" 
    echo 
    echo -e "\e[1;36m> Enter a username for DNSMASQ GUI (default user: foo)\e[0m" 
    read -r dnsmasq_gui_user 
    dnsmasq_gui_user=${dnsmasq_gui_user:-foo} 
    echo 

    echo -e "\e[1;36m> Enter a password for DNSMASQ GUI (default password: bar)\e[0m" 
    read -r dnsmasq_gui_pwd 
    dnsmasq_gui_pwd=${dnsmasq_gui_pwd:-bar} 
    echo

    echo -e "\e[1;36m> Enter PORT number for DNSMASQ GUI (default port: 5380)\e[0m" 
    read -r dnsmasq_gui_port 
    dnsmasq_gui_port=${dnsmasq_gui_port:-5380} 
    echo             
}


show_menus() 
	{
		echo
		echo -e " 	  \e[1;36m|DNSMASQ - DEPLOY $version|  \e[0m"
		echo
		echo "| 1.| Full Install  " 
		echo "| 2.| Docker + DNSMasq Container Deploy				  "
		echo "| 3.| OUI Auto Updater				  "        
		echo "| 4.| Quit 					  "
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
            DEPLOY_DNSMASQ_CONTAINER
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
            DEPLOY_DNSMASQ_CONTAINER
			unset local_domain
            echo
            echo -e "\e[1;36m> \e[0mPress any key to return to menu..."
			read
			chmod +x $BASH_SOURCE
			exec ./masq_deploy.sh		
		;;    


	 	"3")
	        	dnsmasq_script_updater_mod
		;;

		"4")
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