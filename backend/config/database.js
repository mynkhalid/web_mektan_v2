const { Pool } = require('pg');

const db = new Pool({
    // Menggunakan Connection String tunggal yang diberikan Neon
    connectionString: process.env.DATABASE_URL,
    // Wajib diaktifkan agar Neon.tech mengizinkan koneksi dari luar
    ssl: {
        rejectUnauthorized: false 
    }
});


db.connect((err, client, release) => {
    if (err) {
        console.error('❌ Gagal koneksi ke database PostgreSQL:', err.stack);
    } else {
        console.log('✅ Berhasil koneksi ke database PostgreSQL lokal');
        release(); 
    }
});

module.exports = db;