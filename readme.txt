git status; git fetch
podman build . --no-cache  -t ldap_tester;
podman run --name tester_container  -it -d -p 8022:22 ldap_tester /usr/sbin/sshd -D -e

podman exec -it tester_container bash
#Select the file to copy in, the choices are ldap.conf, doctorcc.ddns.net.1636.conf
podman cp ldapfiles/ldap.conf tester_container:/etc/ldap.conf

docker stop tester_container; docker rm tester_container;
