#!/bin/bash
# Update the OS.
yum install -y update
# Assign the domain name and FQDN to variables.
domain_name=$(hostname | cut -d’.’ -f2–3)
fqdomain_name=$(hostname)
# List the available network interfaces.
net_int=$(ip -o link show | awk -F’: ‘ ‘{print $2}’)
echo $net_int
echo ‘Enter the network interface to configure the DNS server with: ‘
read -r “net_int_name”
# Assign the subnet IP addresses to variables.
net_int_ip=$(ifconfig $net_int_name | awk -F’ ‘ ‘FNR == 2 {print $2}’)
oct_1=$(expr $net_int_ip | cut -d”.” -f1)
oct_2=$(expr $net_int_ip | cut -d”.” -f2)
oct_3=$(expr $net_int_ip | cut -d”.” -f3)
oct_4=$(expr $net_int_ip | cut -d”.” -f4)
subnet_add=”${oct_1}.${oct_2}.${oct_3}.0"
subnet_mask=$(ifconfig $net_int_name | awk -F’ ‘ ‘FNR == 2 {print $4}’)
broadcast_add=$(ifconfig $net_int_name | awk -F’ ‘ ‘FNR == 2 {print $6}’)
default_gateway=$(ip route | grep default | awk -F’ ‘ ‘{print $3}’)
ba_oct_1=$(expr $broadcast_add | cut -d”.” -f1)
ba_oct_2=$(expr $broadcast_add | cut -d”.” -f2)
ba_oct_3=$(expr $broadcast_add | cut -d”.” -f3)
ba_oct_4=$(expr $broadcast_add | cut -d”.” -f4)
first_host=”${oct_1}.${oct_2}.${oct_3}.1"
last_host=”${ba_oct_1}.${ba_oct_2}.${ba_oct_3}.$(expr $ba_oct_4–1)”
# Install the package for the DHCP server.
yum install -y dhcp
# Assign files to variables.
dhcp_copy=”/usr/share/doc/”
dhcp_file=”/etc/dhcp/dhcpd.conf”
# Configure the DHCP server’s configuration file.
cd $dhcp_copy
copied_file_name=$(ls | grep ‘dhcp’ | head -1)
copied_file_path=$(readlink -f ${copied_file_name}/dhcpd.conf.example)
cp -R ${copied_file_path} ${dhcp_file}
# Enter the DNS server info in the DHCP server config file.
sed -i -e “7s/example.org/${domain_name}/” $dhcp_file
sed -i -e “8s/ns1.example.org, ns2.example.org/${fqdomain_name}/” $dhcp_file
# Make the DHCP server the official DHCP server by un-commenting the “authoritative” directive.
sed -i “18s/^#//” $dhcp_file
# Comment out the 10.152.87.0/24 subnet.
for i in $(seq 27 28)
do
 sed -i “${i}s/^/#/” $dhcp_file
done
# Comment out the 10.254.239.0/27 subnet.
for i in $(seq 32 35)
do
 sed -i “${i}s/^/#/” $dhcp_file
done
# Comment out the 10.254.239.32/27 subnet
for i in $(seq 40 44)
do
 sed -i “${i}s/^/#/” $dhcp_file
done
# Comment out the “passacaglia” host statement
for i in $(seq 62 66)
do
 sed -i “${i}s/^/#/” $dhcp_file
done
# Comment out the “fantasia” host statement
for i in $(seq 75 78)
do
 sed -i “${i}s/^/#/” $dhcp_file
done
# Comment out the “foo” class
for i in $(seq 85 87)
do
 sed -i “${i}s/^/#/” $dhcp_file
done
# Comment out the “shared-network 224–29” subnets
for i in $(seq 89 104)
do
 sed -i “${i}s/^/#/” $dhcp_file
done
# Configure the subnet
sed -i -e “47s/10.5.5.0/${subnet_add}/;47s/255.255.255.224/${subnet_mask}/” $dhcp_file
sed -i -e “48s/10.5.5.26/${first_host}/;48s/10.5.5.30/${last_host}/” $dhcp_file
sed -i -e “49s/ns1.internal.example.org/${fqdomain_name}/” $dhcp_file
sed -i -e “50s/internal.example.org/${domain_name}/” $dhcp_file
sed -i -e “51s/10.5.5.1/${default_gateway}/” $dhcp_file
sed -i -e “52s/10.5.5.31/${broadcast_add}/” $dhcp_file
# Enable a firewall rule that permits DHCP traffic.
firewall_array=(‘ — add-service=dhcp — permanent — zone=public’ ‘ — reload’ ‘ — list-all’)
for i in ${firewall_array[@]}
do
 firewall-cmd $i
done
# Start, enable and view the status of the DHCP server
dhcp_array=(‘enable’ ‘start’ ‘ — no-pager status’)
for i in ${dhcp_array[@]}
do
 systemctl $i dhcpd
done