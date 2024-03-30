#!/bin/bash
#相关配置信息:
#read -t 10 -p "SERVER IP" SERVER
SERVER=$1
echo "welcome, $SERVER"
PASSWORD="123456"
COUNTRY="CN"
STATE="zj"
CITY="hz"
ORGANIZATION="本地测试"
ORGANIZATIONAL_UNIT="Dev"
EMAIL="123@163.com"
###开始生成文件###
echo "开始生成文件"
#切换到生产密钥的目录
CERTDIR=/root/.docker
if [ ! -d $CERTDIR  ];then
  mkdir -p $CERTDIR
else
  cd $CERTDIR
fi
cd $CERTDIR
清理目录
ls -t |  sed 's/ca.sh//g' | xargs -I {} rm -rf {}
#生成ca私钥(使用aes256加密)
openssl genrsa -aes256 -passout pass:$PASSWORD  -out ca-key.pem 4096
echo "生成ca私钥完成"
#生成ca证书，填写配置信息
openssl req -new -x509 -passin "pass:$PASSWORD" -days 3650 -key ca-key.pem -sha256 -out ca.pem -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORGANIZATION/OU=$ORGANIZATIONAL_UNIT/CN=$SERVER/emailAddress=$EMAIL"
echo "填写配信息完成"
#生成server证书私钥文件
openssl genrsa -out server-key.pem 4096
#生成server证书请求文件
openssl req -subj "/CN=$SERVER" -sha256 -new -key server-key.pem -out server.csr
sh -c 'echo "subjectAltName = IP:'$SERVER',IP:0.0.0.0" >> extfile.cnf'
sh -c 'echo "extendedKeyUsage = serverAuth" >> extfile.cnf'
echo "生成server证书完成"
#使用CA证书及CA密钥以及上面的server证书请求文件进行签发，生成server自签证书
openssl x509 -req -days 1000 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem -passin "pass:$PASSWORD"  -CAcreateserial -out server-cert.pem  -extfile extfile.cnf
echo "生成自签证书完成"
#生成client证书RSA私钥文件
openssl genrsa -out key.pem 4096
#生成client证书请求文件
openssl req -subj '/CN=client' -new -key key.pem -out client.csr
echo "生成clieen请求文件完成"
sh -c 'echo "extendedKeyUsage=clientAuth" > extfile-client.cnf'
#生成client自签证书（根据上面的client私钥文件、client证书请求文件生成）
openssl x509 -req -days 3650 -in client.csr -CA ca.pem -CAkey ca-key.pem  -passin "pass:$PASSWORD" -CAcreateserial -out cert.pem  -extfile extfile-client.cnf
echo "生成client自签证书完成"
rm -v client.csr server.csr
echo "删除无用的文件" 
#更改密钥权限
chmod 0400 ca-key.pem key.pem server-key.pem
#更改密钥权限
chmod 0444 ca.pem server-cert.pem cert.pem
\cp -f ca.pem server-cert.pem server-key.pem /etc/docker
echo "生成文件完成"
systemctl daemon-reload && systemctl restart docker
echo "重启服务"
###生成结束###**
