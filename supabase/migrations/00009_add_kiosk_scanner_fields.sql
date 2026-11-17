ALTER TYPE public.logistics_status ADD VALUE IF NOT EXISTS 'checked_out';

ALTER TABLE public.logistics_queues
  ADD COLUMN IF NOT EXISTS initial_plant_location TEXT,
  ADD COLUMN IF NOT EXISTS checked_out_at TIMESTAMPTZ;

CREATE POLICY "Allow anon read active gate nodes"
  ON public.map_nodes
  FOR SELECT
  TO anon
  USING (node_type = 'gate' AND is_active = TRUE);
