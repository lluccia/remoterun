#!/bin/bash -e

#  Copyright 2015 Formicary Ltd
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

RSA_BITS=3072
PFX_PASS=123456

cd `dirname $0`
rm -rf ca-store *.pfx *.pem *.cnf *.jks
mkdir -p ca-store/newcerts
touch ca-store/index.txt
echo 01 > ca-store/serial

# Generate CA certificate
cat > ca-config.cnf << EOF
[ req ]
default_bits   = ${RSA_BITS}
distinguished_name  = req_distinguished_name
prompt = no
x509_extensions = x509_extensions
[ x509_extensions ]
basicConstraints=critical,CA:TRUE,pathlen:0
[ req_distinguished_name ]
C      = GB
ST     = Greater London
L      = London
O      = Formicary Ltd
CN     = RemoteRun CA
[ ca ]
default_ca = ca_default
[ ca_default ]
dir = ./ca-store
database = \$dir/index.txt
new_certs_dir = \$dir/newcerts
serial = \$dir/serial
certificate = ca-cert.pem
private_key = ca-key.pem
default_md = sha1
policy = ca_policy
email_in_dn = no
copy_extensions = copy
x509_extensions = ca_extensions
[ ca_policy ]
C = supplied
ST = supplied
L = supplied
O = supplied
CN = supplied
[ ca_extensions ]
EOF
chmod 600 ca-config.cnf
openssl req -newkey rsa:${RSA_BITS} -keyout ca-key.pem -x509 -out ca-cert.pem -days 3650 -config ca-config.cnf -nodes
keytool -import -file ca-cert.pem -keystore ca-truststore.jks -storepass 123456 -noprompt

# Generate server certificate
cat > server-config.cnf << EOF
[ req ]
default_bits   = ${RSA_BITS}
prompt = no
req_extensions = extensions
distinguished_name = req_distinguished_name
[ extensions ]
keyUsage=digitalSignature, keyEncipherment, keyAgreement
extendedKeyUsage=serverAuth
[ req_distinguished_name ]
C      = GB
ST     = Greater London
L      = London
O      = Formicary Ltd
CN     = server
EOF
chmod 600 server-config.cnf
openssl req -newkey rsa:${RSA_BITS} -keyout server-key.pem -out server-certrequest.pem -days 3650 -config server-config.cnf -nodes
openssl ca -key "${CA_PASS}" -days 365 -in server-certrequest.pem -out server-cert.pem -config ca-config.cnf -batch
openssl pkcs12 -export -out server-pkcs12.pfx -in server-cert.pem -inkey server-key.pem -name server -CAfile ca-cert.pem -chain -passout "pass:${PFX_PASS}"
keytool -importkeystore -srckeystore server-pkcs12.pfx -srcstoretype pkcs12 -srcstorepass 123456 -destkeystore server-keystore.jks -deststoretype jks -deststorepass 123456

# Generate agent certificates
for NAME in agent1 agent2 ; do
cat > ${NAME}-config.cnf << EOF
[ req ]
default_bits   = ${RSA_BITS}
prompt = no
req_extensions = extensions
distinguished_name = req_distinguished_name
[ extensions ]
keyUsage=digitalSignature, keyAgreement
extendedKeyUsage=clientAuth
[ req_distinguished_name ]
C      = GB
ST     = Greater London
L      = London
O      = Formicary Ltd
CN     = ${NAME}
EOF
chmod 600 ${NAME}-config.cnf
openssl req -newkey rsa:${RSA_BITS} -keyout ${NAME}-key.pem -out ${NAME}-certrequest.pem -days 3650 -config ${NAME}-config.cnf -nodes
openssl ca -key "${CA_PASS}" -days 365 -in ${NAME}-certrequest.pem -out ${NAME}-cert.pem -config ca-config.cnf -batch
openssl pkcs12 -export -out ${NAME}-pkcs12.pfx -in ${NAME}-cert.pem -inkey ${NAME}-key.pem -name ${NAME} -CAfile ca-cert.pem -chain -passout "pass:${PFX_PASS}"
keytool -importkeystore -srckeystore ${NAME}-pkcs12.pfx -srcstoretype pkcs12 -srcstorepass 123456 -destkeystore ${NAME}-keystore.jks -deststoretype jks -deststorepass 123456
done