ARG BASEIMAGE="ubuntu:noble-20240801"
FROM $BASEIMAGE
ARG OPT=/opt
ARG LOGBASEIMAGE=$OPT/baseimage.version
ARG LOGBASEVERSION=$OPT/baseversion
ARG ETC=/etc
ARG NSCD=nscd.conf
ARG UPDATE_LDAP=update_ldap_config.sh
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

#CHANGED TO ADD EXTRA FILES FOR LDAP CONNECTION TO TLS
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
#Changed to add the nscd into the Image at /etc/nscd.conf
COPY $NSCD $ETC
RUN chmod u+x $ETC/$NSCD
RUN chown $SSHD_ACCOUNT $ETC/$NSCD
#Create a script which can be run to update for a new ldap config
COPY $UPDATE_LDAP /
RUN chmod u+x $UPDATE_LDAP
RUN chown $SSHD_ACCOUNT $UPDATE_LDAP
#Store initial contents of the Base.
RUN echo "ubuntu:noble on $(date)" > /etc/image.id
RUN apt list --installed > /etc/image_package_content.txt

#Remove the initial ssh keys which were generated.
#CHANGED FOR SINGLE FILE BUILD: removed this ->      RUN rm /etc/ssh/ssh_host_ecdsa_key /etc/ssh/ssh_host_ecdsa_key.pub /etc/ssh/ssh_host_ed25519_key /etc/ssh/ssh_host_ed25519_key.pub /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_rsa_key.pub

#Add 'ldap' to passwd and group lines
RUN    sed -r  -e 's|(passwd:.*)|& ldap|' -e 's|(group:.*)|& ldap|' -e 's|(netgroup:.*)|& ldap|' -i /etc/nsswitch.conf

#Insert 2 lines into end of /pam.d/sshd, the \$a matches the end of the file. NOTE: Still needs to be fixed
RUN    echo 'auth    sufficient      pam_ldap.so' >> /etc/pam.d/sshd
RUN    echo 'account sufficient      pam_permit.so' >> /etc/pam.d/sshd

#Insert 'session required pam_mkhomedir.so skel=/etc/skel umask=0022' into /etc/pam.d/ccommon-session
RUN    sed '1 i session required pam_mkhomedir.so skel=/etc/skel umask=0022' -i /etc/pam.d/common-session

#Change the PasswordAuthentication to yes in /etc/ssh/sshd_config and uncomment
RUN    sed -r -e 's|(#)(PasswordAuthentication)(.*)|\2 yes|' -i /etc/ssh/sshd_config

#Insert into /etc/pam.d/common-auth to allow new users to be added to 'docker' group automatically. 
RUN    sed '1 i auth    required     pam_group.so use_first_pass' -i /etc/pam.d/common-auth

#Insert into /etc/security/group.conf to allow new users to be added to 'docker' group automatically.
RUN    sed '1 i *;*;*;Al0000-2400;docker' -i /etc/security/group.conf

#Change the initial 'sudo' message to indicate that they only have limited root priviledges, and should seek .
RUN    sed -r -e 's|(To run a command)+(.*)|Sudo only permits specific User Management functions.  See additional documentation for details.|' -e 's/(See "man sudo_root")+(.*)//' -i /etc/bash.bashrc
#####################################
    #in /etc/ssh/sshd_config and uncomment
 RUN   sed -r -e 's|(#)(PermitRootLogin)(.*)|\2 no|' -i /etc/ssh/sshd_config
RUN    sed -r -e 's|(#)(LogLevel)(.*)|\2 DEBUG|' -i /etc/ssh/sshd_config

