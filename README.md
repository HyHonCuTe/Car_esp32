
---

# 🚗 Car\_ESP32 – Bộ sưu tập xe robot điều khiển qua Flutter

**Car\_ESP32** là dự án gồm **3 loại xe robot** sử dụng **ESP32** làm bộ điều khiển trung tâm.
Mỗi loại xe có khả năng di chuyển và tính năng riêng, hỗ trợ điều khiển thủ công thông qua **ứng dụng Flutter** kết nối trực tiếp đến ESP32 qua Wi-Fi hoặc Bluetooth.

---

## 📌 Các loại xe

### 1️⃣ Xe dò line – `car_line/`

* **Chức năng**: Tự động nhận diện và bám theo vạch kẻ đường.
* **Ứng dụng**: Robot thi đấu line follower, vận chuyển hàng theo tuyến cố định.
* **Điểm nổi bật**:

  * Cảm biến dò line đa điểm.
  * Chạy ổn định, tốc độ tùy chỉnh.
  * Có thể điều khiển thủ công bằng ứng dụng.

---

### 2️⃣ Xe Mecanum 360° – `car_360/`

* **Chức năng**: Sử dụng bánh Mecanum cho khả năng di chuyển linh hoạt 360°.
* **Ứng dụng**: Robot dịch vụ, robot di chuyển trong không gian hẹp.
* **Điểm nổi bật**:

  * Tiến / lùi.
  * Di chuyển ngang trái / phải.
  * Xoay tại chỗ.
  * Chuyển hướng mượt mà.

---

### 3️⃣ Xe điều khiển đa hướng cơ bản – `carlord_01/`

* **Chức năng**: Di chuyển tiến, lùi, rẽ trái, rẽ phải.
* **Ứng dụng**: Robot học tập, thử nghiệm điều khiển từ xa.
* **Điểm nổi bật**:

  * Điều khiển đơn giản qua Flutter.
  * Điều chỉnh tốc độ và hướng thời gian thực.

---

## 🛠️ Công nghệ sử dụng

**Phần cứng**:

* ESP32.
* Động cơ DC + Driver.
* Bánh xe thường hoặc bánh Mecanum.
* Cảm biến dò line (chỉ cho xe dò line).

**Phần mềm**:

* Lập trình nhúng: Arduino C/C++ (.ino).
* Ứng dụng điều khiển: Flutter (Dart).
* Giao tiếp: Wi-Fi / Bluetooth.

---

## 📂 Cấu trúc thư mục

```
Car_esp32/
│── car_360/        # Xe Mecanum 360°
│   ├── ino/        # Code ESP32 (.ino)
│   ├── lib/        # Mã nguồn Flutter (Dart)
│   └── android/    # Cấu hình ứng dụng Flutter cho Android
│
│── car_line/       # Xe dò line
│   ├── ino/        # Code ESP32 (.ino)
│   ├── lib/        # Mã nguồn Flutter (Dart)
│   └── android/    # Cấu hình ứng dụng Flutter cho Android
│
│── carlord_01/     # Xe đa hướng cơ bản
│   ├── ino/        # Code ESP32 (.ino)
│   ├── lib/        # Mã nguồn Flutter (Dart)
│   └── android/    # Cấu hình ứng dụng Flutter cho Android
│
└── README.md       # Tài liệu này
```

---

## ⚙️ Cài đặt & Sử dụng

### 1. Nạp code cho ESP32

* Cài **Arduino IDE**.
* Cài **ESP32 Board** trong Arduino IDE.
* Mở file `.ino` của loại xe bạn muốn dùng:

  * `car_line/ino/`
  * `car_360/ino/`
  * `carlord_01/ino/`
* Nạp code vào ESP32 qua cáp USB.

### 2. Cài ứng dụng Flutter điều khiển

* Cài **Flutter SDK** trên máy tính.
* Mở thư mục dự án Flutter tương ứng (VD: `car_line/`).
* Kết nối điện thoại qua USB hoặc mở giả lập Android.
* Chạy lệnh:

  ```bash
  flutter pub get
  flutter run
  ```

### 3. Kết nối và điều khiển

* Bật nguồn cho xe.
* Trên ứng dụng Flutter, chọn chế độ kết nối (Wi-Fi/Bluetooth).
* Điều khiển xe theo ý muốn.

---

## 📷 Hình minh họa

NOTHING
---

## 📜 Giấy phép

Dự án được phát triển cho mục đích học tập và nghiên cứu có thể mail cho tôi nếu bạn cần hỗ trợ vodaohuyhoang@gmail.com

---

