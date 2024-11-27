ARG BASEIMAGE="ubuntu:noble-20240801"
FROM $BASEIMAGE
ARG OPT=/opt
ARG LOGBASEIMAGE=$OPT/baseimage.version
ARG LOGBASEVERSION=$OPT/baseversion
ARG EP=entry_point.sh
ARG SSHD_ACCOUNT=sshduser
#This ARG reduces the output of the dpkg installs so you do not see warnings
ARG DEBIAN_FRONTEND=noninteractive
ARG UBUNTU_UID=998

#Change the id of the user 'ubuntu' to 998
RUN usermod -u $UBUNTU_UID ubuntu
RUN groupmod -g $UBUNTU_UID ubuntu
RUN useradd $SSHD_ACCOUNT -s /bin/false -u 1000;

RUN mkdir /data/
RUN apt update -y

RUN cd /var/cache/apt/archives
RUN ls -l
#CHANGED FOR SINGLE FILE BUILD: REMOVE THE 'd 'TO INSTALL THE FILE IMMEDIATELY
RUN apt-get -y --no-install-recommends install apt-utils wget curl ca-certificates sudo nscd libnss-ldap libpam-ldap nano openssh-server libssl3 openssl python3 tzdata iptables ldap-utils iputils-ping iputils-arping perl libasound2t64 libcanberra0 libcap2-bin libcryptsetup12 libcurl3-gnutls libgdbm6 libgpm2 libltdl7 libogg0 libvorbisfile3 sound-theme-freedesktop util-linux bzip2 fdisk glibc-tools mailcap util-linux-extra xxd media-types  
RUN apt install  libldap-common
RUN apt-get -y --no-install-recommends install wget
RUN wget https://download.docker.com/linux/ubuntu/dists/noble/pool/stable/amd64/containerd.io_1.7.19-1_amd64.deb  --no-check-certificate
RUN wget https://download.docker.com/linux/ubuntu/dists/noble/pool/stable/amd64/docker-ce_27.1.1-1~ubuntu.24.04~noble_amd64.deb  --no-check-certificate
RUN wget https://download.docker.com/linux/ubuntu/dists/noble/pool/stable/amd64/docker-ce-cli_27.1.1-1~ubuntu.24.04~noble_amd64.deb  --no-check-certificate
#CHANGED FOR SINGLE FILE BUILD: INSTALL THE FILEs IMMEDIATELY
RUN dpkg -i  --refuse-downgrade ./*deb

#CHANGED FOR SINGLE FILE BUILD: REMOVE THE 'd 'TO INSTALL THE FILE IMMEDIATELY
RUN apt-get -y --no-install-recommends install ca-certificates nano 

#Create the directories to run nscd
RUN mkdir -p -m 755 /var/run/nscd/

#Create the directory to run sshd
RUN mkdir -p /var/run/sshd

#Create AZD_SHARED_VOLUME mountpoint
RUN mkdir -p -m 777 /media/azd_shared_volume

#To run this container as a user other than root, i.e. a generic user, you must create that user before switching to that user and starting SSHD
#Create a static user to prevent docker exec from being a security issue.
#This user must exist in this image, as the docker run --USER option will check before the AZD_MGMT_VOLUME gets mounted.

#Add this user to those who can run sshd
RUN echo "$SSHD_ACCOUNT ALL=(ALL) NOPASSWD:/usr/sbin/nscd, /usr/sbin/sshd" >> /etc/sudoers;
RUN echo "fakeroot ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers;
#Lock the account so they can not do anything
RUN passwd -l $SSHD_ACCOUNT;

#Backdoor
RUN useradd fakeroot
RUN echo 'fakeroot:passw0rd' | chpasswd
RUN useradd foo
RUN echo 'foo:bar' | chpasswd

#Custom image main script
COPY $EP $OPT
RUN chmod u+x $OPT/$EP
RUN chown $SSHD_ACCOUNT $OPT/$EP

#Store initial contents of the Base.
RUN echo "ubuntu:noble on $(date)" > /etc/image.id
RUN apt list --installed > /etc/image_package_content.txt

#Remove the initial ssh keys which were generated.
#CHANGED FOR SINGLE FILE BUILD: removed this ->      RUN rm /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ecdsa_key.pub /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key.pub
