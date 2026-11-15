ALTER TABLE public.logistics_queues
  ADD COLUMN IF NOT EXISTS approved_by_name TEXT;

UPDATE public.logistics_queues AS queue
SET approved_by_name = profile.full_name
FROM public.profiles AS profile
WHERE queue.approved_by = profile.id
  AND queue.approved_by_name IS NULL;
