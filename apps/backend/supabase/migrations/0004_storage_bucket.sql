-- 0004_storage_bucket.sql
-- Creates the "invoices" Storage bucket (for generated invoice PDFs) and RLS.

insert into storage.buckets (id, name, public)
values ('invoices', 'invoices', true)
on conflict (id) do nothing;

drop policy if exists invoices_bucket_authenticated_all on storage.objects;
create policy invoices_bucket_authenticated_all
  on storage.objects
  for all
  to authenticated
  using (bucket_id = 'invoices')
  with check (bucket_id = 'invoices');
