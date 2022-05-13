#!/bin/bash

rm *.jks 2> /dev/null
rm *.pem 2> /dev/null

echo "===================================================="
echo "Creating fake third-party chain root -> ca"
echo "===================================================="

# generate private keys (for root and ca)

keytool -genkeypair -alias root -dname "cn=Local Network - Development" -validity 10000 -keyalg RSA -keysize 2048 -ext bc:c -keystore root.jks -keypass password -storepass password
keytool -genkeypair -alias ca -dname "cn=Local Network - Development" -validity 10000 -keyalg RSA -keysize 2048 -ext bc:c -keystore ca.jks -keypass password -storepass password

# generate root certificate

keytool -exportcert -rfc -keystore root.jks -alias root -storepass password > root.pem

# generate a certificate for ca signed by root (root -> ca)

keytool -keystore ca.jks -storepass password -certreq -alias ca \
| keytool -keystore root.jks -storepass password -gencert -alias root -ext bc=0 -ext san=dns:ca -rfc > ca.pem

# import ca cert chain into ca.jks

keytool -keystore ca.jks -storepass password -importcert -trustcacerts -noprompt -alias root -file root.pem
keytool -keystore ca.jks -storepass password -importcert -alias ca -file ca.pem

echo  "===================================================================="
echo  "Fake third-party chain generated. Now generating server.jks ..."
echo  "===================================================================="

# generate private keys (for server)

keytool -genkeypair -alias server -dname cn=server -validity 10000 -keyalg RSA -keysize 2048 -keystore server.jks -keypass password -storepass password

# generate a certificate for server signed by ca (root -> ca -> server)

keytool -keystore server.jks -storepass password -certreq -alias server \
| keytool -keystore ca.jks -storepass password -gencert -alias ca -ext ku:c=dig,keyEnc -ext "san=dns:localhost,ip:192.1.1.18" -ext eku=sa,ca -rfc > server.pem

# import server cert chain into server.jks

keytool -keystore server.jks -storepass password -importcert -trustcacerts -noprompt -alias root -file root.pem
keytool -keystore server.jks -storepass password -importcert -alias ca -file ca.pem
keytool -keystore server.jks -storepass password -importcert -alias server -file server.pem
keytool -importkeystore -srckeystore server.jks -destkeystore server.p12 -srcstoretype JKS -deststoretype PKCS12 -deststorepass password -srcstorepass password

openssl pkcs12 -clcerts -nokeys -in server.p12 -out server.crt -password pass:password -passin pass:password
openssl pkcs12 -cacerts -nokeys -in server.p12 -out server-ca-cert.ca -password pass:password -passin pass:password
openssl pkcs12 -nocerts -in server.p12 -out server.password.key -password pass:password -passin pass:password -passout pass:password
openssl rsa -in server.password.key -out server.key -passin pass:password



echo "================================================="
echo "Keystore generated. Now generating truststore ..."
echo "================================================="

# import server cert chain into truststore.jks

keytool -keystore truststore.jks -storepass password -importcert -trustcacerts -noprompt -alias root -file root.pem
keytool -keystore truststore.jks -storepass password -importcert -alias ca -file ca.pem
keytool -keystore truststore.jks -storepass password -importcert -alias server -file server.pem
keytool -importkeystore -srckeystore truststore.jks -destkeystore truststore.p12 -srcstoretype JKS -deststoretype PKCS12 -deststorepass password -srcstorepass password
openssl pkcs12 -in truststore.p12 -out truststore.pem -password pass:password

echo "================================================="
echo "Generate user certs ..."
echo "================================================="

# generate private keys (for user1)

keytool -genkeypair -alias server -dname cn=user1 -validity 10000 -keyalg RSA -keysize 2048 -keystore user1.jks -keypass password -storepass password

# generate a certificate for server signed by ca (root -> ca -> user1)

keytool -keystore user1.jks -storepass password -certreq -alias server \
| keytool -keystore ca.jks -storepass password -gencert -alias ca -rfc > server.pem

# import server cert chain into user1.jks

keytool -keystore user1.jks -storepass password -importcert -trustcacerts -noprompt -alias root -file root.pem
keytool -keystore user1.jks -storepass password -importcert -alias ca -file ca.pem
keytool -keystore user1.jks -storepass password -importcert -alias server -file server.pem
keytool -importkeystore -srckeystore user1.jks -srcstorepass password -destkeystore user1.p12 -srcstoretype JKS -deststoretype PKCS12 -deststorepass password


# generate private keys (for user2)

keytool -genkeypair -alias server -dname cn=user2 -validity 10000 -keyalg RSA -keysize 2048 -keystore user2.jks -keypass password -storepass password

# generate a certificate for server signed by ca (root -> ca -> user2)

keytool -keystore user2.jks -storepass password -certreq -alias server \
| keytool -keystore ca.jks -storepass password -gencert -alias ca -rfc > server.pem

# import server cert chain into user2.jks

keytool -keystore user2.jks -storepass password -importcert -trustcacerts -noprompt -alias root -file root.pem
keytool -keystore user2.jks -storepass password -importcert -alias ca -file ca.pem
keytool -keystore user2.jks -storepass password -importcert -alias server -file server.pem
keytool -importkeystore -srckeystore user2.jks -srcstorepass password -destkeystore user2.p12 -srcstoretype JKS -deststoretype PKCS12 -deststorepass password