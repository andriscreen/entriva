ALTER TABLE public.logistics_queues
  ADD COLUMN IF NOT EXISTS unloading_started_at TIMESTAMPTZ;

UPDATE public.logistics_queues
SET unloading_started_at = updated_at
WHERE status = 'unloading'
  AND unloading_started_at IS NULL;
