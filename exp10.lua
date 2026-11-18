-- ============================================================
-- ANTARCTICA EXPEDITION - FLY REPLAY SOUTH POLE v2
-- Menggantikan replay jalan kaki v1 (ASUMSI LAMA SALAH).
-- Rekaman 2026-11-03 ternyata dibuat TERBANG pakai script fly
-- lain dari Base Camp ke South Pole melewati checkpoint.
-- Itu menjelaskan data rekaman: +/-100 stud/detik, 0 lompat,
-- 0 climbing. Jadi v2 ini TERBANG mengikuti waypoint 3D
-- rekaman (termasuk ketinggiannya) - bukan jalan di tanah.
-- ------------------------------------------------------------
-- CARA KERJA:
--   * Fly engine: BodyVelocity + BodyGyro di HumanoidRootPart,
--     kecepatan FLY_SPEED (default 100 = tempo rekaman),
--     noclip selama terbang, PlatformStand selama terbang.
--   * Waypoint diikuti berurutan; di titik rendah rekaman
--     (checkpoint, mis. Camp 4 cuma +2.5 stud dari tanah)
--     script ikut turun rendah, jadi checkpoint tetap
--     dilewati pada posisi yang sama seperti rekamanmu.
--   * START dari mana pun di rute -> resume waypoint terdekat.
--     Respawn di tengah jalan -> otomatis resume juga.
--   * Jeda rekaman DITIRU PENUH (total diam 808 detik):
--     jeda itu adalah TUNGGU CHECKPOINT - tanpa menunggu
--     beberapa menit di tiap checkpoint, checkpoint TIDAK
--     kehitung (konfirmasi Muhammad 2026-11-03). Total waktu
--     replay jadinya +/-17 menit, sama seperti rekamannya.
--     Posisi ditahan melayang (hover) selama jeda, setelah
--     script terbang persis ke titik tunggunya dulu.
--   * Minum: HANYA saat diam di jeda checkpoint panjang
--     (>=45 detik), kalau hydration <=40%: 20x klik, delay
--     2 detik, dan waktu minum dihitung sebagai bagian dari
--     jeda (total diam tetap persis rekaman, timer aman).
--     Saat terbang TIDAK minum sama sekali.
--   * STOP -> fly engine dimatikan, collision & PlatformStand
--     dipulihkan, karakter jatuh normal ke tanah.
-- CATATAN: Ini mengandalkan fly bekerja di Xeno seperti
-- script fly yang kamu pakai saat merekam. Kalau game
-- menolak BodyVelocity (rubber-banding / mental balik),
-- kabari aku - metodenya diganti ke CFrame fly.
-- ============================================================

-- ================= v10 (GUI) =================
-- v10 = v9 PERSIS, cuma GUI-nya ditambah:
--   * Tombol minimize (kotak kecil 76x44 tanpa nama, isi + dan X,
--     tetap bisa didrag) dan tombol X (STOP total + panel hilang,
--     lewat StopSignal bawaan script ini sendiri).
--   * Panel bisa didrag dari judulnya / dari kotak minimize.
--   * Keybind sembunyi/tampil panel (default RightShift) yang
--     BISA DIGANTI dari panel — klik tombol keybind, tekan
--     tombol baru, Esc = batal.
--   * Klik-vs-drag dibedakan (geser >6px = drag, bukan klik)
--     biar tombol + / X tidak kepencet pas panel digeser.
-- Logika terbang, rute, jeda, minum, loop & auto-stop join
-- TIDAK berubah sama sekali dari v9.
-- ============================================================

-- ================= CONFIG =================
local FLY_SPEED = 100      -- samakan dengan tempo rekaman
local MAX_WAIT = 9999      -- jeda rekaman DITIRU PENUH: jeda = tunggu checkpoint (konfirmasi Muhammad), JANGAN dipotong
local REACH_DIST = 7       -- jarak ke waypoint dianggap sampai
local DRINK_AT = 40
local DRINK_CLICKS = 20
local CLICK_DELAY = 2
local DRINK_COOLDOWN = 30
local CHECK_INTERVAL = 2 -- jeda antar cek hydration monitor (detik)
local NOCLIP = true

-- ================= LOOP (AUTO SUMMIT TERUS) =================
-- true = setelah sampai South Pole: tunggu LOOP_FINISH_WAIT
-- detik (biar kedatangan ke-register), lalu respawn/rejoin
-- dan mulai lagi SENDIRI tanpa kamu tekan START.
local LOOP_MODE = true
-- "reset"  = karakter dimatikan (Health = 0) -> respawn ->
--            script auto-start dari titik respawn (default)
-- "rejoin" = keluar & masuk lagi server yang sama pakai
--            queue_on_teleport; butuh file script ini tersimpan
--            di folder workspace Xeno dengan nama
--            antarctica-fly-replay-southpole.lua
local LOOP_METHOD = "teleport"
-- Khusus metode "teleport": titik ini adalah AIR. Setelah sampai
-- South Pole, karakter dipindahkan ke sini supaya MATI kena air,
-- lalu respawn di Base Camp - dan run berikutnya mulai otomatis
-- dari sana (ekspedisi penuh lagi). Desain dari Muhammad.
local AFTER_SUMMIT_POS = Vector3.new(5915.04, 313.76, -141.51)
local LOOP_FINISH_WAIT = 10
local AUTO_START_ON_LOAD = false
if LOOP_METHOD == "rejoin" then AUTO_START_ON_LOAD = true end

-- ===== AUTO STOP KALAU ADA YANG JOIN =====
-- Script otomatis STOP (persis kayak mencet tombol STOP, loop ikut
-- mati) kalau orang yang masuk daftar di bawah ini join server.
local FRIEND_AUTO_STOP = true    -- teman Roblox (friend list) join -> STOP
local WATCH_NAMES = {}           -- username tambahan yang dipantau, contoh: { "Budi123", "Siti_Game" }
local ANY_JOIN_AUTO_STOP = true  -- MODE SIAPA PUN (dipilih Muhammad): siapa pun join -> STOP

-- ================= ROUTE (dari rekaman) =================
local ROUTE = {
	{pos = Vector3.new(-6016.05, -159.71, -42.56), action = "start"},
	{pos = Vector3.new(-6016.05, -159.71, -42.56), action = "wait", wait = 5.1},
	{pos = Vector3.new(-6005.37, -159.48, -49.14), action = "walk"},
	{pos = Vector3.new(-5987.89, -159.01, -61.76), action = "walk"},
	{pos = Vector3.new(-5973.77, -158.32, -77.04), action = "walk"},
	{pos = Vector3.new(-5960.36, -157.57, -92.97), action = "walk"},
	{pos = Vector3.new(-5952.18, -157.18, -111.87), action = "walk"},
	{pos = Vector3.new(-5948.56, -156.76, -131.93), action = "walk"},
	{pos = Vector3.new(-5942.83, -155.89, -152.79), action = "walk"},
	{pos = Vector3.new(-5935.85, -155.04, -171.95), action = "walk"},
	{pos = Vector3.new(-5925.82, -154.28, -190.66), action = "walk"},
	{pos = Vector3.new(-5916.02, -153.56, -208.09), action = "walk"},
	{pos = Vector3.new(-5906.02, -152.83, -225.87), action = "walk"},
	{pos = Vector3.new(-5895.99, -152.09, -243.64), action = "walk"},
	{pos = Vector3.new(-5884.97, -151.26, -260.30), action = "walk"},
	{pos = Vector3.new(-5873.06, -150.36, -277.88), action = "walk"},
	{pos = Vector3.new(-5861.40, -149.47, -295.12), action = "walk"},
	{pos = Vector3.new(-5849.49, -148.56, -312.70), action = "walk"},
	{pos = Vector3.new(-5837.82, -147.67, -329.93), action = "walk"},
	{pos = Vector3.new(-5826.43, -146.81, -346.35), action = "walk"},
	{pos = Vector3.new(-5814.52, -145.93, -363.41), action = "walk"},
	{pos = Vector3.new(-5802.80, -145.05, -380.10), action = "walk"},
	{pos = Vector3.new(-5790.82, -144.16, -397.12), action = "walk"},
	{pos = Vector3.new(-5778.88, -143.29, -413.66), action = "walk"},
	{pos = Vector3.new(-5766.70, -142.40, -430.54), action = "walk"},
	{pos = Vector3.new(-5753.30, -141.42, -449.11), action = "walk"},
	{pos = Vector3.new(-5741.60, -140.57, -465.32), action = "walk"},
	{pos = Vector3.new(-5729.42, -139.68, -482.20), action = "walk"},
	{pos = Vector3.new(-5717.48, -138.81, -498.75), action = "walk"},
	{pos = Vector3.new(-5704.97, -138.03, -514.34), action = "walk"},
	{pos = Vector3.new(-5692.07, -137.25, -530.15), action = "walk"},
	{pos = Vector3.new(-5679.18, -136.47, -545.96), action = "walk"},
	{pos = Vector3.new(-5666.02, -135.68, -562.09), action = "walk"},
	{pos = Vector3.new(-5653.12, -134.90, -577.91), action = "walk"},
	{pos = Vector3.new(-5640.21, -134.13, -593.71), action = "walk"},
	{pos = Vector3.new(-5626.94, -133.70, -609.79), action = "walk"},
	{pos = Vector3.new(-5612.89, -133.31, -626.82), action = "walk"},
	{pos = Vector3.new(-5599.37, -132.93, -643.20), action = "walk"},
	{pos = Vector3.new(-5586.33, -132.76, -658.94), action = "walk"},
	{pos = Vector3.new(-5573.25, -132.77, -674.61), action = "walk"},
	{pos = Vector3.new(-5559.09, -132.79, -691.56), action = "walk"},
	{pos = Vector3.new(-5545.70, -132.82, -707.52), action = "walk"},
	{pos = Vector3.new(-5532.26, -132.87, -722.33), action = "walk"},
	{pos = Vector3.new(-5518.08, -132.94, -737.58), action = "walk"},
	{pos = Vector3.new(-5504.18, -133.00, -752.53), action = "walk"},
	{pos = Vector3.new(-5490.56, -133.06, -767.17), action = "walk"},
	{pos = Vector3.new(-5476.66, -133.12, -782.12), action = "walk"},
	{pos = Vector3.new(-5462.76, -133.18, -797.07), action = "walk"},
	{pos = Vector3.new(-5448.57, -133.24, -812.32), action = "walk"},
	{pos = Vector3.new(-5434.96, -133.30, -826.96), action = "walk"},
	{pos = Vector3.new(-5420.77, -133.36, -842.21), action = "walk"},
	{pos = Vector3.new(-5406.61, -133.42, -856.91), action = "walk"},
	{pos = Vector3.new(-5391.57, -133.48, -870.72), action = "walk"},
	{pos = Vector3.new(-5376.46, -133.54, -884.45), action = "walk"},
	{pos = Vector3.new(-5360.43, -133.60, -898.40), action = "walk"},
	{pos = Vector3.new(-5345.03, -133.66, -911.16), action = "walk"},
	{pos = Vector3.new(-5329.04, -133.72, -923.85), action = "walk"},
	{pos = Vector3.new(-5312.67, -133.81, -936.04), action = "walk"},
	{pos = Vector3.new(-5296.11, -133.92, -948.00), action = "walk"},
	{pos = Vector3.new(-5279.89, -134.02, -959.71), action = "walk"},
	{pos = Vector3.new(-5262.21, -134.17, -971.49), action = "walk"},
	{pos = Vector3.new(-5244.75, -134.33, -982.06), action = "walk"},
	{pos = Vector3.new(-5227.03, -134.48, -992.19), action = "walk"},
	{pos = Vector3.new(-5209.13, -134.64, -1002.00), action = "walk"},
	{pos = Vector3.new(-5191.08, -134.73, -1011.52), action = "walk"},
	{pos = Vector3.new(-5171.93, -134.73, -1020.70), action = "walk"},
	{pos = Vector3.new(-5152.50, -134.59, -1028.20), action = "walk"},
	{pos = Vector3.new(-5133.29, -134.41, -1035.14), action = "walk"},
	{pos = Vector3.new(-5114.08, -134.24, -1042.08), action = "walk"},
	{pos = Vector3.new(-5094.47, -134.06, -1049.16), action = "walk"},
	{pos = Vector3.new(-5075.65, -133.90, -1055.95), action = "walk"},
	{pos = Vector3.new(-5056.05, -133.72, -1063.03), action = "walk"},
	{pos = Vector3.new(-5036.83, -133.55, -1069.97), action = "walk"},
	{pos = Vector3.new(-5017.41, -133.34, -1076.25), action = "walk"},
	{pos = Vector3.new(-4998.19, -133.13, -1081.81), action = "walk"},
	{pos = Vector3.new(-4977.77, -132.90, -1087.71), action = "walk"},
	{pos = Vector3.new(-4958.16, -132.68, -1093.38), action = "walk"},
	{pos = Vector3.new(-4938.39, -132.46, -1098.44), action = "walk"},
	{pos = Vector3.new(-4926.12, -132.33, -1100.76), action = "walk"},
	{pos = Vector3.new(-4904.57, -132.24, -1103.00), action = "walk"},
	{pos = Vector3.new(-4884.19, -132.17, -1103.08), action = "walk"},
	{pos = Vector3.new(-4863.82, -132.09, -1101.56), action = "walk"},
	{pos = Vector3.new(-4843.05, -132.01, -1100.01), action = "walk"},
	{pos = Vector3.new(-4822.69, -131.93, -1098.46), action = "walk"},
	{pos = Vector3.new(-4802.35, -131.85, -1096.65), action = "walk"},
	{pos = Vector3.new(-4781.29, -131.76, -1093.81), action = "walk"},
	{pos = Vector3.new(-4761.43, -131.68, -1089.13), action = "walk"},
	{pos = Vector3.new(-4741.52, -131.56, -1083.03), action = "walk"},
	{pos = Vector3.new(-4722.02, -131.43, -1076.98), action = "walk"},
	{pos = Vector3.new(-4702.43, -131.23, -1069.92), action = "walk"},
	{pos = Vector3.new(-4684.20, -130.93, -1061.75), action = "walk"},
	{pos = Vector3.new(-4665.58, -130.50, -1051.54), action = "walk"},
	{pos = Vector3.new(-4648.47, -130.05, -1041.20), action = "walk"},
	{pos = Vector3.new(-4630.65, -129.59, -1030.44), action = "walk"},
	{pos = Vector3.new(-4613.23, -129.14, -1019.79), action = "walk"},
	{pos = Vector3.new(-4595.65, -128.66, -1008.64), action = "walk"},
	{pos = Vector3.new(-4579.03, -128.10, -996.81), action = "walk"},
	{pos = Vector3.new(-4562.56, -127.51, -984.75), action = "walk"},
	{pos = Vector3.new(-4546.10, -126.91, -972.69), action = "walk"},
	{pos = Vector3.new(-4529.71, -126.32, -960.54), action = "walk"},
	{pos = Vector3.new(-4512.99, -125.72, -948.13), action = "walk"},
	{pos = Vector3.new(-4496.47, -125.09, -935.44), action = "walk"},
	{pos = Vector3.new(-4480.44, -124.45, -922.80), action = "walk"},
	{pos = Vector3.new(-4463.43, -123.77, -909.39), action = "walk"},
	{pos = Vector3.new(-4447.07, -123.12, -896.49), action = "walk"},
	{pos = Vector3.new(-4431.04, -122.48, -883.85), action = "walk"},
	{pos = Vector3.new(-4415.01, -121.84, -871.20), action = "walk"},
	{pos = Vector3.new(-4398.98, -121.20, -858.56), action = "walk"},
	{pos = Vector3.new(-4382.95, -120.56, -845.92), action = "walk"},
	{pos = Vector3.new(-4367.44, -119.87, -832.68), action = "walk"},
	{pos = Vector3.new(-4354.06, -119.22, -820.77), action = "walk"},
	{pos = Vector3.new(-4338.97, -118.12, -805.89), action = "walk"},
	{pos = Vector3.new(-4325.61, -116.70, -790.63), action = "walk"},
	{pos = Vector3.new(-4314.54, -114.59, -773.67), action = "walk"},
	{pos = Vector3.new(-4304.66, -111.47, -755.66), action = "walk"},
	{pos = Vector3.new(-4295.21, -107.32, -738.10), action = "walk"},
	{pos = Vector3.new(-4285.40, -102.48, -720.41), action = "walk"},
	{pos = Vector3.new(-4275.29, -97.45, -703.42), action = "walk"},
	{pos = Vector3.new(-4264.62, -92.31, -687.31), action = "walk"},
	{pos = Vector3.new(-4253.29, -86.67, -671.37), action = "walk"},
	{pos = Vector3.new(-4243.10, -79.72, -655.69), action = "walk"},
	{pos = Vector3.new(-4232.80, -71.52, -639.68), action = "walk"},
	{pos = Vector3.new(-4222.77, -62.39, -624.44), action = "walk"},
	{pos = Vector3.new(-4212.57, -52.99, -608.94), action = "walk"},
	{pos = Vector3.new(-4202.93, -43.42, -594.28), action = "walk"},
	{pos = Vector3.new(-4192.89, -33.39, -579.03), action = "walk"},
	{pos = Vector3.new(-4183.26, -23.77, -564.39), action = "walk"},
	{pos = Vector3.new(-4172.08, -13.82, -549.89), action = "walk"},
	{pos = Vector3.new(-4158.09, -3.69, -536.12), action = "walk"},
	{pos = Vector3.new(-4144.76, 5.83, -523.24), action = "walk"},
	{pos = Vector3.new(-4131.73, 15.16, -510.59), action = "walk"},
	{pos = Vector3.new(-4119.04, 24.51, -497.62), action = "walk"},
	{pos = Vector3.new(-4107.50, 33.78, -483.54), action = "walk"},
	{pos = Vector3.new(-4099.43, 42.34, -467.41), action = "walk"},
	{pos = Vector3.new(-4095.27, 50.79, -448.84), action = "walk"},
	{pos = Vector3.new(-4095.83, 58.88, -429.24), action = "walk"},
	{pos = Vector3.new(-4100.18, 65.92, -410.55), action = "walk"},
	{pos = Vector3.new(-4106.33, 71.66, -393.28), action = "walk"},
	{pos = Vector3.new(-4115.15, 77.16, -374.23), action = "walk"},
	{pos = Vector3.new(-4123.46, 82.10, -356.70), action = "walk"},
	{pos = Vector3.new(-4132.27, 87.00, -338.47), action = "walk"},
	{pos = Vector3.new(-4140.91, 91.79, -320.60), action = "walk"},
	{pos = Vector3.new(-4149.45, 96.56, -302.19), action = "walk"},
	{pos = Vector3.new(-4156.94, 100.91, -284.15), action = "walk"},
	{pos = Vector3.new(-4163.38, 104.97, -264.73), action = "walk"},
	{pos = Vector3.new(-4168.41, 108.77, -244.43), action = "walk"},
	{pos = Vector3.new(-4171.56, 112.43, -223.76), action = "walk"},
	{pos = Vector3.new(-4171.23, 115.61, -204.02), action = "walk"},
	{pos = Vector3.new(-4169.79, 118.76, -183.89), action = "walk"},
	{pos = Vector3.new(-4166.83, 121.67, -164.35), action = "walk"},
	{pos = Vector3.new(-4160.06, 124.49, -145.29), action = "walk"},
	{pos = Vector3.new(-4152.75, 127.46, -125.10), action = "walk"},
	{pos = Vector3.new(-4145.60, 130.00, -106.59), action = "walk"},
	{pos = Vector3.new(-4138.16, 132.64, -87.32), action = "walk"},
	{pos = Vector3.new(-4131.01, 135.18, -68.81), action = "walk"},
	{pos = Vector3.new(-4123.56, 137.82, -49.54), action = "walk"},
	{pos = Vector3.new(-4116.41, 140.36, -31.03), action = "walk"},
	{pos = Vector3.new(-4109.12, 142.95, -12.14), action = "walk"},
	{pos = Vector3.new(-4101.97, 145.49, 6.36), action = "walk"},
	{pos = Vector3.new(-4094.68, 148.09, 25.26), action = "walk"},
	{pos = Vector3.new(-4087.49, 150.72, 44.18), action = "walk"},
	{pos = Vector3.new(-4080.16, 153.41, 63.50), action = "walk"},
	{pos = Vector3.new(-4071.90, 155.94, 81.97), action = "walk"},
	{pos = Vector3.new(-4056.10, 157.65, 94.52), action = "walk"},
	{pos = Vector3.new(-4036.50, 158.96, 99.39), action = "walk"},
	{pos = Vector3.new(-4016.58, 160.35, 96.14), action = "walk"},
	{pos = Vector3.new(-3997.66, 161.89, 87.56), action = "walk"},
	{pos = Vector3.new(-3979.05, 163.32, 78.30), action = "walk"},
	{pos = Vector3.new(-3961.06, 164.61, 69.65), action = "walk"},
	{pos = Vector3.new(-3942.01, 165.90, 62.44), action = "walk"},
	{pos = Vector3.new(-3922.13, 167.19, 58.08), action = "walk"},
	{pos = Vector3.new(-3901.83, 168.42, 56.74), action = "walk"},
	{pos = Vector3.new(-3881.21, 169.46, 59.24), action = "walk"},
	{pos = Vector3.new(-3861.87, 170.47, 66.84), action = "walk"},
	{pos = Vector3.new(-3843.24, 171.53, 75.12), action = "walk"},
	{pos = Vector3.new(-3823.91, 172.39, 82.87), action = "walk"},
	{pos = Vector3.new(-3807.21, 173.17, 93.45), action = "walk"},
	{pos = Vector3.new(-3811.48, 174.05, 112.80), action = "walk"},
	{pos = Vector3.new(-3820.82, 175.27, 130.40), action = "walk"},
	{pos = Vector3.new(-3833.35, 176.73, 146.97), action = "walk"},
	{pos = Vector3.new(-3845.70, 178.13, 162.64), action = "walk"},
	{pos = Vector3.new(-3858.63, 179.59, 178.92), action = "walk"},
	{pos = Vector3.new(-3871.33, 181.02, 194.84), action = "walk"},
	{pos = Vector3.new(-3882.45, 182.86, 213.16), action = "walk"},
	{pos = Vector3.new(-3886.49, 185.34, 235.00), action = "walk"},
	{pos = Vector3.new(-3877.60, 188.60, 252.81), action = "walk"},
	{pos = Vector3.new(-3860.67, 192.54, 261.45), action = "walk"},
	{pos = Vector3.new(-3840.48, 197.01, 263.38), action = "walk"},
	{pos = Vector3.new(-3820.55, 201.41, 263.32), action = "walk"},
	{pos = Vector3.new(-3800.95, 206.55, 262.32), action = "walk"},
	{pos = Vector3.new(-3782.88, 214.23, 256.99), action = "walk"},
	{pos = Vector3.new(-3764.85, 220.62, 250.87), action = "walk"},
	{pos = Vector3.new(-3744.67, 225.69, 246.27), action = "walk"},
	{pos = Vector3.new(-3736.17, 227.42, 244.56), action = "wait", wait = 68},
	{pos = Vector3.new(-3722.92, 228.19, 238.30), action = "walk"},
	{pos = Vector3.new(-3716.90, 228.54, 235.45), action = "wait", wait = 0.8},
	{pos = Vector3.new(-3700.66, 229.45, 227.92), action = "walk"},
	{pos = Vector3.new(-3681.80, 230.39, 221.35), action = "walk"},
	{pos = Vector3.new(-3662.10, 231.38, 214.62), action = "walk"},
	{pos = Vector3.new(-3642.36, 232.54, 209.61), action = "walk"},
	{pos = Vector3.new(-3622.20, 234.56, 205.24), action = "walk"},
	{pos = Vector3.new(-3602.06, 238.14, 201.70), action = "walk"},
	{pos = Vector3.new(-3582.30, 243.30, 198.12), action = "walk"},
	{pos = Vector3.new(-3563.12, 249.39, 194.75), action = "walk"},
	{pos = Vector3.new(-3539.88, 256.62, 191.16), action = "walk"},
	{pos = Vector3.new(-3519.10, 262.26, 191.66), action = "walk"},
	{pos = Vector3.new(-3499.64, 267.34, 193.72), action = "walk"},
	{pos = Vector3.new(-3480.25, 271.79, 195.81), action = "walk"},
	{pos = Vector3.new(-3459.80, 275.88, 195.49), action = "walk"},
	{pos = Vector3.new(-3440.12, 279.46, 195.78), action = "walk"},
	{pos = Vector3.new(-3419.64, 282.55, 194.02), action = "walk"},
	{pos = Vector3.new(-3402.58, 284.32, 183.34), action = "walk"},
	{pos = Vector3.new(-3389.84, 285.80, 167.48), action = "walk"},
	{pos = Vector3.new(-3375.21, 287.33, 153.41), action = "walk"},
	{pos = Vector3.new(-3366.28, 288.04, 150.34), action = "walk"},
	{pos = Vector3.new(-3345.72, 289.42, 151.93), action = "walk"},
	{pos = Vector3.new(-3325.68, 290.35, 154.90), action = "walk"},
	{pos = Vector3.new(-3305.59, 291.18, 151.42), action = "walk"},
	{pos = Vector3.new(-3286.83, 292.55, 147.57), action = "walk"},
	{pos = Vector3.new(-3267.32, 295.90, 153.39), action = "walk"},
	{pos = Vector3.new(-3254.08, 302.67, 166.46), action = "walk"},
	{pos = Vector3.new(-3246.32, 312.45, 178.48), action = "walk"},
	{pos = Vector3.new(-3231.26, 321.58, 189.72), action = "walk"},
	{pos = Vector3.new(-3212.94, 328.63, 190.26), action = "walk"},
	{pos = Vector3.new(-3196.43, 336.32, 181.12), action = "walk"},
	{pos = Vector3.new(-3182.46, 344.70, 171.89), action = "walk"},
	{pos = Vector3.new(-3169.35, 349.23, 161.22), action = "walk"},
	{pos = Vector3.new(-3153.77, 352.88, 147.83), action = "walk"},
	{pos = Vector3.new(-3138.24, 354.79, 135.24), action = "walk"},
	{pos = Vector3.new(-3122.28, 354.19, 122.35), action = "walk"},
	{pos = Vector3.new(-3109.36, 351.78, 106.83), action = "walk"},
	{pos = Vector3.new(-3100.38, 349.83, 88.66), action = "walk"},
	{pos = Vector3.new(-3092.95, 348.09, 69.73), action = "walk"},
	{pos = Vector3.new(-3082.57, 346.11, 51.76), action = "walk"},
	{pos = Vector3.new(-3071.78, 343.64, 34.58), action = "walk"},
	{pos = Vector3.new(-3060.89, 340.90, 18.02), action = "walk"},
	{pos = Vector3.new(-3049.39, 337.93, 0.89), action = "walk"},
	{pos = Vector3.new(-3037.68, 334.61, -16.02), action = "walk"},
	{pos = Vector3.new(-3026.38, 331.18, -32.69), action = "walk"},
	{pos = Vector3.new(-3015.12, 327.73, -49.37), action = "walk"},
	{pos = Vector3.new(-3004.06, 324.36, -65.68), action = "walk"},
	{pos = Vector3.new(-2992.22, 321.09, -81.99), action = "walk"},
	{pos = Vector3.new(-2980.35, 317.82, -98.28), action = "walk"},
	{pos = Vector3.new(-2966.92, 314.51, -113.23), action = "walk"},
	{pos = Vector3.new(-2948.83, 311.68, -121.87), action = "walk"},
	{pos = Vector3.new(-2928.71, 310.11, -123.51), action = "walk"},
	{pos = Vector3.new(-2908.76, 309.87, -124.04), action = "walk"},
	{pos = Vector3.new(-2889.05, 309.22, -130.26), action = "walk"},
	{pos = Vector3.new(-2873.52, 307.61, -143.22), action = "walk"},
	{pos = Vector3.new(-2861.45, 304.83, -159.49), action = "walk"},
	{pos = Vector3.new(-2849.69, 301.22, -175.83), action = "walk"},
	{pos = Vector3.new(-2835.40, 296.86, -189.69), action = "walk"},
	{pos = Vector3.new(-2818.87, 291.85, -200.57), action = "walk"},
	{pos = Vector3.new(-2809.70, 288.97, -205.59), action = "walk"},
	{pos = Vector3.new(-2797.37, 281.22, -221.76), action = "walk"},
	{pos = Vector3.new(-2788.70, 274.70, -235.87), action = "walk"},
	{pos = Vector3.new(-2787.50, 266.44, -245.64), action = "walk"},
	{pos = Vector3.new(-2787.28, 261.54, -260.73), action = "walk"},
	{pos = Vector3.new(-2791.23, 257.17, -279.93), action = "walk"},
	{pos = Vector3.new(-2796.19, 250.72, -298.68), action = "walk"},
	{pos = Vector3.new(-2806.16, 243.89, -315.09), action = "walk"},
	{pos = Vector3.new(-2817.45, 238.14, -330.48), action = "walk"},
	{pos = Vector3.new(-2830.84, 232.52, -345.41), action = "walk"},
	{pos = Vector3.new(-2830.73, 232.50, -345.49), action = "wait", wait = 0.6},
	{pos = Vector3.new(-2817.78, 222.60, -379.02), action = "walk"},
	{pos = Vector3.new(-2810.92, 221.71, -386.08), action = "walk"},
	{pos = Vector3.new(-2796.20, 223.16, -396.70), action = "walk"},
	{pos = Vector3.new(-2786.14, 224.33, -404.01), action = "walk"},
	{pos = Vector3.new(-2773.28, 225.88, -411.46), action = "wait", wait = 0.6},
	{pos = Vector3.new(-2741.41, 229.66, -396.14), action = "walk"},
	{pos = Vector3.new(-2730.21, 230.94, -389.01), action = "walk"},
	{pos = Vector3.new(-2719.84, 231.89, -382.84), action = "walk"},
	{pos = Vector3.new(-2688.07, 233.70, -370.73), action = "walk"},
	{pos = Vector3.new(-2666.29, 234.73, -365.23), action = "walk"},
	{pos = Vector3.new(-2657.21, 235.12, -364.06), action = "walk"},
	{pos = Vector3.new(-2637.75, 235.96, -362.05), action = "walk"},
	{pos = Vector3.new(-2627.39, 236.39, -361.00), action = "wait", wait = 0.8},
	{pos = Vector3.new(-2589.75, 237.42, -356.41), action = "walk"},
	{pos = Vector3.new(-2569.65, 237.00, -352.65), action = "walk"},
	{pos = Vector3.new(-2548.37, 235.87, -345.51), action = "walk"},
	{pos = Vector3.new(-2531.54, 233.64, -338.35), action = "walk"},
	{pos = Vector3.new(-2511.07, 228.97, -329.09), action = "walk"},
	{pos = Vector3.new(-2492.96, 224.48, -320.78), action = "walk"},
	{pos = Vector3.new(-2476.00, 218.60, -310.97), action = "walk"},
	{pos = Vector3.new(-2458.37, 211.76, -299.57), action = "walk"},
	{pos = Vector3.new(-2442.67, 205.27, -288.24), action = "walk"},
	{pos = Vector3.new(-2427.54, 198.34, -275.71), action = "walk"},
	{pos = Vector3.new(-2413.75, 191.70, -262.23), action = "walk"},
	{pos = Vector3.new(-2401.11, 185.62, -247.45), action = "walk"},
	{pos = Vector3.new(-2392.85, 181.84, -236.62), action = "walk"},
	{pos = Vector3.new(-2381.19, 176.66, -220.67), action = "walk"},
	{pos = Vector3.new(-2360.03, 167.25, -191.72), action = "walk"},
	{pos = Vector3.new(-2348.38, 162.07, -175.77), action = "walk"},
	{pos = Vector3.new(-2336.49, 156.78, -159.51), action = "walk"},
	{pos = Vector3.new(-2324.84, 151.60, -143.56), action = "walk"},
	{pos = Vector3.new(-2313.19, 146.42, -127.62), action = "walk"},
	{pos = Vector3.new(-2301.53, 141.24, -111.68), action = "walk"},
	{pos = Vector3.new(-2289.88, 136.06, -95.73), action = "walk"},
	{pos = Vector3.new(-2277.84, 131.02, -80.10), action = "walk"},
	{pos = Vector3.new(-2260.91, 126.98, -69.86), action = "walk"},
	{pos = Vector3.new(-2245.06, 124.21, -68.11), action = "walk"},
	{pos = Vector3.new(-2224.52, 121.91, -70.30), action = "walk"},
	{pos = Vector3.new(-2204.33, 119.75, -72.23), action = "walk"},
	{pos = Vector3.new(-2184.42, 118.09, -72.42), action = "walk"},
	{pos = Vector3.new(-2164.07, 116.61, -72.38), action = "walk"},
	{pos = Vector3.new(-2144.10, 115.62, -72.56), action = "walk"},
	{pos = Vector3.new(-2123.30, 114.64, -72.80), action = "walk"},
	{pos = Vector3.new(-2102.91, 113.95, -73.22), action = "walk"},
	{pos = Vector3.new(-2082.92, 113.40, -73.50), action = "walk"},
	{pos = Vector3.new(-2062.10, 112.89, -73.63), action = "walk"},
	{pos = Vector3.new(-2041.70, 112.65, -73.42), action = "walk"},
	{pos = Vector3.new(-2021.71, 112.70, -72.92), action = "walk"},
	{pos = Vector3.new(-2001.32, 112.89, -72.19), action = "walk"},
	{pos = Vector3.new(-1980.92, 113.17, -71.32), action = "walk"},
	{pos = Vector3.new(-1960.95, 113.60, -70.49), action = "walk"},
	{pos = Vector3.new(-1940.56, 114.18, -69.72), action = "walk"},
	{pos = Vector3.new(-1920.17, 114.78, -68.96), action = "walk"},
	{pos = Vector3.new(-1899.78, 115.37, -68.19), action = "walk"},
	{pos = Vector3.new(-1879.39, 115.97, -67.43), action = "walk"},
	{pos = Vector3.new(-1858.98, 116.54, -67.35), action = "walk"},
	{pos = Vector3.new(-1838.57, 117.08, -67.44), action = "walk"},
	{pos = Vector3.new(-1818.16, 117.58, -67.65), action = "walk"},
	{pos = Vector3.new(-1797.34, 118.09, -67.85), action = "walk"},
	{pos = Vector3.new(-1776.93, 118.59, -68.05), action = "walk"},
	{pos = Vector3.new(-1756.51, 118.94, -68.47), action = "walk"},
	{pos = Vector3.new(-1736.52, 119.09, -69.19), action = "walk"},
	{pos = Vector3.new(-1715.28, 119.22, -70.03), action = "walk"},
	{pos = Vector3.new(-1695.30, 119.35, -70.82), action = "walk"},
	{pos = Vector3.new(-1674.89, 119.47, -71.63), action = "walk"},
	{pos = Vector3.new(-1654.49, 119.60, -72.44), action = "walk"},
	{pos = Vector3.new(-1628.26, 119.76, -73.48), action = "walk"},
	{pos = Vector3.new(-1607.02, 119.89, -74.32), action = "walk"},
	{pos = Vector3.new(-1587.04, 120.01, -75.11), action = "walk"},
	{pos = Vector3.new(-1566.63, 120.14, -75.91), action = "walk"},
	{pos = Vector3.new(-1546.23, 120.26, -76.72), action = "walk"},
	{pos = Vector3.new(-1525.83, 120.39, -77.53), action = "walk"},
	{pos = Vector3.new(-1505.47, 120.29, -79.15), action = "walk"},
	{pos = Vector3.new(-1485.57, 120.12, -81.08), action = "walk"},
	{pos = Vector3.new(-1465.31, 119.76, -83.70), action = "walk"},
	{pos = Vector3.new(-1445.08, 119.37, -86.43), action = "walk"},
	{pos = Vector3.new(-1424.44, 118.98, -89.23), action = "walk"},
	{pos = Vector3.new(-1404.62, 118.60, -91.91), action = "walk"},
	{pos = Vector3.new(-1384.81, 118.22, -94.59), action = "walk"},
	{pos = Vector3.new(-1364.58, 117.83, -97.33), action = "walk"},
	{pos = Vector3.new(-1344.35, 117.45, -100.06), action = "walk"},
	{pos = Vector3.new(-1324.12, 117.06, -102.80), action = "walk"},
	{pos = Vector3.new(-1304.30, 116.68, -105.48), action = "walk"},
	{pos = Vector3.new(-1284.06, 116.26, -108.14), action = "walk"},
	{pos = Vector3.new(-1263.74, 115.64, -110.05), action = "walk"},
	{pos = Vector3.new(-1243.42, 115.02, -111.94), action = "walk"},
	{pos = Vector3.new(-1222.69, 114.39, -113.88), action = "walk"},
	{pos = Vector3.new(-1202.37, 113.77, -115.77), action = "walk"},
	{pos = Vector3.new(-1181.63, 113.13, -117.70), action = "walk"},
	{pos = Vector3.new(-1161.27, 112.49, -119.01), action = "walk"},
	{pos = Vector3.new(-1140.88, 111.82, -119.70), action = "walk"},
	{pos = Vector3.new(-1120.49, 111.08, -120.66), action = "walk"},
	{pos = Vector3.new(-1100.45, 110.33, -124.30), action = "walk"},
	{pos = Vector3.new(-1080.16, 109.62, -128.97), action = "walk"},
	{pos = Vector3.new(-1076.09, 109.49, -129.88), action = "wait", wait = 1.8},
	{pos = Vector3.new(-1058.93, 108.91, -133.25), action = "walk"},
	{pos = Vector3.new(-1038.90, 108.25, -137.18), action = "walk"},
	{pos = Vector3.new(-1018.88, 107.58, -141.11), action = "walk"},
	{pos = Vector3.new(-998.86, 106.91, -145.04), action = "walk"},
	{pos = Vector3.new(-978.83, 106.25, -148.97), action = "walk"},
	{pos = Vector3.new(-959.20, 105.59, -152.74), action = "walk"},
	{pos = Vector3.new(-939.03, 104.92, -155.84), action = "walk"},
	{pos = Vector3.new(-918.86, 104.26, -158.94), action = "walk"},
	{pos = Vector3.new(-899.05, 103.60, -161.55), action = "walk"},
	{pos = Vector3.new(-878.78, 102.94, -163.93), action = "walk"},
	{pos = Vector3.new(-858.10, 102.26, -166.35), action = "walk"},
	{pos = Vector3.new(-837.84, 101.58, -168.80), action = "walk"},
	{pos = Vector3.new(-817.77, 100.74, -172.46), action = "walk"},
	{pos = Vector3.new(-797.75, 99.89, -176.39), action = "walk"},
	{pos = Vector3.new(-777.73, 99.04, -180.31), action = "walk"},
	{pos = Vector3.new(-758.12, 98.20, -184.16), action = "walk"},
	{pos = Vector3.new(-738.52, 97.36, -188.01), action = "walk"},
	{pos = Vector3.new(-718.09, 96.49, -192.02), action = "walk"},
	{pos = Vector3.new(-698.48, 95.66, -195.87), action = "walk"},
	{pos = Vector3.new(-678.46, 94.80, -199.80), action = "walk"},
	{pos = Vector3.new(-658.45, 93.95, -203.73), action = "walk"},
	{pos = Vector3.new(-638.02, 93.08, -207.74), action = "walk"},
	{pos = Vector3.new(-618.41, 92.24, -211.59), action = "walk"},
	{pos = Vector3.new(-598.40, 91.39, -215.52), action = "walk"},
	{pos = Vector3.new(-578.39, 90.62, -219.42), action = "walk"},
	{pos = Vector3.new(-558.26, 90.20, -222.76), action = "walk"},
	{pos = Vector3.new(-538.04, 90.01, -225.55), action = "walk"},
	{pos = Vector3.new(-518.22, 89.86, -228.23), action = "walk"},
	{pos = Vector3.new(-497.99, 89.71, -230.97), action = "walk"},
	{pos = Vector3.new(-477.76, 89.55, -233.70), action = "walk"},
	{pos = Vector3.new(-457.53, 89.40, -236.44), action = "walk"},
	{pos = Vector3.new(-436.88, 89.25, -239.21), action = "walk"},
	{pos = Vector3.new(-416.62, 89.14, -241.71), action = "walk"},
	{pos = Vector3.new(-396.35, 89.03, -244.21), action = "walk"},
	{pos = Vector3.new(-376.49, 88.88, -246.53), action = "walk"},
	{pos = Vector3.new(-356.21, 88.73, -248.91), action = "walk"},
	{pos = Vector3.new(-335.93, 88.57, -251.29), action = "walk"},
	{pos = Vector3.new(-315.66, 88.42, -253.67), action = "walk"},
	{pos = Vector3.new(-295.79, 88.27, -255.99), action = "walk"},
	{pos = Vector3.new(-275.52, 88.12, -258.37), action = "walk"},
	{pos = Vector3.new(-255.23, 87.95, -260.72), action = "walk"},
	{pos = Vector3.new(-234.94, 87.75, -262.98), action = "walk"},
	{pos = Vector3.new(-214.65, 87.55, -265.23), action = "walk"},
	{pos = Vector3.new(-194.78, 87.35, -267.44), action = "walk"},
	{pos = Vector3.new(-174.49, 87.15, -269.70), action = "walk"},
	{pos = Vector3.new(-154.19, 86.95, -271.96), action = "walk"},
	{pos = Vector3.new(-134.32, 86.75, -274.17), action = "walk"},
	{pos = Vector3.new(-114.03, 86.55, -276.42), action = "walk"},
	{pos = Vector3.new(-94.13, 86.30, -278.49), action = "walk"},
	{pos = Vector3.new(-73.82, 86.00, -280.51), action = "walk"},
	{pos = Vector3.new(-53.08, 85.70, -282.46), action = "walk"},
	{pos = Vector3.new(-33.16, 85.42, -284.20), action = "walk"},
	{pos = Vector3.new(-12.82, 85.12, -285.98), action = "walk"},
	{pos = Vector3.new(7.52, 84.82, -287.73), action = "walk"},
	{pos = Vector3.new(27.92, 84.48, -288.48), action = "walk"},
	{pos = Vector3.new(48.33, 84.14, -289.04), action = "walk"},
	{pos = Vector3.new(68.73, 83.80, -289.61), action = "walk"},
	{pos = Vector3.new(88.72, 83.47, -290.16), action = "walk"},
	{pos = Vector3.new(109.13, 83.13, -290.73), action = "walk"},
	{pos = Vector3.new(129.53, 82.79, -291.29), action = "walk"},
	{pos = Vector3.new(149.94, 82.45, -291.86), action = "walk"},
	{pos = Vector3.new(169.93, 82.11, -292.41), action = "walk"},
	{pos = Vector3.new(190.75, 81.77, -292.99), action = "walk"},
	{pos = Vector3.new(210.74, 81.43, -293.54), action = "walk"},
	{pos = Vector3.new(231.15, 81.09, -294.11), action = "walk"},
	{pos = Vector3.new(251.13, 80.76, -294.66), action = "walk"},
	{pos = Vector3.new(271.54, 80.42, -295.23), action = "walk"},
	{pos = Vector3.new(291.95, 80.08, -295.79), action = "walk"},
	{pos = Vector3.new(312.35, 79.74, -296.36), action = "walk"},
	{pos = Vector3.new(332.34, 79.40, -296.91), action = "walk"},
	{pos = Vector3.new(353.16, 79.05, -297.49), action = "walk"},
	{pos = Vector3.new(373.57, 78.71, -298.05), action = "walk"},
	{pos = Vector3.new(393.56, 78.38, -298.61), action = "walk"},
	{pos = Vector3.new(413.55, 78.05, -299.16), action = "walk"},
	{pos = Vector3.new(434.37, 77.71, -299.69), action = "walk"},
	{pos = Vector3.new(454.70, 77.69, -298.03), action = "walk"},
	{pos = Vector3.new(475.02, 77.72, -296.06), action = "walk"},
	{pos = Vector3.new(495.03, 77.76, -292.76), action = "walk"},
	{pos = Vector3.new(511.24, 77.47, -280.36), action = "walk"},
	{pos = Vector3.new(527.03, 77.19, -268.09), action = "walk"},
	{pos = Vector3.new(543.71, 76.85, -255.62), action = "walk"},
	{pos = Vector3.new(561.11, 76.47, -245.76), action = "walk"},
	{pos = Vector3.new(579.01, 76.08, -235.96), action = "walk"},
	{pos = Vector3.new(597.56, 75.70, -227.48), action = "walk"},
	{pos = Vector3.new(616.44, 75.29, -219.70), action = "walk"},
	{pos = Vector3.new(635.47, 74.86, -212.32), action = "walk"},
	{pos = Vector3.new(654.11, 74.43, -205.09), action = "walk"},
	{pos = Vector3.new(673.17, 73.97, -197.79), action = "walk"},
	{pos = Vector3.new(692.37, 73.44, -190.86), action = "walk"},
	{pos = Vector3.new(712.38, 72.59, -185.06), action = "walk"},
	{pos = Vector3.new(732.21, 71.48, -180.30), action = "walk"},
	{pos = Vector3.new(753.12, 70.03, -176.80), action = "walk"},
	{pos = Vector3.new(773.29, 68.77, -174.20), action = "walk"},
	{pos = Vector3.new(793.65, 68.15, -172.95), action = "walk"},
	{pos = Vector3.new(814.03, 67.76, -171.96), action = "walk"},
	{pos = Vector3.new(837.41, 60.11, -171.64), action = "walk"},
	{pos = Vector3.new(853.49, 47.37, -171.72), action = "walk"},
	{pos = Vector3.new(869.12, 34.25, -172.16), action = "walk"},
	{pos = Vector3.new(881.31, 20.12, -172.57), action = "walk"},
	{pos = Vector3.new(893.13, 6.47, -173.31), action = "walk"},
	{pos = Vector3.new(906.33, -4.96, -169.12), action = "walk"},
	{pos = Vector3.new(921.46, -11.44, -161.37), action = "walk"},
	{pos = Vector3.new(940.97, -15.62, -161.76), action = "walk"},
	{pos = Vector3.new(960.41, -18.92, -158.39), action = "walk"},
	{pos = Vector3.new(976.96, -20.23, -146.64), action = "walk"},
	{pos = Vector3.new(989.14, -20.70, -131.19), action = "walk"},
	{pos = Vector3.new(1011.33, -19.18, -112.88), action = "walk"},
	{pos = Vector3.new(1030.15, -18.66, -106.12), action = "walk"},
	{pos = Vector3.new(1049.32, -18.09, -99.16), action = "walk"},
	{pos = Vector3.new(1068.88, -17.07, -95.57), action = "walk"},
	{pos = Vector3.new(1089.16, -15.61, -96.99), action = "walk"},
	{pos = Vector3.new(1109.30, -14.06, -99.96), action = "walk"},
	{pos = Vector3.new(1129.44, -12.50, -102.93), action = "walk"},
	{pos = Vector3.new(1149.58, -10.94, -105.90), action = "walk"},
	{pos = Vector3.new(1169.65, -9.51, -109.36), action = "walk"},
	{pos = Vector3.new(1189.69, -8.25, -113.12), action = "walk"},
	{pos = Vector3.new(1210.13, -6.95, -116.89), action = "walk"},
	{pos = Vector3.new(1230.18, -5.67, -120.50), action = "walk"},
	{pos = Vector3.new(1250.25, -4.39, -124.07), action = "walk"},
	{pos = Vector3.new(1270.20, -3.29, -128.29), action = "walk"},
	{pos = Vector3.new(1290.02, -2.23, -133.00), action = "walk"},
	{pos = Vector3.new(1310.59, 1.37, -139.51), action = "walk"},
	{pos = Vector3.new(1329.73, 5.48, -143.61), action = "walk"},
	{pos = Vector3.new(1349.57, 9.83, -148.08), action = "walk"},
	{pos = Vector3.new(1364.16, 14.77, -159.18), action = "walk"},
	{pos = Vector3.new(1378.19, 20.47, -172.02), action = "walk"},
	{pos = Vector3.new(1392.31, 24.62, -185.46), action = "walk"},
	{pos = Vector3.new(1417.77, 22.24, -184.09), action = "walk"},
	{pos = Vector3.new(1437.09, 17.29, -180.41), action = "walk"},
	{pos = Vector3.new(1456.59, 15.71, -182.26), action = "walk"},
	{pos = Vector3.new(1476.24, 16.40, -187.72), action = "walk"},
	{pos = Vector3.new(1495.96, 17.59, -189.81), action = "walk"},
	{pos = Vector3.new(1513.67, 18.87, -180.50), action = "walk"},
	{pos = Vector3.new(1525.73, 20.72, -163.73), action = "walk"},
	{pos = Vector3.new(1530.02, 23.21, -153.51), action = "walk"},
	{pos = Vector3.new(1535.10, 30.83, -135.35), action = "walk"},
	{pos = Vector3.new(1548.88, 44.47, -129.95), action = "walk"},
	{pos = Vector3.new(1548.75, 54.07, -136.63), action = "walk"},
	{pos = Vector3.new(1548.81, 55.78, -132.79), action = "walk"},
	{pos = Vector3.new(1559.33, 69.50, -122.43), action = "walk"},
	{pos = Vector3.new(1575.29, 81.39, -119.51), action = "walk"},
	{pos = Vector3.new(1597.13, 90.81, -121.43), action = "walk"},
	{pos = Vector3.new(1610.14, 93.72, -120.44), action = "wait", wait = 0.6},
	{pos = Vector3.new(1641.22, 99.50, -118.53), action = "walk"},
	{pos = Vector3.new(1661.31, 103.17, -118.63), action = "walk"},
	{pos = Vector3.new(1680.61, 106.09, -120.60), action = "walk"},
	{pos = Vector3.new(1710.85, 108.94, -122.47), action = "walk"},
	{pos = Vector3.new(1722.98, 109.14, -123.01), action = "walk"},
	{pos = Vector3.new(1729.26, 109.03, -123.43), action = "wait", wait = 143},
	{pos = Vector3.new(1784.92, 106.33, -135.23), action = "walk"},
	{pos = Vector3.new(1791.35, 106.18, -136.97), action = "wait", wait = 0.8},
	{pos = Vector3.new(1818.98, 108.20, -139.38), action = "walk"},
	{pos = Vector3.new(1827.62, 109.20, -139.77), action = "walk"},
	{pos = Vector3.new(1838.63, 111.03, -140.14), action = "wait", wait = 0.8},
	{pos = Vector3.new(1891.83, 127.61, -139.53), action = "walk"},
	{pos = Vector3.new(1904.36, 132.08, -139.63), action = "walk"},
	{pos = Vector3.new(1912.43, 135.25, -139.78), action = "walk"},
	{pos = Vector3.new(1947.83, 153.65, -139.70), action = "walk"},
	{pos = Vector3.new(1965.28, 164.21, -139.68), action = "walk"},
	{pos = Vector3.new(1982.45, 175.25, -139.75), action = "walk"},
	{pos = Vector3.new(1999.61, 186.31, -139.82), action = "walk"},
	{pos = Vector3.new(2013.67, 198.91, -141.07), action = "walk"},
	{pos = Vector3.new(2029.66, 211.01, -141.58), action = "walk"},
	{pos = Vector3.new(2046.20, 221.82, -141.72), action = "walk"},
	{pos = Vector3.new(2064.15, 231.65, -141.79), action = "walk"},
	{pos = Vector3.new(2082.74, 240.18, -142.47), action = "walk"},
	{pos = Vector3.new(2101.20, 247.79, -143.75), action = "walk"},
	{pos = Vector3.new(2120.34, 255.81, -145.35), action = "walk"},
	{pos = Vector3.new(2138.68, 264.39, -147.46), action = "walk"},
	{pos = Vector3.new(2156.81, 274.38, -149.59), action = "walk"},
	{pos = Vector3.new(2174.62, 284.91, -151.68), action = "walk"},
	{pos = Vector3.new(2194.57, 298.17, -154.56), action = "walk"},
	{pos = Vector3.new(2211.60, 309.85, -157.27), action = "walk"},
	{pos = Vector3.new(2228.29, 321.30, -159.94), action = "walk"},
	{pos = Vector3.new(2245.21, 332.51, -162.35), action = "walk"},
	{pos = Vector3.new(2263.11, 343.12, -163.80), action = "walk"},
	{pos = Vector3.new(2280.48, 352.98, -164.88), action = "walk"},
	{pos = Vector3.new(2298.61, 363.19, -165.90), action = "walk"},
	{pos = Vector3.new(2316.10, 372.88, -166.79), action = "walk"},
	{pos = Vector3.new(2335.06, 383.31, -167.77), action = "walk"},
	{pos = Vector3.new(2352.75, 393.22, -169.93), action = "walk"},
	{pos = Vector3.new(2370.63, 403.44, -173.00), action = "walk"},
	{pos = Vector3.new(2388.51, 413.67, -176.08), action = "walk"},
	{pos = Vector3.new(2406.12, 423.68, -178.59), action = "walk"},
	{pos = Vector3.new(2423.51, 433.41, -180.39), action = "walk"},
	{pos = Vector3.new(2441.39, 443.20, -181.60), action = "walk"},
	{pos = Vector3.new(2459.27, 452.98, -182.74), action = "walk"},
	{pos = Vector3.new(2477.52, 462.96, -183.89), action = "walk"},
	{pos = Vector3.new(2495.41, 472.73, -185.02), action = "walk"},
	{pos = Vector3.new(2512.93, 482.34, -185.71), action = "walk"},
	{pos = Vector3.new(2530.82, 492.18, -186.13), action = "walk"},
	{pos = Vector3.new(2543.36, 502.33, -188.56), action = "walk"},
	{pos = Vector3.new(2559.64, 511.82, -186.57), action = "walk"},
	{pos = Vector3.new(2578.25, 519.17, -182.13), action = "walk"},
	{pos = Vector3.new(2596.91, 525.21, -178.10), action = "walk"},
	{pos = Vector3.new(2616.90, 530.74, -175.99), action = "walk"},
	{pos = Vector3.new(2636.47, 534.99, -175.01), action = "walk"},
	{pos = Vector3.new(2656.59, 537.84, -181.08), action = "walk"},
	{pos = Vector3.new(2675.39, 540.52, -189.62), action = "walk"},
	{pos = Vector3.new(2692.92, 543.27, -200.46), action = "walk"},
	{pos = Vector3.new(2708.55, 546.05, -213.96), action = "walk"},
	{pos = Vector3.new(2723.76, 548.78, -227.30), action = "walk"},
	{pos = Vector3.new(2737.32, 551.56, -242.78), action = "walk"},
	{pos = Vector3.new(2749.23, 554.48, -259.08), action = "walk"},
	{pos = Vector3.new(2762.53, 557.90, -274.73), action = "walk"},
	{pos = Vector3.new(2776.23, 561.41, -290.59), action = "walk"},
	{pos = Vector3.new(2789.92, 564.92, -306.46), action = "walk"},
	{pos = Vector3.new(2803.38, 568.46, -321.94), action = "walk"},
	{pos = Vector3.new(2818.63, 572.52, -334.69), action = "walk"},
	{pos = Vector3.new(2838.22, 577.17, -333.66), action = "walk"},
	{pos = Vector3.new(2843.78, 579.47, -323.52), action = "walk"},
	{pos = Vector3.new(2846.26, 582.81, -303.11), action = "walk"},
	{pos = Vector3.new(2847.54, 585.89, -282.96), action = "walk"},
	{pos = Vector3.new(2856.95, 591.68, -263.38), action = "walk"},
	{pos = Vector3.new(2867.26, 599.17, -252.19), action = "walk"},
	{pos = Vector3.new(2880.25, 607.39, -239.10), action = "walk"},
	{pos = Vector3.new(2895.87, 618.27, -235.67), action = "walk"},
	{pos = Vector3.new(2901.13, 631.85, -246.06), action = "walk"},
	{pos = Vector3.new(2904.73, 643.03, -262.80), action = "walk"},
	{pos = Vector3.new(2914.66, 650.97, -278.83), action = "walk"},
	{pos = Vector3.new(2925.53, 658.07, -295.13), action = "walk"},
	{pos = Vector3.new(2932.30, 662.83, -306.60), action = "walk"},
	{pos = Vector3.new(2944.89, 670.40, -320.65), action = "walk"},
	{pos = Vector3.new(2958.98, 679.03, -331.89), action = "walk"},
	{pos = Vector3.new(2970.38, 688.63, -341.51), action = "walk"},
	{pos = Vector3.new(2987.90, 698.60, -343.83), action = "walk"},
	{pos = Vector3.new(3005.28, 709.15, -342.59), action = "walk"},
	{pos = Vector3.new(3021.97, 720.15, -336.74), action = "walk"},
	{pos = Vector3.new(3037.69, 730.58, -328.90), action = "walk"},
	{pos = Vector3.new(3047.38, 739.88, -318.42), action = "walk"},
	{pos = Vector3.new(3061.90, 750.10, -309.23), action = "walk"},
	{pos = Vector3.new(3075.25, 760.78, -292.80), action = "walk"},
	{pos = Vector3.new(3085.85, 769.01, -277.40), action = "walk"},
	{pos = Vector3.new(3098.35, 777.46, -263.73), action = "walk"},
	{pos = Vector3.new(3112.27, 791.31, -249.50), action = "walk"},
	{pos = Vector3.new(3118.71, 804.65, -239.86), action = "walk"},
	{pos = Vector3.new(3125.45, 818.92, -229.76), action = "walk"},
	{pos = Vector3.new(3129.77, 832.41, -218.71), action = "walk"},
	{pos = Vector3.new(3132.22, 846.03, -206.92), action = "walk"},
	{pos = Vector3.new(3136.41, 856.73, -190.00), action = "walk"},
	{pos = Vector3.new(3142.93, 866.16, -173.07), action = "walk"},
	{pos = Vector3.new(3147.32, 874.97, -154.67), action = "walk"},
	{pos = Vector3.new(3151.75, 882.82, -136.34), action = "walk"},
	{pos = Vector3.new(3154.84, 890.87, -117.87), action = "walk"},
	{pos = Vector3.new(3156.76, 899.63, -99.58), action = "walk"},
	{pos = Vector3.new(3159.99, 909.25, -81.91), action = "walk"},
	{pos = Vector3.new(3163.84, 919.59, -64.75), action = "walk"},
	{pos = Vector3.new(3167.95, 930.18, -47.82), action = "walk"},
	{pos = Vector3.new(3173.94, 941.81, -32.22), action = "walk"},
	{pos = Vector3.new(3181.41, 954.68, -18.32), action = "walk"},
	{pos = Vector3.new(3189.32, 967.80, -4.83), action = "walk"},
	{pos = Vector3.new(3194.13, 981.59, 5.73), action = "walk"},
	{pos = Vector3.new(3203.34, 993.50, 19.16), action = "walk"},
	{pos = Vector3.new(3215.47, 1003.04, 33.82), action = "walk"},
	{pos = Vector3.new(3228.21, 1010.47, 48.07), action = "walk"},
	{pos = Vector3.new(3243.27, 1016.50, 61.15), action = "walk"},
	{pos = Vector3.new(3258.67, 1022.08, 73.38), action = "walk"},
	{pos = Vector3.new(3273.50, 1026.58, 88.50), action = "walk"},
	{pos = Vector3.new(3284.03, 1029.68, 106.22), action = "walk"},
	{pos = Vector3.new(3293.61, 1032.51, 124.51), action = "walk"},
	{pos = Vector3.new(3300.99, 1034.73, 143.88), action = "walk"},
	{pos = Vector3.new(3307.79, 1036.72, 163.04), action = "walk"},
	{pos = Vector3.new(3314.12, 1038.58, 182.36), action = "walk"},
	{pos = Vector3.new(3319.33, 1040.32, 202.46), action = "walk"},
	{pos = Vector3.new(3322.71, 1041.87, 222.96), action = "walk"},
	{pos = Vector3.new(3324.87, 1043.24, 243.22), action = "walk"},
	{pos = Vector3.new(3326.85, 1044.57, 263.49), action = "walk"},
	{pos = Vector3.new(3328.82, 1045.91, 283.77), action = "walk"},
	{pos = Vector3.new(3330.76, 1047.21, 303.64), action = "walk"},
	{pos = Vector3.new(3332.74, 1048.53, 323.92), action = "walk"},
	{pos = Vector3.new(3335.94, 1049.69, 344.04), action = "walk"},
	{pos = Vector3.new(3342.56, 1050.74, 363.75), action = "walk"},
	{pos = Vector3.new(3353.05, 1051.60, 381.08), action = "walk"},
	{pos = Vector3.new(3368.92, 1052.46, 395.11), action = "walk"},
	{pos = Vector3.new(3386.94, 1053.67, 403.43), action = "walk"},
	{pos = Vector3.new(3405.96, 1056.37, 403.90), action = "wait", wait = 0.6},
	{pos = Vector3.new(3418.42, 1069.42, 389.82), action = "walk"},
	{pos = Vector3.new(3422.80, 1080.45, 386.48), action = "walk"},
	{pos = Vector3.new(3427.85, 1091.30, 387.52), action = "walk"},
	{pos = Vector3.new(3431.70, 1103.54, 387.26), action = "walk"},
	{pos = Vector3.new(3437.38, 1116.13, 378.10), action = "walk"},
	{pos = Vector3.new(3442.99, 1128.09, 365.54), action = "walk"},
	{pos = Vector3.new(3451.93, 1137.13, 349.55), action = "walk"},
	{pos = Vector3.new(3461.05, 1145.36, 333.16), action = "walk"},
	{pos = Vector3.new(3468.79, 1151.90, 315.41), action = "walk"},
	{pos = Vector3.new(3475.35, 1159.10, 297.54), action = "walk"},
	{pos = Vector3.new(3481.41, 1167.02, 279.74), action = "walk"},
	{pos = Vector3.new(3487.84, 1175.91, 263.18), action = "walk"},
	{pos = Vector3.new(3494.27, 1186.93, 247.28), action = "walk"},
	{pos = Vector3.new(3500.50, 1198.14, 231.94), action = "walk"},
	{pos = Vector3.new(3506.74, 1209.35, 216.60), action = "walk"},
	{pos = Vector3.new(3513.23, 1221.03, 200.62), action = "walk"},
	{pos = Vector3.new(3520.53, 1232.51, 184.83), action = "walk"},
	{pos = Vector3.new(3529.09, 1243.72, 169.50), action = "walk"},
	{pos = Vector3.new(3536.46, 1255.08, 157.15), action = "walk"},
	{pos = Vector3.new(3543.89, 1267.02, 145.37), action = "walk"},
	{pos = Vector3.new(3556.55, 1277.84, 132.85), action = "walk"},
	{pos = Vector3.new(3569.07, 1288.18, 120.52), action = "walk"},
	{pos = Vector3.new(3581.24, 1297.87, 107.31), action = "walk"},
	{pos = Vector3.new(3592.05, 1307.33, 93.39), action = "walk"},
	{pos = Vector3.new(3602.81, 1317.01, 79.02), action = "walk"},
	{pos = Vector3.new(3610.25, 1326.95, 62.81), action = "walk"},
	{pos = Vector3.new(3617.71, 1337.09, 46.21), action = "walk"},
	{pos = Vector3.new(3625.16, 1347.04, 30.02), action = "walk"},
	{pos = Vector3.new(3624.28, 1358.38, 18.43), action = "walk"},
	{pos = Vector3.new(3625.51, 1369.38, 7.24), action = "walk"},
	{pos = Vector3.new(3628.09, 1381.18, -5.19), action = "walk"},
	{pos = Vector3.new(3629.55, 1393.52, -13.62), action = "walk"},
	{pos = Vector3.new(3636.67, 1403.84, -28.32), action = "walk"},
	{pos = Vector3.new(3643.46, 1413.17, -42.91), action = "walk"},
	{pos = Vector3.new(3647.71, 1422.45, -57.03), action = "walk"},
	{pos = Vector3.new(3653.20, 1431.21, -71.68), action = "walk"},
	{pos = Vector3.new(3661.04, 1440.02, -87.12), action = "walk"},
	{pos = Vector3.new(3666.28, 1450.53, -102.28), action = "walk"},
	{pos = Vector3.new(3673.66, 1460.36, -119.99), action = "walk"},
	{pos = Vector3.new(3680.13, 1470.02, -135.31), action = "walk"},
	{pos = Vector3.new(3686.36, 1479.94, -150.80), action = "walk"},
	{pos = Vector3.new(3693.65, 1488.37, -166.58), action = "walk"},
	{pos = Vector3.new(3706.39, 1493.94, -181.69), action = "walk"},
	{pos = Vector3.new(3718.77, 1499.68, -196.63), action = "walk"},
	{pos = Vector3.new(3734.43, 1504.13, -210.27), action = "walk"},
	{pos = Vector3.new(3752.16, 1507.31, -221.65), action = "walk"},
	{pos = Vector3.new(3769.42, 1505.70, -227.97), action = "walk"},
	{pos = Vector3.new(3781.46, 1501.65, -244.34), action = "walk"},
	{pos = Vector3.new(3790.15, 1496.82, -262.19), action = "walk"},
	{pos = Vector3.new(3798.62, 1491.49, -280.97), action = "walk"},
	{pos = Vector3.new(3806.58, 1484.94, -298.65), action = "walk"},
	{pos = Vector3.new(3814.40, 1478.01, -316.67), action = "walk"},
	{pos = Vector3.new(3822.24, 1470.73, -334.58), action = "walk"},
	{pos = Vector3.new(3830.41, 1462.41, -351.40), action = "walk"},
	{pos = Vector3.new(3839.14, 1452.86, -368.28), action = "walk"},
	{pos = Vector3.new(3848.12, 1443.57, -384.06), action = "walk"},
	{pos = Vector3.new(3861.56, 1433.38, -396.31), action = "walk"},
	{pos = Vector3.new(3877.44, 1422.22, -402.39), action = "walk"},
	{pos = Vector3.new(3894.23, 1410.02, -400.77), action = "walk"},
	{pos = Vector3.new(3910.91, 1398.83, -397.37), action = "walk"},
	{pos = Vector3.new(3927.18, 1387.78, -393.55), action = "walk"},
	{pos = Vector3.new(3943.43, 1375.59, -391.32), action = "walk"},
	{pos = Vector3.new(3959.63, 1363.27, -389.60), action = "walk"},
	{pos = Vector3.new(3975.80, 1350.90, -387.88), action = "walk"},
	{pos = Vector3.new(3991.41, 1337.85, -386.05), action = "walk"},
	{pos = Vector3.new(4006.62, 1324.99, -384.25), action = "walk"},
	{pos = Vector3.new(4022.36, 1311.60, -381.61), action = "walk"},
	{pos = Vector3.new(4037.76, 1298.48, -378.86), action = "walk"},
	{pos = Vector3.new(4053.15, 1285.36, -376.10), action = "walk"},
	{pos = Vector3.new(4068.58, 1272.44, -372.78), action = "walk"},
	{pos = Vector3.new(4084.43, 1260.09, -367.43), action = "walk"},
	{pos = Vector3.new(4099.97, 1248.32, -361.43), action = "walk"},
	{pos = Vector3.new(4115.63, 1237.97, -353.75), action = "walk"},
	{pos = Vector3.new(4132.44, 1230.11, -344.48), action = "walk"},
	{pos = Vector3.new(4148.82, 1223.20, -335.33), action = "walk"},
	{pos = Vector3.new(4165.55, 1216.53, -325.80), action = "walk"},
	{pos = Vector3.new(4182.20, 1210.61, -315.60), action = "walk"},
	{pos = Vector3.new(4199.12, 1204.85, -304.94), action = "walk"},
	{pos = Vector3.new(4215.97, 1199.40, -293.99), action = "walk"},
	{pos = Vector3.new(4232.67, 1194.79, -282.55), action = "walk"},
	{pos = Vector3.new(4248.80, 1191.75, -270.50), action = "walk"},
	{pos = Vector3.new(4264.78, 1189.63, -258.04), action = "walk"},
	{pos = Vector3.new(4280.55, 1188.51, -245.17), action = "walk"},
	{pos = Vector3.new(4296.32, 1187.55, -232.23), action = "walk"},
	{pos = Vector3.new(4311.68, 1186.61, -219.46), action = "walk"},
	{pos = Vector3.new(4326.97, 1185.35, -205.33), action = "walk"},
	{pos = Vector3.new(4342.40, 1183.25, -192.07), action = "walk"},
	{pos = Vector3.new(4359.01, 1180.25, -179.81), action = "walk"},
	{pos = Vector3.new(4376.32, 1175.79, -169.02), action = "walk"},
	{pos = Vector3.new(4393.20, 1170.93, -159.45), action = "walk"},
	{pos = Vector3.new(4408.92, 1166.23, -147.38), action = "walk"},
	{pos = Vector3.new(4411.11, 1165.57, -145.56), action = "wait", wait = 0.6},
	{pos = Vector3.new(4417.66, 1163.59, -140.11), action = "walk"},
	{pos = Vector3.new(4432.64, 1159.08, -127.66), action = "walk"},
	{pos = Vector3.new(4448.24, 1154.38, -114.69), action = "walk"},
	{pos = Vector3.new(4451.98, 1153.26, -111.59), action = "wait", wait = 0.6},
	{pos = Vector3.new(4476.97, 1146.38, -92.66), action = "walk"},
	{pos = Vector3.new(4488.73, 1143.17, -83.91), action = "walk"},
	{pos = Vector3.new(4504.74, 1138.79, -72.01), action = "walk"},
	{pos = Vector3.new(4520.29, 1134.59, -59.52), action = "walk"},
	{pos = Vector3.new(4534.38, 1130.75, -45.86), action = "walk"},
	{pos = Vector3.new(4548.39, 1126.79, -30.98), action = "walk"},
	{pos = Vector3.new(4560.87, 1123.03, -15.29), action = "walk"},
	{pos = Vector3.new(4562.88, 1122.39, -12.21), action = "wait", wait = 1.0},
	{pos = Vector3.new(4585.40, 1118.14, 43.37), action = "walk"},
	{pos = Vector3.new(4592.62, 1118.45, 62.45), action = "walk"},
	{pos = Vector3.new(4599.84, 1118.98, 81.54), action = "walk"},
	{pos = Vector3.new(4607.08, 1119.51, 100.63), action = "walk"},
	{pos = Vector3.new(4616.50, 1117.79, 119.27), action = "walk"},
	{pos = Vector3.new(4627.09, 1113.35, 135.71), action = "walk"},
	{pos = Vector3.new(4638.14, 1106.76, 151.67), action = "walk"},
	{pos = Vector3.new(4647.52, 1098.54, 167.36), action = "walk"},
	{pos = Vector3.new(4655.72, 1089.03, 183.53), action = "walk"},
	{pos = Vector3.new(4662.23, 1077.88, 199.41), action = "walk"},
	{pos = Vector3.new(4668.95, 1066.41, 214.36), action = "walk"},
	{pos = Vector3.new(4676.38, 1054.53, 229.22), action = "walk"},
	{pos = Vector3.new(4683.98, 1042.08, 244.12), action = "walk"},
	{pos = Vector3.new(4690.97, 1029.90, 258.35), action = "walk"},
	{pos = Vector3.new(4696.20, 1018.03, 274.06), action = "walk"},
	{pos = Vector3.new(4700.41, 1006.73, 291.01), action = "walk"},
	{pos = Vector3.new(4704.53, 995.67, 307.67), action = "walk"},
	{pos = Vector3.new(4708.66, 984.65, 324.34), action = "walk"},
	{pos = Vector3.new(4713.56, 975.09, 341.12), action = "walk"},
	{pos = Vector3.new(4719.01, 966.08, 358.60), action = "walk"},
	{pos = Vector3.new(4724.53, 957.14, 376.10), action = "walk"},
	{pos = Vector3.new(4734.51, 948.89, 391.12), action = "walk"},
	{pos = Vector3.new(4749.84, 941.57, 402.85), action = "walk"},
	{pos = Vector3.new(4766.98, 935.72, 411.31), action = "walk"},
	{pos = Vector3.new(4784.82, 930.22, 419.40), action = "walk"},
	{pos = Vector3.new(4803.81, 926.15, 423.99), action = "walk"},
	{pos = Vector3.new(4815.17, 924.15, 425.54), action = "walk"},
	{pos = Vector3.new(4835.15, 920.74, 427.90), action = "walk"},
	{pos = Vector3.new(4855.60, 917.21, 429.42), action = "walk"},
	{pos = Vector3.new(4864.22, 915.71, 429.61), action = "walk"},
	{pos = Vector3.new(4876.93, 913.49, 429.90), action = "walk"},
	{pos = Vector3.new(4896.63, 909.99, 430.22), action = "walk"},
	{pos = Vector3.new(4909.16, 906.39, 427.26), action = "walk"},
	{pos = Vector3.new(4934.67, 896.06, 413.39), action = "walk"},
	{pos = Vector3.new(4950.06, 886.84, 402.61), action = "walk"},
	{pos = Vector3.new(4963.58, 877.15, 392.26), action = "walk"},
	{pos = Vector3.new(4977.96, 866.84, 381.25), action = "walk"},
	{pos = Vector3.new(4991.08, 856.49, 369.53), action = "walk"},
	{pos = Vector3.new(5001.82, 845.64, 355.37), action = "walk"},
	{pos = Vector3.new(5010.45, 833.40, 336.25), action = "walk"},
	{pos = Vector3.new(5016.37, 819.75, 308.02), action = "walk"},
	{pos = Vector3.new(5018.17, 816.48, 298.32), action = "walk"},
	{pos = Vector3.new(5024.41, 807.05, 268.30), action = "walk"},
	{pos = Vector3.new(5032.49, 799.26, 243.91), action = "walk"},
	{pos = Vector3.new(5038.16, 796.82, 237.79), action = "walk"},
	{pos = Vector3.new(5077.13, 785.66, 230.62), action = "walk"},
	{pos = Vector3.new(5085.93, 783.33, 229.67), action = "walk"},
	{pos = Vector3.new(5113.96, 777.68, 223.19), action = "walk"},
	{pos = Vector3.new(5132.04, 775.31, 214.12), action = "walk"},
	{pos = Vector3.new(5148.21, 773.39, 201.96), action = "walk"},
	{pos = Vector3.new(5162.03, 771.80, 186.44), action = "walk"},
	{pos = Vector3.new(5175.27, 770.27, 171.53), action = "walk"},
	{pos = Vector3.new(5187.00, 769.08, 154.88), action = "walk"},
	{pos = Vector3.new(5197.28, 768.06, 137.81), action = "walk"},
	{pos = Vector3.new(5200.85, 767.81, 129.40), action = "walk"},
	{pos = Vector3.new(5206.49, 767.68, 109.82), action = "walk"},
	{pos = Vector3.new(5210.67, 767.75, 89.84), action = "walk"},
	{pos = Vector3.new(5214.75, 767.81, 70.25), action = "walk"},
	{pos = Vector3.new(5218.92, 767.88, 50.26), action = "walk"},
	{pos = Vector3.new(5222.99, 767.94, 30.68), action = "walk"},
	{pos = Vector3.new(5227.82, 768.01, 10.44), action = "walk"},
	{pos = Vector3.new(5234.29, 768.07, -8.49), action = "walk"},
	{pos = Vector3.new(5240.76, 768.14, -27.41), action = "walk"},
	{pos = Vector3.new(5247.51, 768.20, -47.12), action = "walk"},
	{pos = Vector3.new(5257.67, 767.97, -64.30), action = "walk"},
	{pos = Vector3.new(5269.33, 767.63, -81.05), action = "walk"},
	{pos = Vector3.new(5282.71, 767.09, -96.46), action = "walk"},
	{pos = Vector3.new(5296.53, 766.55, -111.47), action = "walk"},
	{pos = Vector3.new(5310.22, 766.00, -126.61), action = "walk"},
	{pos = Vector3.new(5323.62, 765.46, -141.99), action = "walk"},
	{pos = Vector3.new(5337.41, 765.94, -156.14), action = "walk"},
	{pos = Vector3.new(5354.78, 765.12, -166.76), action = "walk"},
	{pos = Vector3.new(5368.41, 764.19, -171.88), action = "walk"},
	{pos = Vector3.new(5388.54, 761.93, -174.57), action = "walk"},
	{pos = Vector3.new(5408.53, 757.27, -174.12), action = "walk"},
	{pos = Vector3.new(5426.84, 748.08, -172.32), action = "walk"},
	{pos = Vector3.new(5442.86, 735.36, -171.14), action = "walk"},
	{pos = Vector3.new(5458.41, 722.23, -169.45), action = "walk"},
	{pos = Vector3.new(5473.62, 709.38, -167.56), action = "walk"},
	{pos = Vector3.new(5489.15, 696.26, -165.63), action = "walk"},
	{pos = Vector3.new(5504.95, 682.86, -163.37), action = "walk"},
	{pos = Vector3.new(5520.75, 669.47, -161.03), action = "walk"},
	{pos = Vector3.new(5535.87, 656.62, -158.60), action = "walk"},
	{pos = Vector3.new(5551.60, 643.23, -155.89), action = "walk"},
	{pos = Vector3.new(5566.69, 630.37, -153.28), action = "walk"},
	{pos = Vector3.new(5582.10, 617.25, -150.62), action = "walk"},
	{pos = Vector3.new(5597.51, 604.12, -147.95), action = "walk"},
	{pos = Vector3.new(5612.90, 591.00, -145.19), action = "walk"},
	{pos = Vector3.new(5628.28, 577.88, -142.34), action = "walk"},
	{pos = Vector3.new(5643.35, 565.02, -139.56), action = "walk"},
	{pos = Vector3.new(5658.74, 551.90, -136.71), action = "walk"},
	{pos = Vector3.new(5674.18, 539.05, -133.24), action = "walk"},
	{pos = Vector3.new(5689.53, 527.18, -128.56), action = "walk"},
	{pos = Vector3.new(5705.25, 515.30, -123.21), action = "walk"},
	{pos = Vector3.new(5720.97, 503.43, -117.81), action = "walk"},
	{pos = Vector3.new(5736.68, 491.69, -112.16), action = "walk"},
	{pos = Vector3.new(5752.47, 480.27, -106.09), action = "walk"},
	{pos = Vector3.new(5768.66, 469.22, -100.49), action = "walk"},
	{pos = Vector3.new(5784.83, 458.69, -95.24), action = "walk"},
	{pos = Vector3.new(5801.31, 448.11, -89.56), action = "walk"},
	{pos = Vector3.new(5817.72, 437.73, -83.25), action = "walk"},
	{pos = Vector3.new(5834.13, 427.35, -76.92), action = "walk"},
	{pos = Vector3.new(5850.50, 417.01, -70.41), action = "walk"},
	{pos = Vector3.new(5866.86, 406.66, -63.91), action = "walk"},
	{pos = Vector3.new(5882.55, 396.21, -56.30), action = "walk"},
	{pos = Vector3.new(5883.65, 384.35, -40.64), action = "walk"},
	{pos = Vector3.new(5877.70, 372.24, -25.88), action = "wait", wait = 0.8},
	{pos = Vector3.new(5862.32, 353.39, -41.00), action = "walk"},
	{pos = Vector3.new(5857.03, 348.60, -32.94), action = "wait", wait = 0.8},
	{pos = Vector3.new(5876.85, 336.45, -7.82), action = "walk"},
	{pos = Vector3.new(5884.41, 331.48, 0.82), action = "wait", wait = 1.2},
	{pos = Vector3.new(5884.43, 325.09, 4.76), action = "drink_spot"},
	{pos = Vector3.new(5884.58, 325.01, 4.73), action = "drink_spot"},
	{pos = Vector3.new(5888.67, 322.29, 6.63), action = "drink_spot"},
	{pos = Vector3.new(5883.89, 324.91, 4.46), action = "wait", wait = 3.6},
	{pos = Vector3.new(5886.34, 321.45, 5.91), action = "drink_spot"},
	{pos = Vector3.new(5886.32, 321.43, 5.91), action = "wait", wait = 242},
	{pos = Vector3.new(5890.55, 320.58, -13.08), action = "walk"},
	{pos = Vector3.new(5892.68, 320.15, -21.98), action = "wait", wait = 0.6},
	{pos = Vector3.new(5912.59, 320.81, -22.36), action = "walk"},
	{pos = Vector3.new(5932.93, 321.59, -21.16), action = "walk"},
	{pos = Vector3.new(5952.93, 322.73, -17.25), action = "walk"},
	{pos = Vector3.new(5972.24, 324.09, -12.37), action = "walk"},
	{pos = Vector3.new(5991.39, 326.24, -5.73), action = "walk"},
	{pos = Vector3.new(6010.75, 328.75, 1.52), action = "walk"},
	{pos = Vector3.new(6029.31, 331.18, 8.55), action = "walk"},
	{pos = Vector3.new(6048.26, 333.67, 15.72), action = "walk"},
	{pos = Vector3.new(6067.21, 336.15, 22.90), action = "walk"},
	{pos = Vector3.new(6087.00, 338.66, 28.88), action = "walk"},
	{pos = Vector3.new(6106.15, 341.05, 34.12), action = "walk"},
	{pos = Vector3.new(6125.29, 343.44, 39.36), action = "walk"},
	{pos = Vector3.new(6144.62, 345.97, 45.33), action = "walk"},
	{pos = Vector3.new(6164.36, 349.08, 53.72), action = "walk"},
	{pos = Vector3.new(6182.95, 352.03, 61.65), action = "walk"},
	{pos = Vector3.new(6201.16, 354.92, 69.42), action = "walk"},
	{pos = Vector3.new(6219.75, 357.87, 77.35), action = "walk"},
	{pos = Vector3.new(6238.34, 360.81, 85.29), action = "walk"},
	{pos = Vector3.new(6256.93, 363.76, 93.22), action = "walk"},
	{pos = Vector3.new(6275.90, 366.77, 101.31), action = "walk"},
	{pos = Vector3.new(6294.49, 369.72, 109.25), action = "walk"},
	{pos = Vector3.new(6313.08, 372.66, 117.18), action = "walk"},
	{pos = Vector3.new(6331.29, 375.55, 124.95), action = "walk"},
	{pos = Vector3.new(6349.50, 378.44, 132.72), action = "walk"},
	{pos = Vector3.new(6368.47, 381.44, 140.82), action = "walk"},
	{pos = Vector3.new(6386.73, 384.32, 149.47), action = "walk"},
	{pos = Vector3.new(6403.60, 386.83, 161.44), action = "walk"},
	{pos = Vector3.new(6415.68, 389.85, 175.71), action = "walk"},
	{pos = Vector3.new(6426.95, 389.36, 192.77), action = "walk"},
	{pos = Vector3.new(6440.69, 388.31, 208.23), action = "walk"},
	{pos = Vector3.new(6457.61, 387.48, 219.55), action = "walk"},
	{pos = Vector3.new(6475.09, 386.91, 229.25), action = "walk"},
	{pos = Vector3.new(6493.08, 386.39, 238.87), action = "walk"},
	{pos = Vector3.new(6510.98, 385.94, 247.79), action = "walk"},
	{pos = Vector3.new(6530.15, 385.52, 256.95), action = "walk"},
	{pos = Vector3.new(6548.20, 385.13, 265.56), action = "walk"},
	{pos = Vector3.new(6566.24, 384.73, 274.17), action = "walk"},
	{pos = Vector3.new(6584.67, 384.33, 282.96), action = "walk"},
	{pos = Vector3.new(6602.85, 383.89, 291.27), action = "walk"},
	{pos = Vector3.new(6626.39, 382.80, 298.26), action = "walk"},
	{pos = Vector3.new(6647.12, 381.78, 299.96), action = "walk"},
	{pos = Vector3.new(6667.48, 380.77, 301.05), action = "walk"},
	{pos = Vector3.new(6688.26, 379.74, 302.16), action = "walk"},
	{pos = Vector3.new(6708.64, 378.74, 303.02), action = "walk"},
	{pos = Vector3.new(6729.44, 377.71, 303.52), action = "walk"},
	{pos = Vector3.new(6749.82, 376.72, 303.84), action = "walk"},
	{pos = Vector3.new(6769.79, 375.78, 303.55), action = "walk"},
	{pos = Vector3.new(6790.59, 374.85, 302.94), action = "walk"},
	{pos = Vector3.new(6811.39, 373.92, 302.20), action = "walk"},
	{pos = Vector3.new(6831.36, 373.03, 301.49), action = "walk"},
	{pos = Vector3.new(6851.74, 372.11, 300.76), action = "walk"},
	{pos = Vector3.new(6872.11, 371.18, 299.76), action = "walk"},
	{pos = Vector3.new(6892.43, 370.18, 298.07), action = "walk"},
	{pos = Vector3.new(6913.15, 369.15, 296.34), action = "walk"},
	{pos = Vector3.new(6933.47, 368.15, 294.65), action = "walk"},
	{pos = Vector3.new(6953.78, 367.14, 292.96), action = "walk"},
	{pos = Vector3.new(6974.09, 366.13, 291.27), action = "walk"},
	{pos = Vector3.new(6994.41, 365.13, 289.57), action = "walk"},
	{pos = Vector3.new(7014.72, 364.12, 287.88), action = "walk"},
	{pos = Vector3.new(7034.62, 363.13, 286.23), action = "walk"},
	{pos = Vector3.new(7054.93, 362.13, 284.54), action = "walk"},
	{pos = Vector3.new(7075.24, 361.12, 282.84), action = "walk"},
	{pos = Vector3.new(7095.56, 360.11, 281.15), action = "walk"},
	{pos = Vector3.new(7115.88, 359.11, 279.54), action = "walk"},
	{pos = Vector3.new(7136.63, 358.08, 278.19), action = "walk"},
	{pos = Vector3.new(7156.97, 357.07, 276.86), action = "walk"},
	{pos = Vector3.new(7177.30, 356.07, 275.53), action = "walk"},
	{pos = Vector3.new(7197.64, 355.06, 274.20), action = "walk"},
	{pos = Vector3.new(7217.98, 354.06, 272.87), action = "walk"},
	{pos = Vector3.new(7238.73, 353.03, 271.51), action = "walk"},
	{pos = Vector3.new(7259.07, 352.02, 270.18), action = "walk"},
	{pos = Vector3.new(7281.89, 350.89, 268.69), action = "walk"},
	{pos = Vector3.new(7302.64, 349.83, 267.14), action = "walk"},
	{pos = Vector3.new(7322.95, 348.78, 265.45), action = "walk"},
	{pos = Vector3.new(7343.25, 347.68, 263.57), action = "walk"},
	{pos = Vector3.new(7363.13, 346.56, 261.56), action = "walk"},
	{pos = Vector3.new(7383.42, 345.41, 259.50), action = "walk"},
	{pos = Vector3.new(7403.71, 344.27, 257.45), action = "walk"},
	{pos = Vector3.new(7423.58, 343.15, 255.44), action = "walk"},
	{pos = Vector3.new(7444.25, 341.81, 253.04), action = "walk"},
	{pos = Vector3.new(7464.39, 340.16, 250.06), action = "walk"},
	{pos = Vector3.new(7484.11, 338.48, 247.12), action = "walk"},
	{pos = Vector3.new(7505.03, 336.32, 244.06), action = "walk"},
	{pos = Vector3.new(7525.13, 334.19, 241.18), action = "walk"},
	{pos = Vector3.new(7544.82, 332.01, 238.36), action = "walk"},
	{pos = Vector3.new(7564.90, 329.64, 235.51), action = "walk"},
	{pos = Vector3.new(7584.99, 327.28, 232.84), action = "walk"},
	{pos = Vector3.new(7605.13, 324.98, 230.43), action = "walk"},
	{pos = Vector3.new(7625.71, 322.67, 228.10), action = "walk"},
	{pos = Vector3.new(7646.33, 320.45, 226.24), action = "walk"},
	{pos = Vector3.new(7666.53, 318.67, 225.97), action = "walk"},
	{pos = Vector3.new(7685.71, 316.31, 226.65), action = "walk"},
	{pos = Vector3.new(7705.35, 316.77, 230.47), action = "walk"},
	{pos = Vector3.new(7723.96, 317.39, 236.56), action = "walk"},
	{pos = Vector3.new(7742.36, 318.24, 245.27), action = "walk"},
	{pos = Vector3.new(7760.34, 319.44, 254.84), action = "walk"},
	{pos = Vector3.new(7781.43, 320.37, 257.06), action = "walk"},
	{pos = Vector3.new(7801.38, 321.20, 258.28), action = "walk"},
	{pos = Vector3.new(7822.10, 321.70, 260.41), action = "walk"},
	{pos = Vector3.new(7842.82, 321.99, 262.63), action = "walk"},
	{pos = Vector3.new(7862.71, 321.93, 264.77), action = "walk"},
	{pos = Vector3.new(7883.01, 321.44, 266.95), action = "walk"},
	{pos = Vector3.new(7902.88, 320.88, 269.23), action = "walk"},
	{pos = Vector3.new(7922.50, 319.67, 272.81), action = "walk"},
	{pos = Vector3.new(7940.48, 318.70, 281.94), action = "walk"},
	{pos = Vector3.new(7956.99, 318.80, 294.64), action = "walk"},
	{pos = Vector3.new(7973.35, 317.66, 306.53), action = "walk"},
	{pos = Vector3.new(7990.47, 317.43, 316.58), action = "walk"},
	{pos = Vector3.new(8007.37, 314.06, 322.51), action = "walk"},
	{pos = Vector3.new(8020.26, 314.95, 338.37), action = "walk"},
	{pos = Vector3.new(8027.34, 317.23, 357.19), action = "walk"},
	{pos = Vector3.new(8032.44, 319.83, 376.80), action = "walk"},
	{pos = Vector3.new(8038.23, 322.19, 396.23), action = "walk"},
	{pos = Vector3.new(8043.74, 324.44, 416.21), action = "walk"},
	{pos = Vector3.new(8049.47, 326.17, 435.28), action = "walk"},
	{pos = Vector3.new(8054.89, 327.75, 454.50), action = "walk"},
	{pos = Vector3.new(8059.22, 328.98, 473.99), action = "walk"},
	{pos = Vector3.new(8064.72, 327.65, 493.44), action = "walk"},
	{pos = Vector3.new(8065.59, 328.51, 513.72), action = "walk"},
	{pos = Vector3.new(8065.23, 329.88, 533.63), action = "walk"},
	{pos = Vector3.new(8068.99, 331.53, 554.05), action = "walk"},
	{pos = Vector3.new(8074.21, 333.25, 573.51), action = "walk"},
	{pos = Vector3.new(8081.18, 335.90, 590.66), action = "walk"},
	{pos = Vector3.new(8082.63, 337.53, 610.92), action = "walk"},
	{pos = Vector3.new(8082.93, 338.87, 631.30), action = "walk"},
	{pos = Vector3.new(8087.90, 339.60, 650.37), action = "walk"},
	{pos = Vector3.new(8094.35, 340.29, 669.19), action = "walk"},
	{pos = Vector3.new(8095.99, 340.85, 689.39), action = "walk"},
	{pos = Vector3.new(8097.51, 341.42, 709.31), action = "walk"},
	{pos = Vector3.new(8106.04, 342.43, 727.26), action = "walk"},
	{pos = Vector3.new(8121.72, 344.08, 740.23), action = "walk"},
	{pos = Vector3.new(8136.84, 345.90, 753.80), action = "walk"},
	{pos = Vector3.new(8151.37, 347.95, 767.95), action = "walk"},
	{pos = Vector3.new(8164.96, 350.85, 782.89), action = "walk"},
	{pos = Vector3.new(8166.33, 351.16, 784.43), action = "drink_spot"},
	{pos = Vector3.new(8178.21, 353.95, 798.09), action = "walk"},
	{pos = Vector3.new(8188.51, 357.86, 814.71), action = "walk"},
	{pos = Vector3.new(8197.56, 361.71, 832.64), action = "walk"},
	{pos = Vector3.new(8205.70, 364.90, 850.60), action = "walk"},
	{pos = Vector3.new(8208.75, 368.26, 870.49), action = "walk"},
	{pos = Vector3.new(8209.90, 371.62, 890.58), action = "walk"},
	{pos = Vector3.new(8209.18, 374.99, 910.71), action = "walk"},
	{pos = Vector3.new(8208.51, 378.35, 930.84), action = "walk"},
	{pos = Vector3.new(8211.26, 381.90, 951.06), action = "walk"},
	{pos = Vector3.new(8223.13, 385.25, 967.01), action = "walk"},
	{pos = Vector3.new(8240.28, 388.32, 978.40), action = "walk"},
	{pos = Vector3.new(8258.13, 391.23, 987.85), action = "walk"},
	{pos = Vector3.new(8275.55, 394.15, 997.14), action = "walk"},
	{pos = Vector3.new(8292.50, 400.09, 1007.15), action = "walk"},
	{pos = Vector3.new(8308.08, 409.94, 1016.57), action = "walk"},
	{pos = Vector3.new(8321.85, 421.33, 1026.39), action = "walk"},
	{pos = Vector3.new(8333.56, 432.86, 1034.64), action = "walk"},
	{pos = Vector3.new(8340.23, 447.24, 1041.06), action = "walk"},
	{pos = Vector3.new(8343.97, 460.55, 1050.88), action = "walk"},
	{pos = Vector3.new(8360.53, 471.33, 1057.06), action = "walk"},
	{pos = Vector3.new(8378.25, 480.30, 1054.62), action = "walk"},
	{pos = Vector3.new(8394.14, 487.23, 1044.22), action = "walk"},
	{pos = Vector3.new(8405.28, 493.32, 1027.69), action = "walk"},
	{pos = Vector3.new(8415.80, 499.27, 1011.23), action = "walk"},
	{pos = Vector3.new(8426.27, 505.20, 994.71), action = "walk"},
	{pos = Vector3.new(8435.64, 510.94, 977.51), action = "walk"},
	{pos = Vector3.new(8443.56, 516.81, 959.64), action = "walk"},
	{pos = Vector3.new(8450.29, 522.80, 941.32), action = "walk"},
	{pos = Vector3.new(8454.48, 530.97, 926.09), action = "walk"},
	{pos = Vector3.new(8457.23, 540.42, 912.50), action = "walk"},
	{pos = Vector3.new(8462.59, 547.60, 895.25), action = "walk"},
	{pos = Vector3.new(8469.11, 554.50, 878.84), action = "walk"},
	{pos = Vector3.new(8474.27, 561.52, 864.64), action = "walk"},
	{pos = Vector3.new(8483.22, 563.93, 846.59), action = "walk"},
	{pos = Vector3.new(8492.54, 565.81, 828.51), action = "walk"},
	{pos = Vector3.new(8502.34, 567.43, 810.67), action = "walk"},
	{pos = Vector3.new(8512.50, 568.98, 793.02), action = "walk"},
	{pos = Vector3.new(8522.91, 570.46, 775.52), action = "walk"},
	{pos = Vector3.new(8533.42, 571.88, 758.08), action = "walk"},
	{pos = Vector3.new(8543.73, 573.27, 741.01), action = "walk"},
	{pos = Vector3.new(8554.52, 574.63, 723.73), action = "walk"},
	{pos = Vector3.new(8565.48, 575.96, 706.55), action = "walk"},
	{pos = Vector3.new(8576.31, 577.21, 689.79), action = "walk"},
	{pos = Vector3.new(8587.58, 578.51, 672.33), action = "walk"},
	{pos = Vector3.new(8598.86, 579.82, 654.86), action = "walk"},
	{pos = Vector3.new(8609.92, 581.09, 637.75), action = "walk"},
	{pos = Vector3.new(8620.75, 582.34, 620.99), action = "walk"},
	{pos = Vector3.new(8631.80, 583.62, 603.87), action = "walk"},
	{pos = Vector3.new(8642.63, 584.87, 587.11), action = "walk"},
	{pos = Vector3.new(8653.68, 586.15, 570.00), action = "walk"},
	{pos = Vector3.new(8664.90, 587.33, 553.47), action = "walk"},
	{pos = Vector3.new(8676.91, 588.50, 536.49), action = "walk"},
	{pos = Vector3.new(8688.78, 589.64, 519.91), action = "walk"},
	{pos = Vector3.new(8700.65, 590.78, 503.34), action = "walk"},
	{pos = Vector3.new(8712.27, 591.90, 487.10), action = "walk"},
	{pos = Vector3.new(8724.38, 593.06, 470.19), action = "walk"},
	{pos = Vector3.new(8736.25, 594.20, 453.61), action = "walk"},
	{pos = Vector3.new(8748.17, 595.24, 437.06), action = "walk"},
	{pos = Vector3.new(8759.90, 595.98, 420.88), action = "walk"},
	{pos = Vector3.new(8771.61, 596.68, 404.69), action = "walk"},
	{pos = Vector3.new(8783.59, 597.22, 388.16), action = "walk"},
	{pos = Vector3.new(8795.79, 597.53, 371.29), action = "walk"},
	{pos = Vector3.new(8807.76, 597.83, 354.76), action = "walk"},
	{pos = Vector3.new(8819.72, 598.12, 338.23), action = "walk"},
	{pos = Vector3.new(8831.44, 598.42, 322.04), action = "walk"},
	{pos = Vector3.new(8843.40, 598.72, 305.51), action = "walk"},
	{pos = Vector3.new(8855.35, 599.00, 288.97), action = "walk"},
	{pos = Vector3.new(8866.89, 599.20, 272.65), action = "walk"},
	{pos = Vector3.new(8869.77, 599.25, 268.56), action = "drink_spot"},
	{pos = Vector3.new(8878.90, 599.41, 255.64), action = "walk"},
	{pos = Vector3.new(8890.67, 599.62, 238.97), action = "walk"},
	{pos = Vector3.new(8902.49, 599.78, 221.81), action = "walk"},
	{pos = Vector3.new(8913.46, 599.88, 205.08), action = "walk"},
	{pos = Vector3.new(8924.24, 599.85, 187.75), action = "walk"},
	{pos = Vector3.new(8935.21, 599.82, 170.04), action = "walk"},
	{pos = Vector3.new(8945.90, 599.74, 152.64), action = "walk"},
	{pos = Vector3.new(8957.32, 599.59, 135.72), action = "walk"},
	{pos = Vector3.new(8969.45, 599.18, 120.90), action = "walk"},
	{pos = Vector3.new(8973.34, 599.03, 117.14), action = "wait", wait = 142},
	{pos = Vector3.new(8983.41, 598.77, 109.06), action = "walk"},
	{pos = Vector3.new(8989.88, 598.59, 103.81), action = "drink_spot"},
	{pos = Vector3.new(8989.88, 598.59, 103.81), action = "wait", wait = 1.2},
	{pos = Vector3.new(9014.42, 598.86, 92.46), action = "walk"},
	{pos = Vector3.new(9019.33, 598.92, 90.18), action = "drink_spot"},
	{pos = Vector3.new(9033.32, 599.07, 83.71), action = "walk"},
	{pos = Vector3.new(9052.19, 599.28, 75.94), action = "walk"},
	{pos = Vector3.new(9052.19, 599.28, 75.94), action = "drink_spot"},
	{pos = Vector3.new(9071.18, 599.49, 68.49), action = "walk"},
	{pos = Vector3.new(9091.33, 599.51, 61.72), action = "walk"},
	{pos = Vector3.new(9111.90, 599.29, 56.35), action = "walk"},
	{pos = Vector3.new(9131.66, 599.08, 51.20), action = "walk"},
	{pos = Vector3.new(9151.02, 598.87, 46.15), action = "walk"},
	{pos = Vector3.new(9171.19, 598.65, 40.89), action = "walk"},
	{pos = Vector3.new(9190.95, 598.44, 35.74), action = "walk"},
	{pos = Vector3.new(9210.31, 598.23, 30.69), action = "walk"},
	{pos = Vector3.new(9230.49, 597.95, 25.43), action = "walk"},
	{pos = Vector3.new(9250.23, 597.36, 20.21), action = "walk"},
	{pos = Vector3.new(9269.97, 596.66, 15.00), action = "walk"},
	{pos = Vector3.new(9289.54, 596.02, 10.99), action = "walk"},
	{pos = Vector3.new(9310.10, 595.43, 7.79), action = "walk"},
	{pos = Vector3.new(9330.31, 594.77, 4.90), action = "walk"},
	{pos = Vector3.new(9350.70, 593.88, 6.83), action = "walk"},
	{pos = Vector3.new(9365.27, 594.28, 20.91), action = "walk"},
	{pos = Vector3.new(9380.17, 595.55, 34.69), action = "walk"},
	{pos = Vector3.new(9396.83, 597.05, 46.40), action = "walk"},
	{pos = Vector3.new(9414.72, 598.20, 56.20), action = "walk"},
	{pos = Vector3.new(9445.73, 599.05, 67.17), action = "walk"},
	{pos = Vector3.new(9466.88, 599.29, 71.18), action = "walk"},
	{pos = Vector3.new(9487.17, 599.41, 69.00), action = "walk"},
	{pos = Vector3.new(9505.53, 599.35, 61.83), action = "walk"},
	{pos = Vector3.new(9522.67, 599.27, 50.76), action = "walk"},
	{pos = Vector3.new(9538.94, 599.20, 38.43), action = "walk"},
	{pos = Vector3.new(9555.64, 599.20, 26.72), action = "walk"},
	{pos = Vector3.new(9574.41, 599.31, 17.76), action = "walk"},
	{pos = Vector3.new(9601.14, 600.36, 14.64), action = "walk"},
	{pos = Vector3.new(9621.11, 600.33, 15.74), action = "walk"},
	{pos = Vector3.new(9641.80, 600.23, 18.06), action = "walk"},
	{pos = Vector3.new(9662.06, 600.02, 20.51), action = "walk"},
	{pos = Vector3.new(9681.94, 599.77, 22.58), action = "walk"},
	{pos = Vector3.new(9702.64, 599.50, 24.68), action = "walk"},
	{pos = Vector3.new(9722.97, 599.24, 26.64), action = "walk"},
	{pos = Vector3.new(9743.31, 598.98, 28.54), action = "walk"},
	{pos = Vector3.new(9764.12, 598.50, 29.27), action = "walk"},
	{pos = Vector3.new(9784.09, 598.01, 29.86), action = "walk"},
	{pos = Vector3.new(9804.90, 597.41, 30.13), action = "walk"},
	{pos = Vector3.new(9825.29, 596.52, 29.49), action = "walk"},
	{pos = Vector3.new(9845.68, 595.57, 28.62), action = "walk"},
	{pos = Vector3.new(9865.49, 594.55, 26.18), action = "walk"},
	{pos = Vector3.new(9885.85, 593.66, 21.99), action = "walk"},
	{pos = Vector3.new(9905.23, 593.07, 15.64), action = "walk"},
	{pos = Vector3.new(9924.04, 592.74, 5.91), action = "walk"},
	{pos = Vector3.new(9941.63, 592.80, -5.23), action = "walk"},
	{pos = Vector3.new(9960.27, 593.01, -16.27), action = "walk"},
	{pos = Vector3.new(9979.37, 593.36, -23.20), action = "walk"},
	{pos = Vector3.new(9999.57, 593.80, -25.92), action = "walk"},
	{pos = Vector3.new(10019.97, 594.01, -25.03), action = "walk"},
	{pos = Vector3.new(10039.79, 593.28, -22.18), action = "walk"},
	{pos = Vector3.new(10059.95, 592.28, -19.00), action = "walk"},
	{pos = Vector3.new(10080.65, 590.95, -17.00), action = "walk"},
	{pos = Vector3.new(10100.94, 589.58, -15.10), action = "walk"},
	{pos = Vector3.new(10121.58, 588.21, -12.70), action = "walk"},
	{pos = Vector3.new(10141.68, 587.05, -9.37), action = "walk"},
	{pos = Vector3.new(10161.78, 585.90, -6.00), action = "walk"},
	{pos = Vector3.new(10181.47, 584.78, -2.69), action = "walk"},
	{pos = Vector3.new(10201.97, 583.61, 0.75), action = "walk"},
	{pos = Vector3.new(10222.07, 582.47, 4.12), action = "walk"},
	{pos = Vector3.new(10242.58, 581.30, 7.56), action = "walk"},
	{pos = Vector3.new(10262.26, 580.38, 10.86), action = "walk"},
	{pos = Vector3.new(10281.99, 579.72, 14.17), action = "walk"},
	{pos = Vector3.new(10302.13, 579.11, 17.54), action = "walk"},
	{pos = Vector3.new(10322.28, 578.61, 20.92), action = "walk"},
	{pos = Vector3.new(10342.01, 578.13, 24.22), action = "walk"},
	{pos = Vector3.new(10362.57, 577.63, 27.67), action = "walk"},
	{pos = Vector3.new(10382.71, 577.13, 31.04), action = "walk"},
	{pos = Vector3.new(10402.86, 576.64, 34.42), action = "walk"},
	{pos = Vector3.new(10423.00, 576.15, 37.80), action = "walk"},
	{pos = Vector3.new(10442.74, 575.66, 41.10), action = "walk"},
	{pos = Vector3.new(10462.88, 575.17, 44.48), action = "walk"},
	{pos = Vector3.new(10483.03, 574.68, 47.85), action = "walk"},
	{pos = Vector3.new(10502.80, 574.18, 50.92), action = "walk"},
	{pos = Vector3.new(10523.50, 573.63, 53.39), action = "walk"},
	{pos = Vector3.new(10543.79, 573.09, 55.80), action = "walk"},
	{pos = Vector3.new(10563.67, 572.56, 58.17), action = "walk"},
	{pos = Vector3.new(10583.96, 572.02, 60.58), action = "walk"},
	{pos = Vector3.new(10604.26, 571.12, 62.81), action = "walk"},
	{pos = Vector3.new(10624.14, 570.13, 64.94), action = "walk"},
	{pos = Vector3.new(10644.43, 569.13, 67.11), action = "walk"},
	{pos = Vector3.new(10664.30, 568.14, 69.24), action = "walk"},
	{pos = Vector3.new(10685.01, 567.12, 71.46), action = "walk"},
	{pos = Vector3.new(10704.88, 566.13, 73.59), action = "walk"},
	{pos = Vector3.new(10725.16, 565.12, 75.79), action = "walk"},
	{pos = Vector3.new(10745.40, 564.06, 78.09), action = "walk"},
	{pos = Vector3.new(10766.06, 562.99, 80.47), action = "walk"},
	{pos = Vector3.new(10785.83, 562.04, 83.29), action = "walk"},
	{pos = Vector3.new(10806.39, 561.11, 86.49), action = "walk"},
	{pos = Vector3.new(10826.12, 560.22, 89.56), action = "walk"},
	{pos = Vector3.new(10846.27, 559.30, 92.69), action = "walk"},
	{pos = Vector3.new(10866.00, 558.41, 95.76), action = "walk"},
	{pos = Vector3.new(10886.15, 557.50, 98.90), action = "walk"},
	{pos = Vector3.new(10906.29, 556.59, 102.03), action = "walk"},
	{pos = Vector3.new(10928.08, 555.60, 105.42), action = "walk"},
	{pos = Vector3.new(10933.43, 555.36, 106.26), action = "wait", wait = 100},
	{pos = Vector3.new(10948.23, 554.69, 108.56), action = "walk"},
	{pos = Vector3.new(10963.85, 553.98, 110.99), action = "walk"},
	{pos = Vector3.new(10972.90, 553.57, 112.40), action = "walk"},
	{pos = Vector3.new(10976.19, 553.42, 112.91), action = "wait", wait = 2.2},
	{pos = Vector3.new(10968.99, 554.81, 109.73), action = "walk"},
	{pos = Vector3.new(10971.63, 550.36, 96.13), action = "walk"},
	{pos = Vector3.new(10985.71, 547.00, 97.34), action = "walk"},
	{pos = Vector3.new(10988.40, 547.34, 98.17), action = "wait", wait = 4.7},
}

-- ================= SERVICES / STATE =================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local running = false
local runId = 0
local flyPaused = false
local hydrationLabel = nil
local skippedCount = 0
local loopCount = 0
local flyVel, flyGyro = nil, nil
local flyMethod = "BV" -- "BV" dulu; watchdog bisa mengganti ke "CFRAME"
local noclipConn = nil
local currentTarget = nil -- posisi ditahan saat hover/pause
local timerStartClock = nil -- timer GUI, dihitung sejak START ditekan
local timerThreadOn = false

-- ================= GUI =================
local old = playerGui:FindFirstChild("AntarcticaFlyReplayGUI")
if old then
    local s = old:FindFirstChild("StopSignal")
    if s then s:Fire() end
    old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "AntarcticaFlyReplayGUI"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local stopSignal = Instance.new("BindableEvent")
stopSignal.Name = "StopSignal"
stopSignal.Parent = gui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 334)
frame.Position = UDim2.new(1, -315, 0, 90)
frame.BackgroundColor3 = Color3.fromRGB(22, 29, 43)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

local function createLabel(text, y, height, size)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, height)
    label.Position = UDim2.new(0, 10, 0, y)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextSize = size
    label.Font = Enum.Font.GothamBold
    label.Parent = frame
    return label
end

local title = createLabel("FLY REPLAY + HYDRATION + LOOP AIR v10", 10, 26, 12)
title.TextColor3 = Color3.fromRGB(0, 200, 255)
local timerLabel = createLabel("00:00", 40, 35, 24)
local progressLabel = createLabel("Waypoint: - / " .. #ROUTE, 80, 25, 14)
local distLabel = createLabel("Ke finish: -", 105, 25, 14)
local waterLabel = createLabel("Hydration: Detecting...", 130, 25, 14)
local status = createLabel("Status: Ready", 160, 25, 12)

local function createButton(text, x, color)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 130, 0, 40)
    button.Position = UDim2.new(0, x, 0, 215)
    button.BackgroundColor3 = color
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = text
    button.Font = Enum.Font.GothamBold
    button.TextSize = 15
    button.Parent = frame
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
    return button
end

local startButton = createButton("START", 10, Color3.fromRGB(30, 170, 85))
local stopButton = createButton("STOP", 160, Color3.fromRGB(200, 55, 55))

-- Tulisan paling bawah panel (permintaan Muhammad)
local footer = createLabel("AUTO SUMMIT BILLY", 262, 22, 13)
footer.TextXAlignment = Enum.TextXAlignment.Center
footer.TextColor3 = Color3.fromRGB(255, 200, 40)

-- ================= KONTROL GUI v10 =================
-- Tombol keybind (di bawah footer)
local guiKeybind = Enum.KeyCode.RightShift
local capturingBind = false
local bindButton = Instance.new("TextButton")
bindButton.Size = UDim2.new(0, 280, 0, 30)
bindButton.Position = UDim2.new(0, 10, 0, 292)
bindButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
bindButton.TextColor3 = Color3.new(1, 1, 1)
bindButton.Font = Enum.Font.GothamBold
bindButton.TextSize = 12
bindButton.Parent = frame
Instance.new("UICorner", bindButton).CornerRadius = UDim.new(0, 8)
local function refreshBindButton()
    if capturingBind then
        bindButton.Text = "Tekan tombol barunya... (Esc = batal)"
        bindButton.BackgroundColor3 = Color3.fromRGB(200, 150, 30)
    else
        bindButton.Text = "Keybind Panel: " .. guiKeybind.Name .. " (klik buat ganti)"
        bindButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
    end
end
refreshBindButton()
bindButton.MouseButton1Click:Connect(function()
    capturingBind = true
    refreshBindButton()
end)

-- Tombol minimize & tutup di pojok kanan atas frame
local function createCornerButton(text, x, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 28, 0, 28)
    b.Position = UDim2.new(0, x, 0, 6)
    b.BackgroundColor3 = color
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    return b
end
local minimizeButton = createCornerButton("-", 232, Color3.fromRGB(70, 70, 80))
local closeButton = createCornerButton("X", 264, Color3.fromRGB(200, 55, 55))

-- Semua isi panel yang disembunyikan pas minimize
local contentParts = { title, timerLabel, progressLabel, distLabel, waterLabel, status, startButton, stopButton, footer, bindButton }
local minimized = false
local dragMoved = false -- true sesaat habis drag, biar klik + / X tidak ikut kepencet
local function setMinimized(min)
    minimized = min
    for _, obj in ipairs(contentParts) do obj.Visible = not min end
    if min then
        frame.Size = UDim2.new(0, 76, 0, 44)
        minimizeButton.Position = UDim2.new(0, 6, 0, 8)
        closeButton.Position = UDim2.new(0, 42, 0, 8)
    else
        frame.Size = UDim2.new(0, 300, 0, 334)
        minimizeButton.Position = UDim2.new(0, 232, 0, 6)
        closeButton.Position = UDim2.new(0, 264, 0, 6)
    end
    minimizeButton.Text = min and "+" or "-"
end
minimizeButton.MouseButton1Click:Connect(function()
    if dragMoved then dragMoved = false return end
    setMinimized(not minimized)
end)
closeButton.MouseButton1Click:Connect(function()
    if dragMoved then dragMoved = false return end
    stopSignal:Fire() -- jalur matikan bawaan script ini (sama kayak digantikan execute baru)
    gui:Destroy()
    print("[FLY REPLAY] Panel ditutup & otomatisasi dihentikan. Execute ulang buat buka lagi.")
end)

-- Keybind sembunyi/tampil panel (+ picker). Koneksi service ini
-- diputus lewat StopSignal pas salinan baru menggantikan panel ini.
local keybindConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gui.Parent then return end
    if capturingBind then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Escape then
                capturingBind = false
            elseif input.KeyCode ~= Enum.KeyCode.Unknown then
                guiKeybind = input.KeyCode
                capturingBind = false
                print("[FLY REPLAY] Keybind panel diganti jadi: " .. guiKeybind.Name)
            end
            refreshBindButton()
        end
        return
    end
    if gameProcessed then return end
    if input.KeyCode == guiKeybind then
        gui.Enabled = not gui.Enabled
    end
end)
stopSignal.Event:Connect(function()
    if keybindConn then keybindConn:Disconnect() keybindConn = nil end
end)

-- Drag panel (dari judul; pas minimize dari kotak / tombolnya)
local dragging = false
local dragStart, frameStart
local function beginDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragMoved = false
        dragStart = input.Position
        frameStart = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if dragMoved then
                    task.delay(0.1, function() dragMoved = false end)
                end
            end
        end)
    end
end
local function moveDrag(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        if delta.Magnitude > 6 then dragMoved = true end
        frame.Position = UDim2.new(
            frameStart.X.Scale, frameStart.X.Offset + delta.X,
            frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
    end
end
title.InputBegan:Connect(beginDrag)
title.InputChanged:Connect(moveDrag)
frame.InputBegan:Connect(function(input)
    if minimized then beginDrag(input) end
end)
frame.InputChanged:Connect(function(input)
    if minimized then moveDrag(input) end
end)
minimizeButton.InputBegan:Connect(beginDrag)
minimizeButton.InputChanged:Connect(moveDrag)
closeButton.InputBegan:Connect(beginDrag)
closeButton.InputChanged:Connect(moveDrag)

local function validRun(id, humanoid)
    return running and id == runId and humanoid and humanoid.Health > 0
end

-- ================= FLY ENGINE =================
local function startFly(character, humanoid, root)
    stopFlyCleanupOnly(character, humanoid)
    flyVel = Instance.new("BodyVelocity")
    flyVel.Name = "FlyReplayVelocity"
    flyVel.MaxForce = Vector3.new(9e5, 9e5, 9e5)
    flyVel.P = 9e4
    flyVel.Velocity = Vector3.zero
    flyVel.Parent = root
    flyGyro = Instance.new("BodyGyro")
    flyGyro.Name = "FlyReplayGyro"
    flyGyro.MaxTorque = Vector3.new(9e5, 9e5, 9e5)
    flyGyro.P = 9e4
    flyGyro.CFrame = root.CFrame
    flyGyro.Parent = root
    humanoid.PlatformStand = true
    if NOCLIP and not noclipConn then
        noclipConn = RunService.Stepped:Connect(function()
            local char = player.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
    end
end

function stopFlyCleanupOnly(character, humanoid)
    local char = character or player.Character
    if char then
        local r = char:FindFirstChild("HumanoidRootPart")
        if r then
            r.Anchored = false
            local v = r:FindFirstChild("FlyReplayVelocity")
            if v then v:Destroy() end
            local g = r:FindFirstChild("FlyReplayGyro")
            if g then g:Destroy() end
        end
    end
    flyVel, flyGyro = nil, nil
end

local function stopFly(character, humanoid)
    stopFlyCleanupOnly(character, humanoid)
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    local char = character or player.Character
    if char then
        local hum = humanoid or char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end

-- Arahkan fly engine: targetPos = nil berarti hover di tempat
local function setFlyTarget(root, targetPos)
    currentTarget = targetPos
    if not flyVel or not flyGyro then return end
    if not targetPos then
        flyVel.Velocity = Vector3.zero
        return
    end
    local delta = targetPos - root.Position
    local dist = delta.Magnitude
    if dist < 0.5 then
        flyVel.Velocity = Vector3.zero
        return
    end
    flyVel.Velocity = delta.Unit * FLY_SPEED
    local flat = Vector3.new(delta.X, 0, delta.Z)
    if flat.Magnitude > 1 then
        flyGyro.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
    end
end

-- ================= HYDRATION =================
-- =========================
-- HYDRATION DETECTION (versi Muhammad)
-- =========================

local function parsePercent(text)
    if type(text) ~= "string" then return nil end

    local value = text:match(
        "^%s*(%d+%.?%d*)%s*%%%s*$"
    )

    return value and tonumber(value) or nil
end

local function getHydration()

    if hydrationLabel
        and hydrationLabel:IsDescendantOf(playerGui) then

        local value = parsePercent(hydrationLabel.Text)

        if value then
            return value
        end
    end

    hydrationLabel = nil

    local candidates = {}

    for _, obj in ipairs(playerGui:GetDescendants()) do

        if (obj:IsA("TextLabel")
            or obj:IsA("TextButton"))
            and not obj:IsDescendantOf(gui) then

            local value = parsePercent(obj.Text)

            if value and value >= 0 and value <= 150 then

                local score = value > 100 and 50 or 0
                local ancestor = obj

                for i = 1, 5 do
                    if not ancestor then break end

                    local name = ancestor.Name:lower()

                    if name:find("water")
                        or name:find("hydrat")
                        or name:find("thirst") then

                        score += 100
                    end

                    ancestor = ancestor.Parent
                end

                table.insert(candidates, {
                    label = obj,
                    score = score,
                    value = value
                })
            end
        end
    end

    table.sort(candidates, function(a, b)
        return a.score > b.score
    end)

    if #candidates == 0 then return nil end

    if #candidates > 1
        and candidates[1].score == candidates[2].score then

        return nil
    end

    hydrationLabel = candidates[1].label

    print("[HYDRATION GUI]",
        hydrationLabel:GetFullName())

    return candidates[1].value
end

-- =========================
-- FIND WATER BOTTLE (versi Muhammad, diperbaiki)
-- Dulu: pencocokan longgar "bottle" ikut menangkap
-- "Health Bottle" - botol yang salah yang diminum.
-- Sekarang: prioritas nama PERSIS "Water Bottle"; cadangan
-- hanya item lain yang namanya mengandung "water".
-- "Health Bottle" tidak akan pernah terpilih lagi.
-- =========================

local function findBottle()

    local character = player.Character
    local backpack = player:FindFirstChild("Backpack")
    local fallback = nil

    for _, parent in ipairs({character, backpack}) do

        if parent then

            for _, item in ipairs(parent:GetChildren()) do

                if item:IsA("Tool") then

                    local name = item.Name:lower()

                    if name == "water bottle" then

                        return item -- prioritas tertinggi: nama persis

                    elseif name:find("water") and not fallback then

                        fallback = item
                    end
                end
            end
        end
    end

    return fallback
end

-- =========================
-- PILIH WATER BOTTLE DARI SLOT HOTBAR (permintaan Muhammad:
-- di hotbar-nya Water Bottle SELALU otomatis di slot 2,
-- Health Bottle di slot 6 - jadi ambil langsung slot 2).
-- Urutan cek:
--   1) Water Bottle yang sedang ter-equip (di karakter)
--   2) Tool di slot WATER_SLOT Backpack, diverifikasi namanya
--      mengandung "water" supaya tidak salah ambil
--   3) Cadangan: pencarian nama persis "Water Bottle"
-- =========================

local WATER_SLOT = 2

local function pickWaterBottle()

    local character = player.Character

    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool")
                and item.Name:lower() == "water bottle" then
                return item
            end
        end
    end

    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        local tools = {}
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(tools, item)
            end
        end
        local slotTool = tools[WATER_SLOT]
        if slotTool
            and slotTool.Name:lower():find("water") then
            return slotTool
        end
    end

    return findBottle()
end

-- =========================
-- AUTO DRINK (versi Muhammad)
-- Jumlah klik & delay mengikuti CONFIG file ini
-- (DRINK_CLICKS / CLICK_DELAY di atas).
-- =========================

local function drinkWater(character, humanoid, id)

    local bottle = pickWaterBottle()

    if not bottle then
        status.Text = "Water Bottle not found!"
        warn("[WATER] Bottle not found")
        return
    end

    humanoid:EquipTool(bottle)

    task.wait(0.5)

    for i = 1, DRINK_CLICKS do

        if not running
            or id ~= runId
            or humanoid.Health <= 0 then

            return
        end

        if bottle.Parent ~= character then

            status.Text = "Bottle not equipped"
            return
        end

        bottle:Activate()

        status.Text = "Drinking: " .. i .. "/" .. DRINK_CLICKS

        print("[AUTO DRINK]", i, "/" .. DRINK_CLICKS)

        task.wait(CLICK_DELAY)
    end

    if running and id == runId then

        status.Text = "Drinking completed"

        print("[WATER]", DRINK_CLICKS, "activations completed")
    end
end

-- ================= TERBANG KE WAYPOINT =================
local function nearestRouteIndex(rootPos)
    local best, bestDist = 1, math.huge
    for i, wp in ipairs(ROUTE) do
        local d = (rootPos - wp.pos).Magnitude
        if d < bestDist then bestDist, best = d, i end
    end
    return best, bestDist
end

local function flyToWaypoint(root, wp, id, humanoid)
    local dist0 = (root.Position - wp.pos).Magnitude
    local deadline = os.clock() + dist0 / FLY_SPEED * 4 + 5
    local startPos = root.Position
    local startTime = os.clock()
    local watchdogDone = false
    while validRun(id, humanoid) do
        while flyPaused and validRun(id, humanoid) do
            setFlyTarget(root, nil)
            task.wait(0.2)
            deadline += 0.2
        end
        local d = (root.Position - wp.pos).Magnitude
        distLabel.Text = string.format("Ke finish: %d stud",
            math.floor((root.Position - ROUTE[#ROUTE].pos).Magnitude))
        if d <= REACH_DIST then
            setFlyTarget(root, nil)
            return true
        end
        if os.clock() > deadline then
            setFlyTarget(root, nil)
            return false
        end
        -- Watchdog: BodyVelocity tidak menggerakkan karakter sama sekali
        -- dalam 2.5 detik pertama -> game menolak metode BV, beralih
        -- permanen ke CFrame fly (bergerak per-frame, tanpa fisika).
        if not watchdogDone and os.clock() - startTime > 2.5 then
            watchdogDone = true
            if flyMethod == "BV" and (root.Position - startPos).Magnitude < 3 then
                flyMethod = "CFRAME"
                local v = root:FindFirstChild("FlyReplayVelocity")
                if v then v:Destroy() end
                local g = root:FindFirstChild("FlyReplayGyro")
                if g then g:Destroy() end
                flyVel, flyGyro = nil, nil
                warn("[FLY REPLAY] BodyVelocity macet - beralih ke CFrame fly")
                status.Text = "Fly BV macet - ganti CFrame fly"
            end
        end
        setFlyTarget(root, wp.pos)
        if flyMethod == "CFRAME" then
            local delta = wp.pos - root.Position
            if delta.Magnitude > 0.5 then
                local step = math.min(FLY_SPEED * 0.1, delta.Magnitude)
                local newPos = root.Position + delta.Unit * step
                local flat = Vector3.new(delta.X, 0, delta.Z)
                if flat.Magnitude > 1 then
                    root.CFrame = CFrame.lookAt(newPos, newPos + flat)
                else
                    root.CFrame = CFrame.new(newPos) * (root.CFrame - root.CFrame.Position)
                end
                root.AssemblyLinearVelocity = Vector3.zero
            end
        end
        task.wait(0.1)
    end
    setFlyTarget(root, nil)
    return false
end

-- ================= MAIN =================
local function beginRun(character)
    runId += 1
    local id = runId
    hydrationLabel = nil
    if not timerStartClock then timerStartClock = os.clock() end
    task.spawn(function()
        local humanoid = character:WaitForChild("Humanoid")
        local root = character:WaitForChild("HumanoidRootPart")
        if not validRun(id, humanoid) then return end

        startFly(character, humanoid, root)
        task.wait(0.3)

        local startIdx, nearDist = nearestRouteIndex(root.Position)
        status.Text = string.format("Resume waypoint %d (jarak %d)", startIdx, math.floor(nearDist))
        print("[FLY REPLAY] Resume index", startIdx, "dist", math.floor(nearDist))
        task.wait(1)

        -- =========================
        -- HYDRATION MONITOR (versi Muhammad)
        -- =========================

        local lastDrink = -math.huge

        task.spawn(function()

            while validRun(id, humanoid) do

                local hydration = getHydration()

                if hydration ~= nil then

                    waterLabel.Text =
                        "Hydration: " .. hydration .. "%"

                    if hydration <= DRINK_AT
                        and os.clock() - lastDrink
                        >= DRINK_COOLDOWN then

                        lastDrink = os.clock()

                        print("[WATER] Threshold reached:",
                            hydration)

                        drinkWater(character, humanoid, id)
                    end

                else

                    waterLabel.Text =
                        "Hydration: Not detected"

                end

                task.wait(CHECK_INTERVAL)
            end
        end)

        for i = startIdx, #ROUTE do
            if not validRun(id, humanoid) then break end
            local wp = ROUTE[i]
            progressLabel.Text = string.format("Waypoint: %d / %d", i, #ROUTE)
            distLabel.Text = string.format("Ke finish: %d stud",
                math.floor((root.Position - ROUTE[#ROUTE].pos).Magnitude))

            if wp.action == "wait" then
                local w = math.min(wp.wait or 0, MAX_WAIT)
                if w >= 1 then
                    flyToWaypoint(root, wp, id, humanoid) -- persis ke titik checkpoint dulu
                    setFlyTarget(root, nil)
                    if flyMethod == "CFRAME" then root.Anchored = true end -- CFrame fly: tahan posisi jeda pakai anchor
                    local t0 = os.clock()
                    -- Minum HANYA di jeda checkpoint panjang (>=45 detik),
                    -- dan waktu minumnya dihitung sebagai BAGIAN dari jeda:
                    -- total diam di checkpoint tetap persis durasi rekaman,
                    -- jadi timer ekspedisi tidak terganggu.
                    if w >= 45 then
                        local hydration = getHydration()
                        if hydration and hydration <= DRINK_AT then
                            status.Text = "Minum di checkpoint (di dalam jeda)..."
                            drinkWater(character, humanoid, id)
                            setFlyTarget(root, nil)
                        end
                    end
                    if os.clock() - t0 < w then
                        status.Text = string.format("Hover jeda: %ds (asli %ds)", w, math.floor(wp.wait))
                        while validRun(id, humanoid) and os.clock() - t0 < w do
                            setFlyTarget(root, root.Position) -- tahan posisi
                            task.wait(0.3)
                        end
                    end
                    if flyMethod == "CFRAME" then root.Anchored = false end
                end
            elseif wp.action == "drink_spot" then
                -- Titik minum di rekaman sekarang hanya waypoint biasa:
                -- minum tidak menghentikan terbang lagi (aturannya:
                -- minum hanya saat diam di jeda checkpoint).
                flyToWaypoint(root, wp, id, humanoid)
            else -- walk / start / segment_start / marker / state / jump (semua diterbangi)
                status.Text = "Terbang ke waypoint " .. i .. "..."
                local ok = flyToWaypoint(root, wp, id, humanoid)
                if not ok and validRun(id, humanoid) then
                    skippedCount += 1
                    warn("[FLY REPLAY] Waypoint dilewati:", i, "total skip:", skippedCount)
                    status.Text = "Waypoint " .. i .. " dilewati (" .. skippedCount .. ")"
                end
            end
        end

        if validRun(id, humanoid) then
            loopCount += 1
            status.Text = string.format("SAMPAI DI SOUTH POLE! Run #%d selesai", loopCount)
            progressLabel.Text = "Waypoint: SELESAI (Loop " .. loopCount .. ")"
            distLabel.Text = "Ke finish: 0"
            setFlyTarget(root, nil)
            print("[FLY REPLAY] SELESAI run #", loopCount, "| Waypoint dilewati:", skippedCount)
            if LOOP_MODE then
                status.Text = string.format("Run #%d selesai - tunggu %ds biar kehitung, lalu respawn...", loopCount, LOOP_FINISH_WAIT)
                task.wait(LOOP_FINISH_WAIT)
                stopFly(character, humanoid)
                if LOOP_METHOD == "teleport" then
                    status.Text = "Teleport ke air - mati, respawn Base Camp..."
                    local r2 = character:FindFirstChild("HumanoidRootPart")
                    if r2 then
                        r2.CFrame = CFrame.new(AFTER_SUMMIT_POS)
                        r2.AssemblyLinearVelocity = Vector3.zero
                    end
                    print("[FLY REPLAY] Teleport ke air setelah summit ->", AFTER_SUMMIT_POS)
                    timerStartClock = nil -- timer ekspedisi baru dari 00:00
                    -- Karakter mati kena air -> respawn di Base Camp ->
                    -- CharacterAdded otomatis start lagi (running masih true).
                    -- Cadangan: kalau 8 detik belum mati juga, matikan manual.
                    task.spawn(function()
                        local t0 = os.clock()
                        while os.clock() - t0 < 8 do
                            if not humanoid or humanoid.Health <= 0 then return end
                            task.wait(0.5)
                        end
                        pcall(function()
                            if humanoid then humanoid.Health = 0 end
                        end)
                    end)
                elseif LOOP_METHOD == "rejoin" then
                    status.Text = "Rejoin server untuk loop berikutnya..."
                    local ok, err = pcall(function()
                        if type(queue_on_teleport) == "function" then
                            queue_on_teleport('loadstring(readfile("antarctica-fly-replay-southpole.lua"))()')
                        end
                        game:GetService("TeleportService"):Teleport(game.PlaceId, player)
                    end)
                    if not ok then
                        warn("[FLY REPLAY] Rejoin gagal:", err)
                        running = false
                        startButton.Text = "START"
                    end
                else -- reset: mati -> respawn -> CharacterAdded auto-start (running masih true)
                    status.Text = "Respawn untuk loop berikutnya..."
                    timerStartClock = nil -- ekspedisi baru: timer dari 00:00 lagi
                    humanoid.Health = 0
                end
            else
                task.wait(2)
                stopFly(character, humanoid) -- turun di South Pole
                running = false
                startButton.Text = "START"
            end
        end
    end)
end

local function startAutomation()
    if running then return end
    running = true
    flyPaused = false
    skippedCount = 0
    timerStartClock = os.clock()
    timerLabel.Text = "00:00"
    if not timerThreadOn then
        timerThreadOn = true
        task.spawn(function()
            while gui.Parent do
                if running and timerStartClock then
                    local e = os.clock() - timerStartClock
                    timerLabel.Text = string.format("%02d:%02d", math.floor(e / 60), math.floor(e % 60))
                end
                task.wait(0.25)
            end
            timerThreadOn = false
        end)
    end
    startButton.Text = "RUNNING"
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 then
            beginRun(character)
        else
            status.Text = "Waiting for respawn"
        end
    else
        status.Text = "Waiting for character"
    end
end
startButton.MouseButton1Click:Connect(startAutomation)

local function stopAutomation()
    local character = player.Character
    running = false
    flyPaused = false
    runId += 1
    startButton.Text = "START"
    status.Text = "Status: Stopped"
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        stopFly(character, humanoid)
    end
    print("[FLY REPLAY] Stopped")
end
stopButton.MouseButton1Click:Connect(stopAutomation)
stopSignal.Event:Connect(function()
    running = false
    runId += 1
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    stopFlyCleanupOnly(nil, nil)
end)

-- ===== PENGAWAS JOIN: temen/koneksi masuk server -> AUTO STOP =====
local function isWatchedJoiner(p)
    if ANY_JOIN_AUTO_STOP then
        return true, "mode siapa pun join"
    end
    for _, name in ipairs(WATCH_NAMES) do
        if string.lower(p.Name) == string.lower(name) then
            return true, "nama dipantau"
        end
    end
    if FRIEND_AUTO_STOP then
        local ok, isFriend = pcall(function()
            return player:IsFriendsWith(p.UserId)
        end)
        if ok and isFriend then
            return true, "teman Roblox"
        end
    end
    return false
end

Players.PlayerAdded:Connect(function(p)
    if p == player then return end
    task.spawn(function()
        local watched, why = isWatchedJoiner(p)
        if watched then
            if running then
                stopAutomation()
                status.Text = "AUTO STOP: " .. p.DisplayName .. " join (" .. why .. ")"
            end
            print("[FLY REPLAY] AUTO STOP - " .. p.Name .. " (" .. p.DisplayName .. ") join server: " .. why)
        end
    end)
end)

-- Yang SUDAH di server pas script jalan: kasih peringatan di console
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= player then
        task.spawn(function()
            local watched, why = isWatchedJoiner(p)
            if watched then
                print("[FLY REPLAY] PERINGATAN: " .. p.Name .. " (" .. why .. ") SUDAH ada di server ini.")
            end
        end)
    end
end

player.CharacterAdded:Connect(function(character)
    if running then
        status.Text = "Respawn - resume terbang"
        beginRun(character)
    end
end)

if AUTO_START_ON_LOAD then
    task.spawn(function()
        task.wait(3)
        print("[FLY REPLAY] AUTO_START_ON_LOAD aktif - mulai sendiri")
        startAutomation()
    end)
end

print("================================")
print(" FLY REPLAY SOUTH POLE v2 READY")
print(" Waypoints:", #ROUTE, "| Speed:", FLY_SPEED)
print(" Press START to begin")
print(" Auto Stop Join: teman=" .. tostring(FRIEND_AUTO_STOP) .. ", pantau " .. #WATCH_NAMES .. " nama, siapa pun=" .. tostring(ANY_JOIN_AUTO_STOP))
print("================================")
