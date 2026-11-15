DROP POLICY IF EXISTS "Allow auth users full access to vendors" ON public.vendors;

CREATE POLICY "Allow authenticated users to read vendors"
  ON public.vendors
  FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Allow admin logistics to manage vendors"
  ON public.vendors
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin_logistics'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE profiles.id = auth.uid()
        AND profiles.role = 'admin_logistics'
    )
  );
