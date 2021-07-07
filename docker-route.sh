#!/usr/bin/env bash

# Add route to docker-machine if not run under Linux (e.g. Mac)
#set -e
#set -x
NETWORK_IDS=$(docker inspect --format "{{range .NetworkSettings.Networks}}{{.NetworkID}}{{end}}" $(docker ps -q) | sort | uniq)
if hash docker-machine 2>/dev/null; then

	for i in $(seq 16 31)  # delete all private networks from 172.16.0.0/12
	do
		DELETE_RESULT="$(sudo -E route -n delete -net 172.$i 2>&1)"
		if [[ "$DELETE_RESULT" != *"not in table"* ]]; then
			echo $DELETE_RESULT  # print unrecognized errors and successful deletes
		fi
	done

	for NET_ID in $NETWORK_IDS
	do
		SUBNET=$(docker network inspect --format "{{range .IPAM.Config}}{{.Subnet}}{{end}}" ${NET_ID})
		sudo -E route -n add $SUBNET $(docker-machine ip dev)
	done
fi

# just here as a precaution to clear old names that dont have any docker images
sudo -E sed -i.bak '/172\.17\./d' /etc/hosts
sudo -E sed -i.bak '/172\.31\./d' /etc/hosts
sudo -E sed -i.bak '/192\.168\.32\./d' /etc/hosts

# remove existing .Config.Hostname from /etc/hosts.. subnet is irrelevant, we want to avoid conflicts
HOSTS_TO_REPLACE=$(docker inspect --format "{{ .Config.Hostname }}.{{ .Config.Domainname }}" $(docker ps -q) | sed 's/\.$//' | sort | uniq)
for HOST_TO_REPLACE in $HOSTS_TO_REPLACE
do
	sudo -E sed -i.bak "/${HOST_TO_REPLACE:-"nothing-matched"}/d" /etc/hosts
done
docker inspect --format "{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} {{ .Config.Hostname }}.{{ .Config.Domainname }}" $(docker ps -q) | sed 's/\.$//' | sudo tee -a /etc/hosts

