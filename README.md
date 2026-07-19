# BMS — Estimasi SOC Baterai Li-ion (Kelompok 4, SKPA)

Proyek akhir mata kuliah **Sistem Kendali Prediktif & Adaptif**: identifikasi parameter model baterai secara online dan estimasi *State of Charge* (SOC) menggunakan FFRLS, Levenberg–Marquardt, dan Extended Kalman Filter di MATLAB.

## Ringkasan

Baterai dimodelkan sebagai **rangkaian ekivalen Thevenin orde-2 (2-RC)**:

```
        R0        R1              R2
Uoc ---/\/\/--+--/\/\/--+------/\/\/--+---- Ut
              |    |    |        |    |
              +----||---+        +----||---+
                   C1                 C2
```

Alur kerjanya:

1. **Kurva OCV–SOC** diturunkan dari uji OCV lewat *polynomial fitting* (orde 2–12, dipilih RMSE terkecil, terpisah untuk charge & discharge).
2. **FFRLS** (Forgetting Factor Recursive Least Squares, λ = 0.98) mengidentifikasi parameter diskrit θ₁…θ₆ dari data arus/tegangan secara online, lalu diinversi menjadi R0, R1, R2, C1, C2, Uoc.
3. **Levenberg–Marquardt** memperhalus (*refine*) hasil FFRLS tiap titik waktu dengan optimasi nonlinier terhadap θ.
4. **EKF** memakai parameter hasil LM untuk mengestimasi state `[U1; U2; SOC]`, dibandingkan terhadap *Coulomb counting* sebagai referensi.

## Dataset

Data uji baterai **A123 1.1 Ah @ 25 °C** (format CALCE):

| File | Isi | Kolom yang dipakai |
|---|---|---|
| `A1-007-OCV-25-20120905.xlsx` | Uji OCV sel #007 | 1 = waktu, 2 = arus, 3 = tegangan |
| `A1-008-OCV-25-20120905.xlsx` | Uji OCV sel #008 | idem |
| `A1-007-DST-US06-FUDS-25-20120827.xlsx` | Profil dinamis DST/US06/FUDS sel #007 | 1 = waktu, 4 = arus, 5 = tegangan |
| `A1-008-DST-US06-FUDS-25-20120827.xlsx` | Profil dinamis sel #008 | idem |

Kapasitas nominal yang dipakai di seluruh skrip: `Cn = 1.1 Ah`.

> Skrip saat ini di-*hardcode* ke sel **A1-007**. Untuk menjalankan sel 008, ganti nama file di bagian *Read Data* pada tiap notebook.

## Struktur File

**Live Script (urutan eksekusi):**

| File | Fungsi | Input | Output |
|---|---|---|---|
| [SoCApprox.mlx](SoCApprox.mlx) | Fitting polinomial OCV–SOC | `A1-007-OCV-*.xlsx` | `_polynomialEstimate.txt` |
| [FFRLS.mlx](FFRLS.mlx) | Identifikasi parameter online | `A1-007-DST-*.xlsx` | `_FFRLSParameters.txt`, `_discreteParameters.txt` |
| [LM.mlx](LM.mlx) | Refinement Levenberg–Marquardt | `_discreteParameters.txt` | `_LMParameters.txt` |
| [EKF.mlx](EKF.mlx) | Estimasi SOC | `_LMParameters.txt`, `_polynomialEstimate.txt` | plot SOC, Ut, Uoc + error |

**Fungsi pendukung:**

- [UocCurve.m](UocCurve.m) — evaluasi OCV dari SOC; memilih koefisien charge/discharge berdasarkan tanda arus, dengan *clamping* di bawah ambang SOC minimum.
- [dUocCurve.m](dUocCurve.m) — turunan dOCV/dSOC, dipakai sebagai Jacobian matriks output C pada EKF.

**Data hasil (regenerated, boleh dihapus):**

`_polynomialEstimate.txt`, `_FFRLSParameters.txt`, `_discreteParameters.txt`, `_LMParameters.txt`, `voc_soc_polyfit_discharge_charge.txt`

**Dokumen:**

- [SKPA_KELOMPOK 4_PROYEK AKHIR BMS.pdf](SKPA_KELOMPOK%204_PROYEK%20AKHIR%20BMS.pdf) — laporan proyek akhir
- [Paper.pdf](Paper.pdf) — paper referensi

## Cara Menjalankan

Butuh **MATLAB** (diuji dengan R2024b) — tidak ada toolbox tambahan; hanya `polyfit`, `readmatrix`, `readtable`.

```matlab
% dari folder proyek
run SoCApprox.mlx   % 1. kurva OCV-SOC
run FFRLS.mlx       % 2. identifikasi parameter
run LM.mlx          % 3. refinement
run EKF.mlx         % 4. estimasi SOC
```

Urutan ini wajib — tiap tahap membaca file `.txt` yang dihasilkan tahap sebelumnya. File `.txt` hasil sudah disertakan, jadi tiap notebook juga bisa dijalankan sendiri tanpa mengulang tahap awal.

## Detail Implementasi

**FFRLS — penanganan outlier.** Setelah iterasi ke-100, tiap parameter diperiksa terhadap batas ±3σ dari 100 sampel terakhir. Jika ada yang melewati batas, skrip menelusuri mundur hingga 40 estimasi θ sebelumnya dan memakai yang memberi error prediksi terkecil (*early exit* jika error < 0.05). Ini mencegah divergensi saat matriks kovarians `P` menjadi *ill-conditioned*.

**Konversi θ ↔ RC.** Model diskrit orde-2 dari diskretisasi bilinear (Tustin). `theta2rc` menginversi θ menjadi parameter RC lewat konstanta waktu τ₁, τ₂ (akar persamaan kuadrat); `rc2theta_scalar` melakukan arah sebaliknya dan dipakai LM untuk menghitung residual serta Jacobian secara *finite difference* (δ = 1e-6).

**EKF.** Matriks A dan B diturunkan dari solusi eksak diskrit rangkaian RC (`exp(-dt/RC)`); C = `[-1, -1, dUoc/dSOC]`, D = `-R0`. Parameter non-finit dari LM di-*fallback* ke `1e12`. SOC di-*clamp* ke [0, 1] tiap langkah. Tuning: `Q = diag([1e-6, 1e-6, 1e-6])`, `R = 1`, `P₀ = I`.

## Catatan & Gotchas

- **`dUocCurve.m` mendeklarasikan fungsi bernama `UocCurve`.** MATLAB memanggil berdasarkan nama file, jadi kodenya tetap jalan, tapi nama di dalam file sebaiknya diperbaiki agar tidak membingungkan.
- **`dUocCurve` membaca `global best_coeffs_chg`, sedangkan `EKF.mlx` mendefinisikannya sebagai variabel lokal.** Tanpa deklarasi `global` di EKF, variabel tersebut kosong dan turunan yang dikembalikan bernilai 0 — Jacobian SOC pada EKF menjadi nol. Perlu dicek ulang sebelum hasil dipakai.
- **`dUocCurve` hanya memakai koefisien charge**, tidak membedakan charge/discharge seperti `UocCurve`.
- `voc_soc_polyfit_discharge_charge.txt` berisi fitting orde-8 dari eksperimen awal; yang dipakai pipeline adalah `_polynomialEstimate.txt` (orde-12).
- Koefisien polinomial yang di-*hardcode* di `UocCurve.m` sedikit berbeda dari isi `_polynomialEstimate.txt` (beda di digit ke-6), karena berasal dari *run* yang berbeda.

## Kelompok 4

Proyek akhir Sistem Kendali Prediktif & Adaptif, Semester 6.
