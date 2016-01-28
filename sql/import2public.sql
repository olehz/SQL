DROP TABLE IF EXISTS public.osm_admin CASCADE;
ALTER TABLE import.osm_admin SET SCHEMA public;

DROP TABLE IF EXISTS public.osm_buildings CASCADE ;
ALTER TABLE import.osm_buildings SET SCHEMA public;

DROP TABLE IF EXISTS public.osm_power;
ALTER TABLE import.osm_power SET SCHEMA public;



DROP TABLE IF EXISTS public.osm_roads CASCADE ;
ALTER TABLE import.osm_roads SET SCHEMA public;

DROP TABLE IF EXISTS public.osm_rels CASCADE ;
ALTER TABLE import.osm_rels SET SCHEMA public;



DROP TABLE IF EXISTS public.osm_point_places CASCADE ;
ALTER TABLE import.osm_point_places SET SCHEMA public;

DROP TABLE IF EXISTS public.osm_polygon_places CASCADE ;
ALTER TABLE import.osm_polygon_places SET SCHEMA public;


DROP TABLE IF EXISTS public.osm_linestring_poi;
ALTER TABLE import.osm_linestring_poi SET SCHEMA public;

DROP TABLE IF EXISTS public.osm_polygon_poi;
ALTER TABLE import.osm_polygon_poi SET SCHEMA public;

DROP TABLE IF EXISTS public.osm_point_poi;
ALTER TABLE import.osm_point_poi SET SCHEMA public;

--DROP SCHEMA import CASCADE;