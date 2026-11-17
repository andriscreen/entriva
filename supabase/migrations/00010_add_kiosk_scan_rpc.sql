CREATE OR REPLACE FUNCTION public.kiosk_process_queue_scan(
  p_queue_number TEXT,
  p_plant_location TEXT,
  p_gate_node_id UUID,
  p_action TEXT
)
RETURNS TABLE (
  outcome TEXT,
  queue_status public.logistics_status,
  source_plant TEXT,
  target_plant TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  queue_row public.logistics_queues%ROWTYPE;
  original_plant TEXT;
  scan_time TIMESTAMPTZ := clock_timestamp();
BEGIN
  IF p_action IS NULL OR p_action NOT IN ('check_in', 'check_out') THEN
    RAISE EXCEPTION 'Aksi scan tidak valid.';
  END IF;

  IF p_plant_location IS NULL OR p_plant_location NOT IN ('Jatake 1', 'Jatake 2', 'Jatake 3', 'Jatake 6') THEN
    RAISE EXCEPTION 'Plant lokasi pos tidak valid.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.map_nodes AS gate
    WHERE gate.id = p_gate_node_id
      AND gate.plant_location = p_plant_location
      AND gate.node_type = 'gate'
      AND gate.is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'Node gerbang tidak aktif atau tidak sesuai dengan plant.';
  END IF;

  SELECT queue.*
  INTO queue_row
  FROM public.logistics_queues AS queue
  WHERE queue.queue_number = p_queue_number
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY
    SELECT 'not_found'::TEXT, NULL::public.logistics_status, NULL::TEXT, NULL::TEXT;
    RETURN;
  END IF;

  original_plant := queue_row.plant_location;

  IF p_action = 'check_in' AND queue_row.status = 'approved' THEN
    IF queue_row.initial_plant_location = p_plant_location
      AND queue_row.plant_location <> p_plant_location THEN
      RETURN QUERY
      SELECT 'exit_transfer'::TEXT, queue_row.status, p_plant_location, queue_row.plant_location;
      RETURN;
    END IF;

    UPDATE public.logistics_queues AS queue
    SET initial_plant_location = CASE
          WHEN queue.plant_location <> p_plant_location
            AND queue.initial_plant_location IS NULL
          THEN queue.plant_location
          ELSE queue.initial_plant_location
        END,
        plant_location = p_plant_location,
        status = 'waiting_in_yard',
        current_node_id = p_gate_node_id,
        updated_at = scan_time
    WHERE queue.id = queue_row.id;

    RETURN QUERY
    SELECT
      CASE WHEN original_plant = p_plant_location THEN 'check_in' ELSE 'rerouted' END::TEXT,
      'waiting_in_yard'::public.logistics_status,
      original_plant,
      p_plant_location;
    RETURN;
  END IF;

  IF p_action = 'check_out' AND queue_row.status = 'completed' THEN
    UPDATE public.logistics_queues AS queue
    SET status = 'checked_out',
        current_node_id = NULL,
        checked_out_at = scan_time,
        updated_at = scan_time
    WHERE queue.id = queue_row.id;

    RETURN QUERY
    SELECT 'checked_out'::TEXT, 'checked_out'::public.logistics_status, queue_row.plant_location, NULL::TEXT;
    RETURN;
  END IF;

  RETURN QUERY
  SELECT 'status_changed'::TEXT, queue_row.status, queue_row.plant_location, queue_row.plant_location;
END;
$$;

REVOKE ALL ON FUNCTION public.kiosk_process_queue_scan(TEXT, TEXT, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.kiosk_process_queue_scan(TEXT, TEXT, UUID, TEXT) TO anon, authenticated;
