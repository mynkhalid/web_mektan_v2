-- ============================================================
-- SQL Script: Pembuatan Tabel MyMektan
-- Dibuat berdasarkan schema Supabase yang ada
-- Jalankan urut dari atas ke bawah di pgAdmin (Query Tool)
-- ============================================================

-- 1. Tabel pengaturan_sistem (tidak punya dependensi)
CREATE TABLE public.pengaturan_sistem (
  kunci character varying NOT NULL,
  nilai bigint,
  keterangan text,
  CONSTRAINT pengaturan_sistem_pkey PRIMARY KEY (kunci)
);

-- 2. Tabel alsintan (induk utama, direferensikan tabel lain)
CREATE TABLE public.alsintan (
  alsintan_id serial NOT NULL,
  kode_perangkat character varying,
  nama_alat character varying,
  kategori_alat character varying,
  merk_alat character varying,
  nomor_seri character varying,
  status character varying,
  status_sensor character varying,
  status_operasional character varying,
  deskripsi text,
  kapasitas_lahan character varying,
  gambar text,
  waktu_reset timestamp without time zone,
  latitude numeric,
  longitude numeric,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  lebar_implemen numeric,
  kondisi_fisik character varying,
  status_ketersediaan character varying DEFAULT 'Tersedia di Balai'::character varying,
  tahun_penerimaan integer,
  kode_unit character varying,
  nomor_mesin character varying,
  CONSTRAINT alsintan_pkey PRIMARY KEY (alsintan_id)
);

-- 3. Tabel users
CREATE TABLE public.users (
  user_id serial NOT NULL,
  username character varying UNIQUE,
  email character varying UNIQUE,
  nama_lengkap character varying,
  no_hp character varying,
  password character varying,
  role character varying,
  nip character varying,
  foto_profil text,
  current_token text,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  nama_instansi character varying,
  kabupaten character varying,
  kecamatan character varying,
  desa character varying,
  status_akun character varying DEFAULT 'aktif'::character varying,
  CONSTRAINT users_pkey PRIMARY KEY (user_id)
);

-- 4. Tabel pengajuan_publik (referensi ke alsintan)
CREATE TABLE public.pengajuan_publik (
  id_pengajuan serial NOT NULL,
  alsintan_id integer,
  tanggal_mulai date,
  tanggal_berakhir date,
  nama_peminjam character varying,
  jabatan_peminjam character varying,
  kontak_peminjam character varying,
  nama_kelompok character varying,
  desa character varying,
  kecamatan character varying,
  kabupaten character varying,
  status_pengajuan character varying DEFAULT 'Pending'::character varying,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pengajuan_publik_pkey PRIMARY KEY (id_pengajuan),
  CONSTRAINT pengajuan_publik_alsintan_id_fkey FOREIGN KEY (alsintan_id) REFERENCES public.alsintan(alsintan_id)
);

-- 5. Tabel transaksi_peminjaman (referensi ke alsintan)
CREATE TABLE public.transaksi_peminjaman (
  id_transaksi serial NOT NULL,
  alsintan_id integer,
  tanggal_mulai date,
  tanggal_berakhir date,
  nomor_ba character varying,
  nama_peminjam character varying,
  jabatan_peminjam character varying,
  kontak_peminjam character varying,
  nama_kelompok character varying,
  desa character varying,
  kecamatan character varying,
  kabupaten character varying,
  biaya_jasa numeric,
  status_pinjam character varying,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT transaksi_peminjaman_pkey PRIMARY KEY (id_transaksi),
  CONSTRAINT transaksi_peminjaman_alsintan_id_fkey FOREIGN KEY (alsintan_id) REFERENCES public.alsintan(alsintan_id)
);

-- 6. Tabel monitoring_status (referensi ke alsintan, 1:1)
CREATE TABLE public.monitoring_status (
  alsintan_id integer NOT NULL,
  status_mesin character varying,
  last_heartbeat timestamp without time zone,
  total_hour_meter double precision,
  total_jarak_kerja double precision,
  tegangan_aki double precision,
  latitude numeric,
  longitude numeric,
  updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  hdop integer,
  satelit integer,
  status_iot character varying,
  CONSTRAINT monitoring_status_pkey PRIMARY KEY (alsintan_id),
  CONSTRAINT monitoring_status_alsintan_id_fkey FOREIGN KEY (alsintan_id) REFERENCES public.alsintan(alsintan_id)
);

-- 7. Tabel riwayat_perjalanan (referensi ke alsintan)
CREATE TABLE public.riwayat_perjalanan (
  id serial NOT NULL,
  alsintan_id integer,
  latitude numeric,
  longitude numeric,
  waktu_rekam timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  status_mesin character varying,
  CONSTRAINT riwayat_perjalanan_pkey PRIMARY KEY (id),
  CONSTRAINT riwayat_perjalanan_alsintan_id_fkey FOREIGN KEY (alsintan_id) REFERENCES public.alsintan(alsintan_id)
);

-- 8. Tabel riwayat_telemetri (referensi ke alsintan)
CREATE TABLE public.riwayat_telemetri (
  id serial NOT NULL,
  alsintan_id integer,
  tegangan_aki double precision,
  arus double precision,
  waktu_rekam timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT riwayat_telemetri_pkey PRIMARY KEY (id),
  CONSTRAINT riwayat_telemetri_alsintan_id_fkey FOREIGN KEY (alsintan_id) REFERENCES public.alsintan(alsintan_id)
);