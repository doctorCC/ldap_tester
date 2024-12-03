# ldap_tester
This project attempt to create a interface to test whether an LDAP server can authenticate a user.
To get the ldap.conf into the running Container:

1) Run the command with bind a volume containing file.
podman run --name ldaptester --rm -it -d -p 8022:22 -v /local-folder/:/target-folder/  my-container /usr/sbin/sshd -D -e
podman run --name ldaptester --rm -it -d -p 8022:22 -v ./ldapfiles/:/etc/ldapfiles /usr/sbin/sshd -D -e

OR
2) Copy it in at run time with
podman cp ./file.txt my-container:/path/where/to/place
podman cp ./ldapfiles/meth57_ldap.conf ldaptester:/etc/ldap/ldap.conf

OR
or 3) docker exec -it my-container wget "file_to_get" -0 /path/where/to/place
eg [docker exec -it ldaptester wget "http://doctorcc.ddns.net/ldapfiles/ldap.conf" -O /etc/ldap/ldap.conf


Once the Container has started, log in with a local user fakeroot/passw0rd with 
ssh fakeroot@127.0.0.1 -p 8022

Then test the default ldap configuration by running
ldapsearch -x
If it returns then the default config is working.

#Additional changes to the Image
Copy the ./nscd.conf into /etc/nscd.conf

