#!/bin/bash

# Tạo một file tạm để lưu IPs
TEMP_FILE=$(mktemp)
RESULT_FILE=$(mktemp)

# Số lần thử
ATTEMPTS=10

# Lấy các IP từ DNS và chỉ lưu địa chỉ IP vào tệp tạm thời
dig @1.1.1.1 #SNI +short | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' > $TEMP_FILE

# Lưu các IP vào một mảng
mapfile -t IP_ARRAY < $TEMP_FILE

# Hàm kiểm tra tốc độ
check_speed() {
    local ip=$1
    local download_speed
    local test_url="https://ash-speed.hetzner.com/100MB.bin"

    # Kiểm tra tốc độ download bằng curl, với IP cụ thể và ngăn bộ nhớ đệm
    download_speed=$(curl -o /dev/null -s -w "%{speed_download}\n" $test_url --resolve ash-speed.hetzner.com:443:$ip --header "Cache-Control: no-cache")

    # Lưu tốc độ vào file kết quả
    echo "$ip $download_speed" >> $RESULT_FILE
}

# Kiểm tra tốc độ cho từng IP và lưu vào file kết quả
for ip in "${IP_ARRAY[@]}"; do
    check_speed $ip
done

# Sắp xếp và xuất 4 IP tốt nhất dựa trên tốc độ download, chỉ hiển thị IP
sort -k2 -nr $RESULT_FILE | head -n 4 | awk '{print $1}'

# Xóa file tạm
rm $TEMP_FILE $RESULT_FILE
