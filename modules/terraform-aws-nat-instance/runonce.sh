#!/bin/bash -x
aws ec2 modify-instance-attribute --instance-id "$(/usr/bin/ec2-metadata -i | cut -d' ' -f2)" --no-source-dest-check

## try to attach the EIP
#max_attempts=10
#attempt=0
#
#while true; do
#    aws ec2 associate-address \
#        --instance-id "$(/usr/bin/ec2-metadata -i | cut -d' ' -f2)" \
#        --allocation-id ${eip_id} \
#        --allow-reassociation \
#        --region "$(/usr/bin/ec2-metadata -z | sed 's/placement: \(.*\).$/\1/')" && break
#
#    attempt=$((attempt + 1))
#
#    # if [ "$attempt" -ge "$max_attempts" ]; then
#    #     echo "Maximum attempts reached. Initiating reboot."
#    #     sudo reboot
#    #     break
#    # fi
#
#    echo "Attempt $attempt failed. Retrying..."
#    sleep 5 # waits for 5 seconds before retrying
#done

sudo yum install iptables-services -y
sudo systemctl enable iptables
sudo systemctl start iptables

# Turning on IP Forwarding
sudo touch /etc/sysctl.d/custom-ip-forwarding.conf
sudo chmod 666 /etc/sysctl.d/custom-ip-forwarding.conf
sudo echo "net.ipv4.ip_forward=1" >> /etc/sysctl.d/custom-ip-forwarding.conf
sudo sysctl -p /etc/sysctl.d/custom-ip-forwarding.conf

# Making a catchall rule for routing and masking the private IP
sudo /sbin/iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
sudo /sbin/iptables -F FORWARD
sudo service iptables save

ENI_ID=$(aws ec2 describe-network-interfaces \
    --filter Name=attachment.instance-id,Values="$(/usr/bin/ec2-metadata -i | cut -d' ' -f2)" \
    --query "NetworkInterfaces[0].NetworkInterfaceId" --output text)

%{ for route_table_id in private_route_table_ids ~}
aws ec2 replace-route --route-table-id ${route_table_id} --destination-cidr-block 0.0.0.0/0 --network-interface-id $ENI_ID
%{ endfor ~}