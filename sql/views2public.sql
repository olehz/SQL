DROP TABLE IF EXISTS public.osm_places;
ALTER TABLE import.osm_places SET SCHEMA public;

DROP TABLE IF EXISTS public.osm_streets;
ALTER TABLE import.osm_streets SET SCHEMA public;

DROP TABLE IF EXISTS public.osm_poi;
ALTER TABLE import.osm_poi SET SCHEMA public;


