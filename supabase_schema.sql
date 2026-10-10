-- ==============================================================================
-- SCHEMA LENGKAP ONELINGUA / SMART VOCABULARY
-- Berdasarkan ERD & Class Diagram Keseluruhan Sistem
-- Jalankan skrip ini sekali jalan di: Supabase Dashboard -> SQL Editor -> Run
-- ==============================================================================

-- 1. TABEL JOURNALS
CREATE TABLE IF NOT EXISTS public.journals (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    story TEXT NOT NULL,
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_journals_user_id ON public.journals(user_id);


-- 2. TABEL PROGRESS
CREATE TABLE IF NOT EXISTS public.progress (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    section TEXT NOT NULL,
    phase TEXT NOT NULL,
    level INTEGER NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_section_phase UNIQUE (user_id, section, phase)
);

CREATE INDEX IF NOT EXISTS idx_progress_user_id ON public.progress(user_id);


-- 3. TABEL AI_EVALUATIONS
CREATE TABLE IF NOT EXISTS public.ai_evaluations (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    section TEXT NOT NULL,
    nilai_ketepatan NUMERIC NOT NULL,
    answer TEXT,
    feedback TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_evaluations_user_id ON public.ai_evaluations(user_id);


-- 4. TABEL NEWBORN_VIDEOS (Modul Newborn - Video Immersion)
CREATE TABLE IF NOT EXISTS public.newborn_videos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(50) NOT NULL,
    platform VARCHAR(20) NOT NULL CHECK (platform IN ('youtube', 'tiktok')),
    video_id VARCHAR(100) NOT NULL,
    embed_url TEXT NOT NULL,
    title VARCHAR(255),
    order_index INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_newborn_videos_cat_order 
ON public.newborn_videos(category, order_index ASC);


-- 5. TABEL DICTIONARY (Modul Kamus Kosakata)
CREATE TABLE IF NOT EXISTS public.dictionary (
    id BIGSERIAL PRIMARY KEY,
    word TEXT NOT NULL,
    pos VARCHAR(20) NOT NULL,
    definition_en TEXT NOT NULL,
    definition_id TEXT NOT NULL,
    v1 TEXT DEFAULT '',
    v2 TEXT DEFAULT '',
    v3 TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dictionary_word ON public.dictionary(word);
CREATE INDEX IF NOT EXISTS idx_dictionary_pos ON public.dictionary(pos);


-- ==============================================================================
-- KEAMANAN: ROW LEVEL SECURITY (RLS)
-- ==============================================================================

ALTER TABLE public.journals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_evaluations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.newborn_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dictionary ENABLE ROW LEVEL SECURITY;

-- Policy Journals (User hanya bisa CRUD datanya sendiri)
DROP POLICY IF EXISTS "Users can manage their own journals" ON public.journals;
CREATE POLICY "Users can manage their own journals"
    ON public.journals
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy Progress (User hanya bisa baca/tulis progresnya sendiri)
DROP POLICY IF EXISTS "Users can manage their own progress" ON public.progress;
CREATE POLICY "Users can manage their own progress"
    ON public.progress
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy AI Evaluations (User hanya bisa akses riwayat evaluasinya sendiri)
DROP POLICY IF EXISTS "Users can manage their own evaluations" ON public.ai_evaluations;
CREATE POLICY "Users can manage their own evaluations"
    ON public.ai_evaluations
    FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Policy Newborn Videos (Akses baca publik/anonim agar video bisa diputar)
DROP POLICY IF EXISTS "Allow public read access for newborn_videos" ON public.newborn_videos;
CREATE POLICY "Allow public read access for newborn_videos" 
    ON public.newborn_videos 
    FOR SELECT 
    USING (true);

-- Policy Dictionary (Akses baca publik/anonim untuk pencarian kamus)
DROP POLICY IF EXISTS "Allow public read access for dictionary" ON public.dictionary;
CREATE POLICY "Allow public read access for dictionary" 
    ON public.dictionary 
    FOR SELECT 
    USING (true);


-- ==============================================================================
-- SEED DATA CONTOH (Untuk Pengujian Awal)
-- ==============================================================================

-- Sample Video Newborn (Greetings & Daily)
INSERT INTO public.newborn_videos (category, platform, video_id, embed_url, title, order_index)
VALUES 
    ('greetings', 'youtube', 'F9A_FzE4V2g', 'https://www.youtube.com/embed/F9A_FzE4V2g', 'Basic English Greetings', 1),
    ('home', 'youtube', 'q-9B4w9U3vA', 'https://www.youtube.com/embed/q-9B4w9U3vA', 'Objects in the Living Room', 1)
ON CONFLICT DO NOTHING;

-- Sample Kata Kamus (Verbs & Nouns Dasar)
INSERT INTO public.dictionary (word, pos, definition_en, definition_id, v1, v2, v3)
VALUES
    ('run', 'verb', 'Move at a speed faster than a walk.', 'Berlari dengan cepat.', 'run', 'ran', 'run'),
    ('eat', 'verb', 'Put food into the mouth and chew and swallow it.', 'Makan atau mengunyah makanan.', 'eat', 'ate', 'eaten'),
    ('write', 'verb', 'Mark letters, words, or other symbols on a surface.', 'Menulis kata atau kalimat.', 'write', 'wrote', 'written'),
    ('book', 'noun', 'A written or printed work consisting of pages.', 'Buku bacaan atau catatan.', '', '', ''),
    ('water', 'noun', 'A colourless, transparent, odourless liquid.', 'Air minum atau cairan.', '', '', '')
ON CONFLICT DO NOTHING;
