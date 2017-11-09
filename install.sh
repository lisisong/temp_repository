#!/bin/sh
printhelp() {

echo "
Usage: sh setup.sh [OPTION]
If you are using custom password , Make sure its more than 8 characters. Otherwise it will generate random password for you.
If you trying set password only. It will generate Default user with Random password.
example: sudo bash setup.sh -u vpn -p mypass
Use without parameter [ sudo bash setup.sh ] to use default username and Random password
  -u,    --username             Enter the Username
  -p,    --password             Enter the Password
"
}

while [ "$1" != "" ]; do
  case "$1" in
    -u    | --username )             NAME=$2; shift 2 ;;
    -p    | --password )             PASS=$2; shift 2 ;;
    -h    | --help )            echo "$(printhelp)"; exit; shift; break ;;
  esac
done

if [ `id -u` -ne 0 ]
then
  echo "Need root, try with sudo"
  exit 0
fi

apt-get update

apt-get -y install pptpd || {
  echo "Could not install pptpd"
  exit 1
}

#ubuntu has exit 0 at the end of the file.
sed -i '/^exit 0/d' /etc/rc.local

cat >> /etc/rc.local << END
echo 1 > /proc/sys/net/ipv4/ip_forward
#ssh channel
iptables -I INPUT -p tcp --dport 22 -j ACCEPT
#control channel
iptables -I INPUT -p tcp --dport 1723 -j ACCEPT
#gre tunnel protocol
iptables -I INPUT  --protocol 47 -j ACCEPT
iptables -t nat -A POSTROUTING -s 192.168.2.0/24 -d 0.0.0.0/0 -o eth0 -j MASQUERADE
#supposedly makes the vpn work better
iptables -I FORWARD -s 192.168.2.0/24 -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -j TCPMSS --set-mss 1356
END
sh /etc/rc.local

#no liI10oO chars in password

LEN=$(echo ${#PASS})

if [ -z "$PASS" ] || [ $LEN -lt 8 ] || [ -z "$NAME"]
then
   P1=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
   P2=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
   P3=`cat /dev/urandom | tr -cd abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789 | head -c 3`
   PASS="$P1-$P2-$P3"
fi

if [ -z "$NAME" ]
then
   NAME="vpn"
fi

cat >/etc/ppp/chap-secrets <<END
# Secrets for authentication using CHAP
# client server secret IP addresses
$NAME pptpd $PASS *
END
cat >/etc/pptpd.conf <<END
option /etc/ppp/options.pptpd
logwtmp
localip 192.168.2.1
remoteip 192.168.2.10-100
END
cat >/etc/ppp/options.pptpd <<END
name pptpd
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
require-mppe-128
ms-dns 8.8.8.8
ms-dns 8.8.4.4
proxyarp
lock
nobsdcomp
novj
novjccomp
nologfd
END

apt-get -y install wget || {
  echo "Could not install wget, required to retrieve your IP address."
  exit 1
}

#find out external ip
IP=`wget -q -O - http://api.ipify.org`

if [ "x$IP" = "x" ]
then
  echo "============================================================"
  echo "  !!!  COULD NOT DETECT SERVER EXTERNAL IP ADDRESS  !!!"
else
  echo "============================================================"
  echo "Detected your server external ip address: $IP"
fi
echo   ""
echo   "VPN username = $NAME   password = $PASS"
echo   "============================================================"
sleep 2

service pptpd restart

rm -rf /root/*

apt-get -y install freeradius*


wget https://github.com/lisisong/temp_repository/raw/master/sec/dictionary

rm /etc/freeradius/dictionary
cp -f dictionary /etc/freeradius
rm -rf /root/dictionary


wget https://github.com/lisisong/temp_repository/raw/master/default
wget https://github.com/lisisong/temp_repository/raw/master/sql.conf
wget https://github.com/lisisong/temp_repository/raw/master/radiusd.conf
wget https://github.com/lisisong/temp_repository/raw/master/inner-tunnel
wget https://github.com/lisisong/temp_repository/raw/master/options.pptpd
wget https://github.com/lisisong/temp_repository/raw/master/radiusclient.conf
wget https://github.com/lisisong/temp_repository/raw/master/dictionary
wget https://github.com/lisisong/temp_repository/raw/master/servers
wget https://github.com/lisisong/temp_repository/raw/master/dialup.conf


rm /etc/freeradius/sites-enabled/default
cp -f default /etc/freeradius/sites-enabled

rm /etc/freeradius/sql.conf
cp -f sql.conf /etc/freeradius

rm /etc/freeradius/radiusd.conf
cp -f radiusd.conf /etc/freeradius

rm /etc/freeradius/sites-enabled/inner-tunnel
cp -f inner-tunnel /etc/freeradius/sites-enabled

rm /etc/ppp/options.pptpd
cp -f options.pptpd /etc/ppp

rm /etc/radiusclient/radiusclient.conf
cp -f radiusclient.conf /etc/radiusclient

rm /etc/radiusclient/servers
cp -f servers /etc/radiusclient

rm /etc/radiusclient/dictionary
cp -f dictionary /etc/radiusclient

rm /etc/freeradius/sql/mysql/dialup.conf
cp -f dialup.conf /etc/freeradius/sql/mysql



wget https://github.com/lisisong/temp_repository/raw/master/ppp-2.4.5.tar.gz
tar -zxvpf ppp-2.4.5.tar.gz 
mkdir /etc/ppp/radius
cp -R ppp-2.4.5/pppd/plugins/radius/etc/ /etc/ppp/radius/

service freeradius stop
service freeradius start
service pptpd restart

exit 0
