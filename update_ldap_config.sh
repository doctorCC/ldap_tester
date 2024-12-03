#!/bin/bash
set -e
set -x
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m"

base_volume_manipulation(){
    echo "Make initial adjustments to the base, that were previously done during the build."
    echo "New method for determining if a pattern is found, returns a number"
    val1=$(sed -n '/^group: .*ldap/p' /etc/nsswitch.conf | wc -l)
#Check to see if base needs to be edited.  Do this by searching for an editted file.  If it is not edited, then we need to do all the editting here.
#  val1=$(cat /etc/nsswitch.conf | grep '^group:.* ldap')

  echo "val1 = [$val1]"
  if [ $val1 -gt 0 ];then
	echo "Found evidence that the base has already been 'seeded', no need o repeat."
  else
	echo "The initial seeding must be done now."
 	edit_base="true"
  fi

#Determine if the base needs to have initial modification.
  if [ "X$edit_base" != "X" ];then
  #####################################
  #Edit files for seeding LDAP in place
  #####################################

#Add 'ldap' to passwd and group lines
    sed -r  -e 's|(passwd:.*)|& ldap|' -e 's|(group:.*)|& ldap|' -e 's|(netgroup:.*)|& ldap|' -i /etc/nsswitch.conf

#Insert 2 lines into end of /pam.d/sshd, the \$a matches the end of the file. NOTE: Still needs to be fixed
    echo 'auth    sufficient      pam_ldap.so\naccount sufficient      pam_permit.so' >> /etc/pam.d/sshd

#Insert 'session required pam_mkhomedir.so skel=/etc/skel umask=0022' into /etc/pam.d/ccommon-session
    sed '1 i session required pam_mkhomedir.so skel=/etc/skel umask=0022' -i /etc/pam.d/common-session

#Change the PasswordAuthentication to yes in /etc/ssh/sshd_config and uncomment
    sed -r -e 's|(#)(PasswordAuthentication)(.*)|\2 yes|' -i /etc/ssh/sshd_config

#Insert into /etc/pam.d/common-auth to allow new users to be added to 'docker' group automatically. 
    sed '1 i auth    required     pam_group.so use_first_pass' -i /etc/pam.d/common-auth

#Insert into /etc/security/group.conf to allow new users to be added to 'docker' group automatically.
    sed '1 i *;*;*;Al0000-2400;docker' -i /etc/security/group.conf

#Change the initial 'sudo' message to indicate that they only have limited root priviledges, and should seek .
    sed -r -e 's|(To run a command)+(.*)|Sudo only permits specific User Management functions.  See additional documentation for details.|' -e 's/(See "man sudo_root")+(.*)//' -i /etc/bash.bashrc
#####################################
    #in /etc/ssh/sshd_config and uncomment
    sed -r -e 's|(#)(PermitRootLogin)(.*)|\2 no|' -i /etc/ssh/sshd_config
#Create the keys if they do not exist
    if [ ! -f /etc/ssh/ssh_host_rsa_key ];then
      echo "------EYECATCHER ssh rsa doesnt exist.------";
      dpkg-reconfigure openssh-server;
      echo "Changed keys at [$(date)]" > /etc/ssh/cli.keychange;
    fi
  fi
##################################################################################################################
    #Check for an upgrade by rebuilding the ca-certs
#    rebuild_certs
}
##################################################################################################################
rebuild_certs(){
    echo "--Rebuild the ca-certs--"
    #Write a file to the VOLUME to track whether or not cert exist, NOTE possible infinitely growing file
    tmpfile="/etc/certcheck"
    date >> "$tmpfile"
echo "The list of certs before [$(ls /etc/ssl/certs )]" >> "$tmpfile"
	#Check to see what is currently installed by looking at the size of /etc/ssl/certs/ca-certificates.crt
	certfile=/etc/ssl/certs/ca-certificates.crt
	if [ -f $certfile ];then
		actualsize=$(wc -c <"$certfile")
		echo -e "$GREEN File existed and was [$actualsize] bytes $NC" 
		if [ $actualsize -gt 0 ];then
			echo "TODO: Possible check for newer certificates here"   >> "$tmpfile"
		else
			echo "$certfile was empty therefore install certs to /usr/local/share/ca-certificates, then run the 'update-ca-certificates'"  >> "$tmpfile" 
		fi
	else
		echo -e "$RED File did not exist, we must install certificates now.$NC"   >> "$tmpfile"
	fi

	#Reinstall certs 1)ensure openssl, 2) installing ca-certs, 3) run 'update-ca-certificates'
	check_openssl=$(apt list --installed openssl | grep openssl)
	echo -e "$YELLOW check_openssl is [$check_openssl]$NC"
	if [ "X$check_openssl" = "X" ];then
	echo "*****Failed [$check_openssl]"  >> "$tmpfile"
	else
	echo "*****Passed [$check_openssl]" >> "$tmpfile"
	fi
	check_certificates=$(apt list --installed | grep ca-certificates | wc -l)
	echo "check_certificates returns a line count of [$check_certificates]"
	if [ "X$check_certificates" = "X" ];then
	echo "-----Failed [$check_certificates]"  >> "$tmpfile"
	else
	echo "-----Passed [$check_certificates]" >> "$tmpfile"
	fi
	#Check the values inside the /usr/local/share/ca-certificates
	cert_src="/usr/local/share/ca-certificates"
	check_cert_cnt=$(ls "$cert_src" | wc -l)
	if [ $check_cert_cnt -gt 0 ];then
		echo "There were [$check_cert_cnt] source certificates found"  >> "$tmpfile"
	else
		echo "No files found in [$cert_src], must reinstall the ca-certificates"  >> "$tmpfile"
		#may have to remove them first with
		dpkg -r ca-certificates
		#The files are in the additional.tgz but must be extracted and installed.
		tar -xvf /opt/additional.tgz
		dpkg -i --refuse-downgrade ca-certificates_20240203_all.deb
		dpkg -i --refuse-downgrade libssl3t64_3.0.13-0ubuntu3.3_s390x.deb
		dpkg -i --refuse-downgrade openssl_3.0.13-0ubuntu3.3_s390x.deb
	fi

	#Check for  /usr/local/share/ca-certificates/ to see if there are any certificates which should be installed.
	#During an upgrade, these files will be empty, hence need to reinstall.
echo "Check for openssl with '$(apt list | grep open)'" >> /etc/certcheck
echo "Check for cert with '$(apt list | grep cert)'" >> /etc/certcheck
check1=$(apt list | grep cert)
	if [ "X$check1" = "X" ];then
	echo "Failed [$check1]"  >> /etc/certcheck
	else
	echo "Passed [$check1]" >> /etc/certcheck
	fi
echo "The list of certs after [$(ls /etc/ssl/certs )]" >> "$tmpfile"
##echo "NEED BETTER WAY TO CHECK apt list" >> /etc/certcheck
    #ensure the directory exists
##echo "Look for ssl directory first -> [$(ls -l /etc/ssl/)]" >> /etc/certcheck
##    mkdir -p /etc/ssl/certs
##echo "Look for it after -> [$(ls -l /etc/ssl/certs)]" >> /etc/certcheck
    #If the command below fails, then /etc/certcheck will be empty
##    echo "The list of certs before [$(ls /etc/ssl/certs )]" >> /etc/certcheck
##    echo "Run 'update-ca-certificates'"
##    rc=$(update-ca-certificates)
##    if [ "X$rc" != "X" ];then
##       echo "update-ca-certificates failed -> [$rc]"
##       echo "update-ca-certificates failed -> [$rc]" >> /etc/certcheck
##    fi
##    echo "The new # of certs [$(ls /etc/ssl/certs | wc)]"
##    echo "The list of certs after [$(ls /etc/ssl/certs )]" >> /etc/certcheck
    echo "The current # of certs after [$(cat /etc/ssl/certs/ca-certificates.crt | grep BEGIN | wc)]" >> /etc/certcheck
       
}
##################################################################################################################

echo -e "Select what to do\n\t1) Base modifications\n\t2) Rebuild the certs"

if read -t 10 -p "Please enter your choice (you have 10 seconds): " choosen_option; then
    echo "You have selected [$choosen_option]."
else
    echo "Time's up! No input received.";
    choosen_option=0
fi

case $choosen_option in
    1)
        echo "You chose Base modification"
        base_volume_manipulation
        ;;
    2)
        echo "You chose Rebuild the certs"
        rebuild_certs
        ;;
    *)
        echo "Unknown selected."
        ;;
esac

