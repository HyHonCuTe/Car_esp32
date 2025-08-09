---

# 🚗 Car\_ESP32 – Bộ sưu tập xe robot điều khiển qua Flutter

**Car\_ESP32** là dự án gồm **3 loại xe robot** sử dụng **ESP32** làm bộ điều khiển trung tâm, mỗi loại có khả năng di chuyển và tính năng riêng biệt. Tất cả đều hỗ trợ điều khiển thủ công qua ứng dụng **Flutter** kết nối trực tiếp đến ESP32.

---

## 📌 Danh sách các loại xe

### 1️⃣ Xe dò line

* **Chức năng**: Tự động nhận diện và bám theo vạch kẻ đường.
* **Ứng dụng**: Robot thi đấu line follower, vận chuyển hàng theo tuyến đường cố định.
* **Điểm nổi bật**:

  * Cảm biến dò line đa điểm
  * Chạy ổn định, tốc độ tùy chỉnh
  * Hỗ trợ chế độ điều khiển thủ công

---

### 2️⃣ Xe Mecanum 360°

* **Chức năng**: Sử dụng bánh Mecanum cho khả năng di chuyển linh hoạt mọi hướng.
* **Ứng dụng**: Robot dịch vụ, vận chuyển trong không gian hẹp.
* **Điểm nổi bật**:

  * Tiến / lùi
  * Di chuyển ngang trái / phải
  * Xoay tại chỗ
  * Chuyển hướng mượt mà

---

### 3️⃣ Xe điều khiển đa hướng cơ bản

* **Chức năng**: Di chuyển tiến, lùi, rẽ trái, rẽ phải.
* **Ứng dụng**: Robot học tập, thử nghiệm điều khiển từ xa.
* **Điểm nổi bật**:

  * Điều khiển dễ dàng qua ứng dụng Flutter
  * Tốc độ và hướng điều chỉnh theo thời gian thực

---

## 🛠️ Công nghệ sử dụng

* **Phần cứng**:

  * ESP32
  * Động cơ DC + Driver
  * Bánh xe thường hoặc Mecanum
  * Cảm biến (đối với xe dò line)
* **Phần mềm**:

  * Ngôn ngữ lập trình: Arduino C/C++
  * Ứng dụng điều khiển: Flutter
  * Giao thức giao tiếp: Wi-Fi / Bluetooth

---

## 📂 Cấu trúc dự án

```
Car_esp32/
│── car_360/         # Xe Mecanum 360°
│── car_line/        # Xe dò line
│── carlord_01/      # Xe điều khiển đa hướng cơ bản
│── README.md        # Tài liệu này

 - file ino       # Code nhúng esp
 - file main.dart # Các cấu hình kèm theo flutter
```

---


---

Nếu bạn muốn, mình có thể **thêm bảng so sánh tính năng 3 loại xe** vào README này để nhìn vào là phân biệt được ngay.
Bạn có muốn mình làm bảng đó luôn không?
