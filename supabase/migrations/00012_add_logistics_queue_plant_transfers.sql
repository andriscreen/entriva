CREATE TABLE public.logistics_queue_transfers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  queue_id UUID REFERENCES public.logistics_queues(id) ON DELETE SET NULL,
  queue_number TEXT NOT NULL,
  source_plant TEXT NOT NULL CHECK (source_plant IN ('Jatake 1', 'Jatake 2', 'Jatake 3', 'Jatake 6')),
  target_plant TEXT NOT NULL CHECK (target_plant IN ('Jatake 1', 'Jatake 2', 'Jatake 3', 'Jatake 6')),
  transferred_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  transferred_by_name TEXT NOT NULL,
  transferred_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

CREATE INDEX logistics_queue_transfers_queue_time_idx
  ON public.logistics_queue_transfers (queue_id, transferred_at DESC);

ALTER TABLE public.logistics_queue_transfers ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON public.logistics_queue_transfers TO authenticated;

CREATE POLICY "Allow logistics staff to read relevant plant transfer history"
  ON public.logistics_queue_transfers
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles AS profile
      WHERE profile.id = auth.uid()
        AND profile.role IN ('admin_logistics', 'operator_logistics')
        AND profile.plant_location IN (source_plant, target_plant)
    )
  );

CREATE OR REPLACE FUNCTION public.transfer_logistics_queue_plant(
  p_queue_id UUID,
  p_target_plant TEXT
)
RETURNS TABLE (
  transfer_id UUID,
  queue_id UUID,
  queue_number TEXT,
  source_plant TEXT,
  target_plant TEXT,
  transferred_by UUID,
  transferred_by_name TEXT,
  transferred_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  actor_role public.user_role;
  actor_plant TEXT;
  actor_name TEXT;
  queue_row public.logistics_queues%ROWTYPE;
  transfer_row public.logistics_queue_transfers%ROWTYPE;
  transfer_time TIMESTAMPTZ;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Sesi pengguna tidak ditemukan.';
  END IF;

  SELECT profile.role, profile.plant_location, profile.full_name
  INTO actor_role, actor_plant, actor_name
  FROM public.profiles AS profile
  WHERE profile.id = auth.uid();

  IF NOT FOUND OR actor_role NOT IN ('admin_logistics', 'operator_logistics') THEN
    RAISE EXCEPTION 'Hanya Admin Logistik dan Operator Yard yang dapat mengalihkan plant.';
  END IF;

  IF p_target_plant IS NULL
    OR p_target_plant NOT IN ('Jatake 1', 'Jatake 2', 'Jatake 3', 'Jatake 6') THEN
    RAISE EXCEPTION 'Plant tujuan tidak valid.';
  END IF;

  SELECT queue.*
  INTO queue_row
  FROM public.logistics_queues AS queue
  WHERE queue.id = p_queue_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Antrean kendaraan tidak ditemukan.';
  END IF;

  IF queue_row.plant_location IS DISTINCT FROM actor_plant THEN
    RAISE EXCEPTION 'Anda hanya dapat mengalihkan antrean dari plant akun Anda.';
  END IF;

  IF queue_row.status <> 'waiting_in_yard' THEN
    RAISE EXCEPTION 'Alih plant hanya dapat dilakukan saat kendaraan masih menunggu di yard.';
  END IF;

  IF queue_row.plant_location = p_target_plant THEN
    RAISE EXCEPTION 'Plant tujuan sama dengan plant saat ini.';
  END IF;

  transfer_time := clock_timestamp();

  UPDATE public.logistics_queues AS queue
  SET plant_location = p_target_plant,
      current_node_id = NULL,
      assigned_dock_id = NULL,
      updated_at = transfer_time
  WHERE queue.id = queue_row.id;

  INSERT INTO public.logistics_queue_transfers (
    queue_id,
    queue_number,
    source_plant,
    target_plant,
    transferred_by,
    transferred_by_name,
    transferred_at
  )
  VALUES (
    queue_row.id,
    queue_row.queue_number,
    queue_row.plant_location,
    p_target_plant,
    auth.uid(),
    actor_name,
    transfer_time
  )
  RETURNING * INTO transfer_row;

  RETURN QUERY
  SELECT
    transfer_row.id,
    transfer_row.queue_id,
    transfer_row.queue_number,
    transfer_row.source_plant,
    transfer_row.target_plant,
    transfer_row.transferred_by,
    transfer_row.transferred_by_name,
    transfer_row.transferred_at;
END;
$$;

REVOKE ALL ON FUNCTION public.transfer_logistics_queue_plant(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.transfer_logistics_queue_plant(UUID, TEXT) TO authenticated;
