\timing on

\echo '\nosm_point_places: add aditional fields'
ALTER TABLE import.osm_point_places
  ADD COLUMN region_id bigint,
  ADD COLUMN state_id bigint,
  ADD COLUMN country_code character(2),

  ADD COLUMN lon float,
  ADD COLUMN lat float,
  ADD COLUMN morpher_name_uk character varying(250),
  ADD COLUMN morpher_name_ru character varying(250);

\echo '\nosm_point_places: Morpher'
UPDATE :scm.osm_point_places p SET morpher_name_uk = m.morpher_name_uk FROM morphers_uk m WHERE p.upnad = 'f' AND m.name_uk = p.name_uk;
UPDATE :scm.osm_point_places p SET morpher_name_ru = m.morpher_name_ru FROM morphers_ru m WHERE p.upnad = 'f' AND m.name_ru = p.name_ru;

\echo '\nosm_point_places: state_id + country_code'
UPDATE :scm.osm_point_places p SET state_id = a.parent_id, region_id = a.osm_id, country_code = a.country_code
FROM :scm.osm_admin a
WHERE p.upnad = 'f' AND a.level = 3
AND ST_Contains(a.boundary, p.geometry);

UPDATE :scm.osm_point_places p SET state_id = a.osm_id, country_code = a.country_code
FROM :scm.osm_admin a
WHERE p.upnad = 'f' AND state_id IS NULL AND a.level = 2
AND ST_Contains(a.boundary, p.geometry);

\echo '\nosm_point_places: lat/lon'
UPDATE :scm.osm_point_places SET lon = ST_X(ST_Transform(geometry, 4326)), lat = ST_Y(ST_Transform(geometry, 4326));

\echo '\nPlaces: Create table'
DROP TABLE IF EXISTS import.osm_places CASCADE;
CREATE TABLE import.osm_places AS
  SELECT  row_number() OVER () id, c.osm_id,
  c.name, c.alt_name, c.old_name, c.name_uk, c.name_ru, c.name_pl, c.name_en, c.name_be, int_name,
  c.population,c.addr_postcode,c.official_status,c.name_prefix AS name_prefix,
  c.koatuu,
  c.wikipedia,
  c.wikidata,
  c.place, c.geometry as centre,
  c.country_code, c.state_id, c.region_id,
  c.morpher_name_uk, c.morpher_name_ru, c.lon, c.lat,
  (SELECT ARRAY_AGG(a) FROM UNNEST(ARRAY[b.osm_id]) a WHERE a IS NOT NULL) AS boundary_id,
  b.geometry AS boundary,
  0 AS streets
  FROM :scm.osm_point_places c
  LEFT JOIN :scm.osm_polygon_places b ON c.name = b.name AND c.place = b.place AND ST_Contains(b.geometry, c.geometry)
;

\echo '\nPlaces: Add boundary'
UPDATE import.osm_places p SET
  boundary_id = (SELECT ARRAY_AGG(boundary_id[1]) FROM import.osm_places WHERE osm_id = d.osm_id),
  boundary = (SELECT ST_Union(boundary) FROM import.osm_places WHERE osm_id = d.osm_id)
FROM (
SELECT osm_id FROM import.osm_places
GROUP BY osm_id
HAVING COUNT(osm_id) > 1
) AS d
WHERE p.osm_id = d.osm_id;

\echo '\nPlaces: Remove (fix double boundary)'
DELETE FROM import.osm_places r USING (SELECT osm_id, MAX(id) AS max_id FROM import.osm_places GROUP BY osm_id HAVING COUNT(osm_id) > 1) AS m WHERE m.osm_id = r.osm_id AND r.id < m.max_id;

\echo '\nPlaces: Replace id/osm_id'
ALTER TABLE import.osm_places ADD PRIMARY KEY (id);
CREATE INDEX osm_streets_osm_id_idx ON import.osm_streets USING BTREE(osm_id);

\echo '\nPlaces: Create spatial indexes'
CREATE INDEX osm_places_boundary ON import.osm_places USING GIST(boundary);

CREATE INDEX osm_places_geom_geohash ON import.osm_places (ST_GeoHash(ST_Transform(ST_SetSRID(Box2D(boundary), 3857), 4326)));
CLUSTER osm_places_geom_geohash ON import.osm_places;
--CLUSTER osm_places_boundary ON import.osm_places;
--ALTER TABLE import.osm_places ADD CONSTRAINT enforce_dims_boundary CHECK (st_ndims(boundary) = 2);
--ALTER TABLE import.osm_places ADD CONSTRAINT enforce_srid_boundary CHECK (st_srid(boundary) = 3857);


CREATE INDEX osm_places_centre ON import.osm_places USING GIST(centre);
--CLUSTER osm_places_centre ON import.osm_places;
--ALTER TABLE import.osm_places ADD CONSTRAINT enforce_dims_centre CHECK (st_ndims(centre) = 2);
--ALTER TABLE import.osm_places ADD CONSTRAINT enforce_geotype_centre CHECK (geometrytype(centre) = 'POINT'::text OR centre IS NULL);
--ALTER TABLE import.osm_places ADD CONSTRAINT enforce_srid_centre CHECK (st_srid(centre) = 3857);

\echo '\nPlaces: Add boundary (admin_level=8)'
CREATE INDEX osm_admin_name_idx ON :scm.osm_admin(name);
CREATE INDEX osm_places_name_idx ON import.osm_places(name);

UPDATE import.osm_places p SET boundary = a.boundary, boundary_id = ARRAY[a.osm_id]
FROM :scm.osm_admin a
WHERE p.boundary_id IS NULL AND p.name = a.name AND a.admin_level = 8 AND ST_Contains(a.boundary, p.centre);

CREATE INDEX osm_places_place_idx ON import.osm_places(place);

ANALYZE import.osm_places;