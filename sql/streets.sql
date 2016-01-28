ALTER TABLE import.osm_roads
  ADD COLUMN place_id bigint,
  ADD COLUMN region_id bigint,
  ADD COLUMN state_id bigint,
  ADD COLUMN country_code character(2);

UPDATE import.osm_roads l SET
place_id = p.osm_id,
state_id = p.state_id,
region_id = p.region_id,
country_code = p.country_code,
upnad = 't'
FROM (SELECT osm_id, boundary, state_id, region_id, country_code FROM import.osm_places WHERE place IN ('city','town','village','hamlet') AND
boundary IS NOT NULL AND ST_IsValid(boundary)
) p
WHERE upnad = 'f' AND
(ST_Intersects(l.geometry, p.boundary)) AND NOT ST_Touches(l.geometry, p.boundary);

DROP TABLE IF EXISTS import.osm_streets;
CREATE TABLE import.osm_streets AS
  SELECT row_number() OVER () id,
  (select ('x'||substr(encode(digest(place_id||name||addr_suburb, 'sha1'), 'hex'),1,8))::bit(32)::int) AS hash_id,
  array_agg(osm_id) AS osm_ids,
  name, alt_name, old_name, name_uk, name_ru, name_pl, name_be, ''::character varying AS name_en,
  addr_suburb,
  place_id, country_code, state_id,
  ST_LineMerge(ST_Collect(geometry)) AS geometry,
  ST_AsGeoJson(ST_Transform(ST_LineMerge(ST_Collect(geometry)), 4326)) AS geojson,
  FALSE AS crossed_boundary,
  FALSE AS segments_gaps,
  FALSE AS has_error
FROM import.osm_roads
GROUP BY osm_id, country_code, state_id, place_id, addr_suburb, name, alt_name, old_name, name_uk, name_ru, name_pl, name_be
;