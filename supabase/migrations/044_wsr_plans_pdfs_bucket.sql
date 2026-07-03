-- Bucket privado para PDFs de planes de entrenamiento entregados.
-- Escritura y lectura exclusivas de service_role (Vercel serverless usa
-- SUPABASE_SERVICE_ROLE_KEY). Las corredoras acceden solo vía signed URL
-- de 1 año generada por api/deliver-plan.ts, nunca por acceso directo al bucket.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('wsr-plans-pdfs', 'wsr-plans-pdfs', false, 20971520, array['application/pdf'])
on conflict (id) do nothing;

-- storage.objects ya trae RLS activado por defecto en todo proyecto Supabase
-- y le pertenece a supabase_storage_admin, no a postgres: un
-- ALTER TABLE ... ENABLE ROW LEVEL SECURITY aquí falla con
-- "must be owner of table objects". No hace falta y no debe incluirse.

create policy "wsr-plans-pdfs: solo service_role escribe"
  on storage.objects
  for insert
  to service_role
  with check (bucket_id = 'wsr-plans-pdfs');

create policy "wsr-plans-pdfs: solo service_role actualiza"
  on storage.objects
  for update
  to service_role
  using (bucket_id = 'wsr-plans-pdfs')
  with check (bucket_id = 'wsr-plans-pdfs');

create policy "wsr-plans-pdfs: solo service_role lee"
  on storage.objects
  for select
  to service_role
  using (bucket_id = 'wsr-plans-pdfs');

create policy "wsr-plans-pdfs: solo service_role elimina"
  on storage.objects
  for delete
  to service_role
  using (bucket_id = 'wsr-plans-pdfs');
