\c acl
drop function get_parent_tree(UUID);
CREATE OR REPLACE FUNCTION get_parent_tree(in_id UUID) 
RETURNS table(id UUID, level int, path text ,parent_object UUID) AS $$
with recursive p(id,level,path,parent_object) as (
  select id,0, '/'||id , parent_object from object_identities where id = in_id
  union
  select o.id,p.level+1, p.path || '/' || o.id, o.parent_object 
  from object_identities o inner join p on p.parent_object = o.id
) select id,level,path,parent_object from p;
$$ LANGUAGE sql;

drop function insert_bulk_permissions(UUID,boolean,boolean,boolean,boolean,UUID[]);
CREATE OR REPLACE function insert_bulk_permissions(in_oid UUID,in_create_permission boolean,in_read_permission boolean,in_update_permission boolean,in_delete_permission boolean,variadic in_sids UUID[]) RETURNS void AS $$
DECLARE
tmp_id UUID;
BEGIN
  FOREACH tmp_id in ARRAY in_sids LOOP
    insert into acl_entries(object_id,sid,create_permission,read_permission,update_permission,delete_permission)
      select in_oid, asid , in_create_permission, in_read_permission, in_update_permission, in_delete_permission  
      from unnest(in_sids) AS asid
    on conflict (object_id, sid) do 
    update set read_permission = in_read_permission, update_permission = in_update_permission, delete_permission = in_delete_permission, create_permission = in_create_permission 
  where acl_entries.object_id = in_oid AND acl_entries.sid = tmp_id;
END LOOP; 
END;
$$ LANGUAGE  plpgsql;

drop function delete_objects(in_oids UUID[]);
CREATE OR REPLACE function delete_objects(VARIADIC in_oids UUID[]) RETURNS void AS $$
delete from object_identities where id in (select oid from unnest(in_oids) as oid);
$$ LANGUAGE  sql;


drop function insert_bulk_sid_permissions(UUID,boolean,boolean,boolean,boolean,UUID[]);
CREATE OR REPLACE function insert_bulk_sid_permissions(in_sid UUID,in_create_permission boolean,in_read_permission boolean,in_update_permission boolean,in_delete_permission boolean,variadic in_oids UUID[]) RETURNS void AS $$
DECLARE
tmp_id UUID;
BEGIN
  FOREACH tmp_id in ARRAY in_oids LOOP
    insert into acl_entries(object_id,sid,create_permission,read_permission,update_permission,delete_permission) 
      select oid, in_sid , in_create_permission, in_read_permission, in_update_permission, in_delete_permission  
      from unnest(in_oids) AS oid
    on conflict (object_id, sid) do update set read_permission = in_read_permission, update_permission = in_update_permission, delete_permission = in_delete_permission, create_permission = in_create_permission 
    where acl_entries.object_id = tmp_id AND acl_entries.sid = in_sid;
  END LOOP;
END;
$$ LANGUAGE  plpgsql;

drop function get_permissions(UUID,UUID);
drop type permission;
create type permission as (
  object_id         UUID,
  sid               UUID,
  read_permission   boolean,
  create_permission boolean,
  update_permission boolean,
  delete_permission boolean
);

CREATE OR REPLACE FUNCTION get_permissions(in_object_id UUID, in_sid UUID) 
RETURNS json AS $$
DECLARE
result permission;
tmp record;
BEGIN
  result.object_id = in_object_id;
  result.sid = in_sid;
  result.read_permission = false;
  result.create_permission = false;
  result.update_permission = false;
  result.delete_permission = false;
  FOR tmp IN select * from get_parent_tree(in_object_id) t inner join acl_entries ac on t.id = ac.object_id where ac.sid = in_sid LOOP
    RAISE NOTICE 'got record with id % and values % % % %', tmp.object_id, tmp.read_permission, tmp.create_permission,tmp.update_permission,tmp.delete_permission;
    if tmp.read_permission THEN
      result.read_permission = true;
    END IF;
    IF tmp.create_permission THEN
      result.create_permission = true;
    END IF;
    IF tmp.update_permission THEN
      result.update_permission = true;
    END IF;
    IF tmp.delete_permission THEN
      result.delete_permission = true;
    END IF;
    END LOOP;
    return to_json(result);
    END;
    $$ LANGUAGE plpgsql;

