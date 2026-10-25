ALTER TABLE jadwal_pelajaran
    ADD KEY idx_jadwal_hari_kelas_jam (hari, kelas, jam_mulai),
    ADD KEY idx_jadwal_hari_guru_jam (hari, guru_pengampu, jam_mulai);
