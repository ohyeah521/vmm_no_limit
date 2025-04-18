#!/bin/sh



# 屏蔽认证服务器
if grep -q "synosurveillance.synology.com" /etc/hosts; then
  echo "already blocked license server: synosurveillance.synology.com."
else
  echo "add block license server: synosurveillance.synology.com"
  echo "0.0.0.0 synosurveillance.synology.com" | sudo tee -a /etc/hosts
fi


# 定义处理文件的函数
process_file() {
  local dir="$1"
  local file="$2"
  local url="$3"
  local mode="$4"

  cd "$dir" || exit
  cp ./"$file" ./"$file"_backup
  rm ./"$file"
  wget "$url" -O ./"$file"
  chmod "$mode" ./"$file"
}




# 处理每个文件 
process_file /var/packages/Virtualization/target/usr/lib libsynoccc.so    https://github.com/ohyeah521/vmm_no_limit/raw/main/patch/2.7.0-12229/libsynoccc.so     0755


