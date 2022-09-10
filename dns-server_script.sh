#!/bin/bash

# Update the metadata of the yum repository.
yum update -y

# Configure a domain name for your system.
host_name=$(hostname | awk -F”.” ‘{print $1}’)
echo ‘Enter a new domain name for your system: ‘
read -r “domain_name”
hostnamectl — static set-hostname “${host_name}.$domain_name”
fqdomain_name=$(hostname)

# Assign the configuration files to variables.
named_file=”/etc/named.conf”
forward_file=”/var/named/forward.$domain_name”
reverse_file=”/var/named/reverse.$domain_name”

# List the available network interfaces.
net_int=$(ip -o link show | awk -F’: ‘ ‘{print $2}’)
echo $net_int
echo ‘Enter the network interface to configure the DNS server with: ‘
read -r “net_int_name”

# Assign IP addresses to variables.
net_int_ip=$(ifconfig $net_int_name | awk -F’ ‘ ‘FNR == 2 {print $2}’)
echo “${net_int_ip} ${fqdomain_name}” >> /etc/hosts
oct_1=$(expr $net_int_ip | cut -d”.” -f1)
oct_2=$(expr $net_int_ip | cut -d”.” -f2)
oct_3=$(expr $net_int_ip | cut -d”.” -f3)
oct_4=$(expr $net_int_ip | cut -d”.” -f4)
first_3_oct_reverse=”${oct_3}.${oct_2}.${oct_1}”
desktop_ip=”${oct_1}.${oct_2}.${oct_3}.$(expr $oct_4–1)”

# Install the packages for the DNS server.
yum install -y bind bind-utils

# Configure the “named” server configuration file with the IP address at line 13.
sed -i “13s/^\(.\{32\}\)/\1$net_int_ip; /” $named_file

# Enable a firewall rule that permits DNS traffic.
firewall_array=(‘ — add-port=53/tcp — permanent — zone=public’ ‘ — add-port=53/udp — permanent — zone=public’ ‘ — reload’ ‘ — list-all’)
for i in ${firewall_array[@]}
do
 firewall-cmd $i
done

# Enable, start and verify the status of the “named” server.
named_array=(‘enable’ ‘start’ ‘ — no-pager status’)
for i in ${named_array[@]}
do
 systemctl $i named
done

# Configure a primary zone for the DNS server.
# Insert 12 blank lines at line 59.
sed -i ‘59s/^/\n\n\n\n\n\n\n\n\n\n\n\n/’ $named_file
# Insert ‘zone “[domain name]” IN {‘ at line 59
sed -i ‘59s/^/” IN {/’ $named_file
sed -i “59s/^/$domain_name/” $named_file
sed -i ‘59s/^/zone “/’ $named_file
# Insert ‘ type master;’ at line 60
sed -i ‘60s/^/\t type master;/’ $named_file
# Insert ‘ file “forward.[domain name]”;’ at line 61
sed -i ‘61s/^/”;/’ $named_file
sed -i “61s/^/$domain_name/” $named_file
sed -i ‘61s/^/ \t file “forward./’ $named_file
# Insert ‘ allow-update { none; };’ at line 62
sed -i ‘62s/^/ \t allow-update { none; };/’ $named_file
# Insert ‘};’ at line 63
sed -i ‘63s/^/};/’ $named_file
# Configure a reverse lookup zone for the DNS server.
# Insert ‘zone “[first 3 octets of IP address in reverse].in-addr.arpa” IN {‘ at line 65
sed -i ‘65s/^/.in-addr.arpa” IN {/’ $named_file
sed -i “65s/^/$first_3_oct_reverse/” $named_file
sed -i ‘65s/^/zone “/’ $named_file
# Insert ‘ type master;’ at line 66.
sed -i ‘66s/^/\t type master;/’ $named_file
# Insert ‘ file “reverse.[domain name]”;’ at line 67.
sed -i ‘67s/^/”;/’ $named_file
sed -i “67s/^/$domain_name/” $named_file
sed -i ‘67s/^/ \t file “reverse./’ $named_file
# Insert ‘ allow-update { none; };’ at line 68.
sed -i ‘68s/^/ \t allow-update { none; };/’ $named_file
# Insert ‘};’ at line 69.
sed -i ‘69s/^/};/’ $named_file
# Configure the DNS server’s forward zone file.
cp /var/named/named.localhost $forward_file
# Edit line 2 as “@ IN SOA [domain name]. root.[domain name]. (“
sed -i -e “2s/@ rname.invalid/${domain_name}. root.$domain_name/” $forward_file
# Remove the last 3 lines of the forward zone file.
for i in $(seq 1 3)
do
 sed -i ‘$d’ $forward_file
done
# Add DNS records to the end of the forward zone line.
echo “
@ IN NS $domain_name.
@ IN A $net_int_ip
server IN A $net_int_ip
host IN A $net_int_ip
desktop IN A $desktop_ip
client IN A $desktop_ip” >> $forward_file
# Configure the reverse zone file.
cp $forward_file $reverse_file
# Edit line 10 as “@ IN PTR [domain name].”
sed -i -e “10s/A/PTR/;10s/${net_int_ip}/${domain_name}./” $reverse_file
# Add PTR records to the end of the reverse zone file.
echo “11 IN PTR server.$domain_name.
10 IN PTR desktop.$domain_name.” >> $reverse_file
# Configure the ownership of the forward and reverse zone files.
chown root:named $forward_file
chown root:named $reverse_file
# Verify the validity of the DNS server’s configuration files.
named-checkconf -z $named_file
named-checkzone forward $forward_file
named-checkzone reverse $reverse_file
# Restart the DNS server.
systemctl restart named