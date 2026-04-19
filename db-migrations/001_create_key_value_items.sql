-- Migration 001: Create key_value_items table
-- A simple key-value store for the POC application.

CREATE TABLE IF NOT EXISTS public.key_value_items (
    id         BIGSERIAL    PRIMARY KEY,
    key        TEXT         NOT NULL,
    value      TEXT         NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Allow read/write access via PostgREST for authenticated and anonymous users
ALTER TABLE public.key_value_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all for anon" ON public.key_value_items
    FOR ALL
    TO anon
    USING (true)
    WITH CHECK (true);
