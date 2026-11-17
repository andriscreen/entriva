ALTER TABLE public.logistics_queues
  ADD COLUMN estimated_arrival_at TIMESTAMPTZ,
  ADD COLUMN checked_in_at TIMESTAMPTZ;

COMMENT ON COLUMN public.logistics_queues.estimated_arrival_at IS
  'Driver-provided estimated arrival time at the destination plant.';

COMMENT ON COLUMN public.logistics_queues.checked_in_at IS
  'Server timestamp recorded when the vehicle checks in at the gate.';

CREATE INDEX logistics_queues_plant_status_checked_in_idx
  ON public.logistics_queues (plant_location, status, checked_in_at, created_at);

CREATE OR REPLACE FUNCTION public.set_logistics_queue_checked_in_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NEW.status = 'waiting_in_yard' AND OLD.status IS DISTINCT FROM NEW.status THEN
    NEW.checked_in_at := clock_timestamp();
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER logistics_queues_set_checked_in_at
BEFORE UPDATE OF status ON public.logistics_queues
FOR EACH ROW
EXECUTE FUNCTION public.set_logistics_queue_checked_in_at();

CREATE OR REPLACE FUNCTION public.require_logistics_queue_estimated_arrival()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NEW.estimated_arrival_at IS NULL OR NEW.estimated_arrival_at <= statement_timestamp() THEN
    RAISE EXCEPTION 'Estimasi kedatangan harus diisi dengan waktu yang akan datang.';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER logistics_queues_require_estimated_arrival
BEFORE INSERT ON public.logistics_queues
FOR EACH ROW
EXECUTE FUNCTION public.require_logistics_queue_estimated_arrival();
