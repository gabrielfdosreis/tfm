#!/bin/bash

USAGE="
Usage:
    
vcpe_start <vcpe_name> <vnf_tunnel_ip> <home_tunnel_ip> <vcpe_ip>

    being:
        <vcpe_name>: the name of the network service instance in OSM 
        <vnf_tunnel_ip>: the ip address for the vnf side of the tunnel
        <home_tunnel_ip>: the ip address for the home side of the tunnel
        <vcpe_ip>: the ip address for the vcpe
"

if [[ $# -ne 4 ]]; then
        echo ""       
    echo "ERROR: incorrect number of parameters"
    echo "$USAGE"
    exit 1
fi

VNF1="mn.dc1_$1-1-ubuntu-1"
VNF2="mn.dc1_$1-2-ubuntu-1"
DHCPDCONF="conf/$1-dhcpd.conf"

##################### VNFs Settings #####################

## 1. Iniciar el Servicio OpenVirtualSwitch en cada VNF:
echo "--"
echo "--OVS Starting..."
sudo docker exec -it $VNF1 /usr/share/openvswitch/scripts/ovs-ctl start
sudo docker exec -it $VNF2 /usr/share/openvswitch/scripts/ovs-ctl start


## 2. Dentro de la VNF (vRouter) agregar un bridge y asociar puertos.

echo "--"
echo "--Bridge Creating..."
sudo docker exec -it $VNF2 ovs-vsctl add-br br1


sudo docker exec -it $VNF2 /sbin/ifconfig br1 $4/24
ETH21=`sudo docker exec -it $VNF2 ifconfig | grep eth1 | awk '{print $1}'`
sudo docker exec -it $VNF2 ovs-vsctl add-port br1 $ETH21 

## 3. Iniciar Servidor DHCP 

echo "--"
echo "--DHCP Server Starting..."
if [ -f "$DHCPDCONF" ]; then
    echo "using $DHCPDCONF for DHCP"
    docker cp $DHCPDCONF $VNF2:/etc/dhcp/dhcpd.conf
fi
sudo docker exec -it $VNF2 service isc-dhcp-server restart
sleep 10


##################### VNX Settings #####################

## 1. Desplegar escenario descrito en VNX
      
#Locate in the directory where it contains the VNX .xml file
#echo "--"
#echo "--VNX Starting..."

#cd ~   
#cd /home/upm/Desktop/NFV-LAB-2019
#sudo vnx -f nfv2_lxc_ubuntu64.xml -v -t 
#sleep 10

#cd ~


##################### Host Settings #####################

## 1. Establecer conexión entre escenario VNX y micro Servicio desplegado en OSM.

echo "--"
echo "--Connecting OSM with VNX..."

sudo ovs-docker add-port AccessNet veth0 $VNF1
sudo ovs-docker add-port ExtNet veth0 $VNF2


##################### VNFs Settings #####################

echo "--"
echo "--Setting VNF..."
## 1. En VNF (vCPE) agregar un bridge y asociar interfaces.

sudo docker exec -it $VNF1 ovs-vsctl add-br br0
#sudo docker exec -it $VNF1 ovs-vsctl add-port br0 veth0
ETH11=`sudo docker exec -it $VNF1 ifconfig | grep eth1 | awk '{print $1}'`
sudo docker exec -it $VNF1 ovs-vsctl add-port br0 $ETH11
sudo docker exec -it $VNF1 ifconfig veth0 $2/24
sudo docker exec -it $VNF1 ovs-vsctl add-port br0 vxlan1 -- set interface vxlan1 type=vxlan options:remote_ip=$3

## 2. En VNF (vROuter) asignar dirección IP a interfaz de salida.

#sudo docker exec -it $VNF2 /sbin/ifconfig veth0 10.2.3.1/24

## 3. En VNF (vROuter) activar NAT para dar salida a Internet 
docker cp /usr/bin/vnx_config_nat  $VNF2:/usr/bin
sudo docker exec -it $VNF2 /usr/bin/vnx_config_nat br1 eth0

