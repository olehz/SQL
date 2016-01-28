\timing on

\echo '\nosm_buildings: add aditional fields'
ALTER TABLE import.osm_buildings
	ADD COLUMN place_id bigint,
	ADD COLUMN street_id bigint;

\echo '\nosm_streets: add aditional fields'
ALTER TABLE import.osm_streets
	ADD COLUMN buildings bigint[],
	ADD COLUMN numbers character varying(50)[],
	ADD COLUMN letters character varying(30);

\echo '\nBuildings: Add place_id'
UPDATE :scm.osm_buildings b SET place_id = p.osm_id, upnad = 't' FROM import.osm_places p
WHERE upnad = 'f' AND p.streets > 0 AND ST_Contains(p.boundary, b.geometry);
CREATE INDEX osm_buildings_place_id_idx ON :scm.osm_buildings USING BTREE (place_id);

\echo '\nStreets: Fill buildings (addr)'
CREATE INDEX osm_buildings_addr_street_idx ON :scm.osm_buildings(addr_street);
UPDATE import.osm_streets s SET buildings = b.buildings
FROM (SELECT array_agg(osm_id) AS buildings, place_id, addr_street, addr_suburb FROM :scm.osm_buildings GROUP BY place_id, addr_street, addr_suburb) AS b
WHERE s.place_id = b.place_id AND s.name = b.addr_street AND s.addr_suburb = b.addr_suburb;

\echo '\nStreets: Fill buildings (rels)'
CREATE INDEX osm_rels_streets_idx ON :scm.osm_rels(streets);
CREATE INDEX osm_rels_houses_idx ON :scm.osm_rels(houses);
CREATE INDEX osm_streets_ids_idx ON import.osm_streets USING GIN (osm_ids);

UPDATE import.osm_streets s SET buildings = (rel.houses || s.buildings) FROM :scm.osm_rels rel WHERE s.osm_ids && rel.streets;
CREATE INDEX osm_streets_buildings_idx ON import.osm_streets USING GIN (buildings);

\echo '\nVACUUM ANALYZE'
VACUUM ANALYZE :scm.osm_buildings;
VACUUM ANALYZE import.osm_streets;

\echo '\nBuildings: Add street_id'
UPDATE :scm.osm_buildings b SET street_id = s.id FROM import.osm_streets s WHERE b.place_id IS NOT NULL AND b.osm_id = ANY(s.buildings);
CREATE INDEX osm_buildings_street_id_idx ON :scm.osm_buildings USING BTREE (street_id);



\echo '\nStreets: Order addr:housenumbers'
CREATE INDEX osm_buildings_housenumber_idx ON :scm.osm_buildings(addr_housenumber);

UPDATE import.osm_streets s SET
numbers = b.numbers,
buildings = b.buildings
FROM
(
SELECT
	street_id,
	array_agg(addr_housenumber ORDER BY CAST(substring(addr_housenumber FROM '^\d+') AS int),LENGTH(addr_housenumber),addr_housenumber) AS numbers,
	array_agg(osm_id ORDER BY CAST(substring(addr_housenumber FROM '^\d+') AS int),LENGTH(addr_housenumber),addr_housenumber) AS buildings
	FROM :scm.osm_buildings b GROUP BY street_id
) AS b
WHERE b.street_id = s.id
;


ALTER TABLE import.osm_places
  ADD COLUMN letters character varying(150);

\echo '\nStreets: Fill letters'
UPDATE import.osm_streets s SET letters = array_to_string(ARRAY(SELECT DISTINCT upper(substr(unnest(string_to_array(
trim(regexp_replace(s.name, '(\«|\‘|\"|\(|\)|\„|вулиця|провулок|площа|проспект|бульвар|узвіз|міст|проїзд|набережна|шосе|алея|в’їзд|тупик|спуск|майдан|підйом|лінія|дорога|дача|квартал|кілометр|просік|з’їзд|тунель|шляхопровід|естакада|метроміст|кільце|заїзд|Street|Lane|Square|Avenue|Boulevard|Descent|Bridge|Pass|Embarkment|Road|Alley|Entrance|End|Descent|Square|Ascent|Line|Road|Dacha|Quarter|Kilometer|Glade|Ramp|Tunnel|Overpass|Trestle|Bridge|Roundabout|улица|переулок|площадь|проспект|бульвар|спуск|мост|проезд|набережная|шоссе|аллея|въезд|тупик|спуск|майдан|подъём|линия|дорога|дача|квартал|километр|просек|съезд|тоннель|путепровод|эстакада|метромост|кольцо|заезд)', '')),
' ')),1,1))), ',');

\echo '\nPlaces: Fill letters'
UPDATE import.osm_places p SET letters = array_to_string(ARRAY(SELECT DISTINCT unnest(string_to_array(s.letters, ',')) AS z FROM import.osm_streets s WHERE place_id = p.osm_id ORDER BY z), ',');