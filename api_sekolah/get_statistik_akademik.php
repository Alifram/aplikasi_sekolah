<?php

header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

include 'koneksi.php';

error_reporting(0);
ini_set('display_errors', 0);


// ======================================================
// REQUEST OPTIONS
// ======================================================

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit;
}


// ======================================================
// HANYA MENERIMA POST
// ======================================================

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode([
        "status" => "error",
        "message" => "Method request harus POST."
    ]);
    exit;
}


// ======================================================
// AMBIL DATA JSON
// ======================================================

$input = json_decode(file_get_contents('php://input'), true);

$angkatan = isset($input['angkatan'])
    ? trim($input['angkatan'])
    : '2026';

$angkatan = mysqli_real_escape_string(
    $koneksi,
    $angkatan
);


// ======================================================
// DATA DEFAULT KELAS 1 - 6
// ======================================================

$statistik = [
    "Kelas 1" => [
        "Semester 1" => 0.0,
        "Semester 2" => 0.0
    ],
    "Kelas 2" => [
        "Semester 1" => 0.0,
        "Semester 2" => 0.0
    ],
    "Kelas 3" => [
        "Semester 1" => 0.0,
        "Semester 2" => 0.0
    ],
    "Kelas 4" => [
        "Semester 1" => 0.0,
        "Semester 2" => 0.0
    ],
    "Kelas 5" => [
        "Semester 1" => 0.0,
        "Semester 2" => 0.0
    ],
    "Kelas 6" => [
        "Semester 1" => 0.0,
        "Semester 2" => 0.0
    ]
];


// ======================================================
// QUERY STATISTIK
//
// TAHAP 1
// Hitung rata-rata nilai setiap siswa
// berdasarkan kelas + semester.
//
// TAHAP 2
// Hitung rata-rata seluruh siswa
// dalam kelas + semester tersebut.
//
// Nilai setiap siswa diberi bobot yang sama.
// ======================================================

$query = "
    SELECT
        data_siswa.kelas,
        data_siswa.semester_format,

        ROUND(
            AVG(data_siswa.rata_rata_siswa),
            1
        ) AS rerata_kelas

    FROM
    (
        SELECT

            TRIM(n.kelas) AS kelas,

            CASE
                WHEN TRIM(n.semester) = 'Semester 1'
                    THEN 'Semester 1'

                WHEN TRIM(n.semester) = 'Semester 2'
                    THEN 'Semester 2'

                WHEN TRIM(n.semester) = '1'
                    THEN 'Semester 1'

                WHEN TRIM(n.semester) = '2'
                    THEN 'Semester 2'

                ELSE NULL
            END AS semester_format,

            n.siswa_id,

            AVG(
                (
                    NULLIF(n.nilai_tugas, 0) +
                    NULLIF(n.nilai_uts, 0) +
                    NULLIF(n.nilai_uas, 0)
                )
                /
                NULLIF(
                    (
                        CASE
                            WHEN n.nilai_tugas > 0 THEN 1
                            ELSE 0
                        END
                        +
                        CASE
                            WHEN n.nilai_uts > 0 THEN 1
                            ELSE 0
                        END
                        +
                        CASE
                            WHEN n.nilai_uas > 0 THEN 1
                            ELSE 0
                        END
                    ),
                    0
                )
            ) AS rata_rata_siswa

        FROM nilai_raport n

        WHERE n.tahun_angkatan = '$angkatan'

        GROUP BY
            n.siswa_id,
            TRIM(n.kelas),
            semester_format

    ) AS data_siswa

    WHERE
        data_siswa.semester_format IS NOT NULL
        AND data_siswa.rata_rata_siswa IS NOT NULL

    GROUP BY
        data_siswa.kelas,
        data_siswa.semester_format

    ORDER BY
        data_siswa.kelas ASC,
        data_siswa.semester_format ASC
";


// ======================================================
// JALANKAN QUERY
// ======================================================

$result = mysqli_query(
    $koneksi,
    $query
);


if (!$result) {

    echo json_encode([
        "status" => "error",
        "message" =>
            "Gagal mengambil data statistik: "
            . mysqli_error($koneksi)
    ]);

    mysqli_close($koneksi);
    exit;
}


// ======================================================
// MASUKKAN HASIL KE DATA STATISTIK
// ======================================================

while ($row = mysqli_fetch_assoc($result)) {

    $kelas = trim($row['kelas']);

    $semester = trim(
        $row['semester_format']
    );

    $rerata = round(
        (float) $row['rerata_kelas'],
        1
    );

    if (
        isset($statistik[$kelas]) &&
        isset($statistik[$kelas][$semester])
    ) {
        $statistik[$kelas][$semester] = $rerata;
    }
}


// ======================================================
// RESPONSE
// ======================================================

echo json_encode([
    "status" => "success",
    "angkatan" => $angkatan,
    "data" => $statistik
]);


mysqli_close($koneksi);

?>