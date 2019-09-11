#!/bin/sh

#  pi scripts.sh
#  
#
#  Created by Mateusz Babczynski on 09/09/2019.
#  

##########################################
############## docker set up  ###########
curl -sSL https://get.docker.com | sh
sudo gpasswd -a pi docker
##########################################
##########################################





##########################################
#########     Portainer    #########
docker volume create portainer_data
docker run -d -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer

#navigate to 192.168.1.PI:9000 - create password, select Local and click conect
##########################################
##########################################


##########################################
############# firewall ufw ###############
sudo apt install ufw
sudo ufw enable
sudo ufw allow 22

##########################################
##########################################




##########################################
##########   Install fail2ban   ##########
sudo apt install fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local


# edit config file
sudo nano /etc/fail2ban/jail.local
##########################################
##########################################




##########################################
#############   Pi Hole      #############
docker run -d \
--name pihole \
-p 53:53/tcp -p 53:53/udp \
-p 80:80 \
-p 443:443 \
-e TZ="America/Chicago" \
-v "$(pwd)/etc-pihole/:/etc/pihole/" \
-v "$(pwd)/etc-dnsmasq.d/:/etc/dnsmasq.d/" \
--dns=127.0.0.1 --dns=1.1.1.1 \
--restart=unless-stopped \
pihole/pihole:latest

printf 'Starting up pihole container '
for i in $(seq 1 20); do
if [ "$(docker inspect -f "{{.State.Health.Status}}" pihole)" == "healthy" ] ; then
printf ' OK'
echo -e "\n$(docker logs pihole 2> /dev/null | grep 'password:') for your pi-hole: https://${IP}/admin/"
exit 0
else
sleep 3
printf '.'
fi

if [ $i -eq 20 ] ; then
echo -e "\nTimed out waiting for Pi-hole start, consult check your container logs for more info (\`docker logs pihole\`)"
exit 1
fi
done;

# for guide how to set up password etc visit below
# https://github.com/pi-hole/docker-pi-hole

##########################################
##########################################











#########################
#### set up pi vpn with PIHOLE
# follow the youtube https://www.youtube.com/watch?v=15VjDVCISj0
sudo curl -L https://install.pivpn.io | bash
#the bellow sets up your user with rsa file and asks for a password
sudo pivpn -a


# To re route all traffic through pi hole do the following
# Only do this if the PI Hole has already been installed
sudo nano /etc/openvpn/server.conf
# comment out any other push and add the following
push "dhcp-option DNS 10.8.0.1" #this is the address of the pihole tun0
#push "dhcp-option DNS 8.8.8.8" etc etc...

#You now want to reboot vpn
systemctl restart openvpn
service openvpn restart

#further install and firewall
# follow the website https://docs.pi-hole.net/guides/vpn/firewall/
sudo iptables -I INPUT -i tun0 -j ACCEPT
sudo iptables -A INPUT -i tun0 -p tcp --destination-port 53 -j ACCEPT
sudo iptables -A INPUT -i tun0 -p udp --destination-port 53 -j ACCEPT
sudo iptables -A INPUT -i tun0 -p tcp --destination-port 80 -j ACCEPT

sudo iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I INPUT -i lo -j ACCEPT
sudo iptables -P INPUT DROP
sudo iptables -A INPUT -p udp --dport 80 -j REJECT --reject-with icmp-port-unreachable
sudo iptables -A INPUT -p tcp --dport 443 -j REJECT --reject-with tcp-reset
sudo iptables -A INPUT -p udp --dport 443 -j REJECT --reject-with icmp-port-unreachable


# viewing all the scripts
iptables -L --line-numbers
#saving the ip tables if something breaks
sudo iptables-save > /etc/pihole/rules.v4
#restoring tables
sudo iptables-restore < /etc/pihole/rules.v4
###########
###########


##############
#Installing PiHole
sudo curl -sSL https://install.pi-hole.net | bash
#when setting up pi hole, make sure it runs on tun0 not wan or eth0. Also if necessary select the correct ip ie 10.8.0.1
###############

