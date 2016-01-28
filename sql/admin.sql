\timing on

ALTER TABLE import.osm_admin
	ADD COLUMN level int,
	ADD COLUMN parent_id bigint,
	ADD COLUMN children bigint[],
	ADD COLUMN geojson text,
	ADD COLUMN lon float,
	ADD COLUMN lat float;

SELECT AddGeometryColumn('import', 'osm_admin', 'center', 3857, 'POINT', 2);

\echo 'Admin: Center'

UPDATE :scm.osm_admin SET center = ST_PointOnSurface(boundary) WHERE ST_IsValid(boundary);

CREATE INDEX osm_admin_center ON :scm.osm_admin USING GIST(center);
CLUSTER osm_admin_center ON :scm.osm_admin;

\echo '\nAdmin: GeoJSON'
UPDATE :scm.osm_admin a SET
  geojson = ST_AsGeoJson(ST_Transform(ST_SimplifyPreserveTopology(boundary, 2 ^ (12-admin_level)), 4326)),
  lon = ST_X(ST_Transform(center, 4326)), lat = ST_Y(ST_Transform(center, 4326))
  WHERE upnad = 'f';

\echo '\nAdmins: Add parent_id'
UPDATE :scm.osm_admin a SET level = 1 WHERE admin_level = 2 AND country_code != '';

UPDATE :scm.osm_admin a SET parent_id = sub.parent_id, country_code = sub.country_code, level = 2
FROM (SELECT country_code, osm_id AS parent_id, UNNEST(subareas) AS osm_id FROM :scm.osm_admin WHERE level = 1) AS sub
WHERE a.osm_id = sub.osm_id;

UPDATE :scm.osm_admin a SET parent_id = sub.parent_id, country_code = sub.country_code, level = 3
FROM (SELECT country_code, osm_id AS parent_id, UNNEST(subareas) AS osm_id FROM :scm.osm_admin WHERE level = 2) AS sub
WHERE a.osm_id = sub.osm_id;

UPDATE :scm.osm_admin a SET parent_id = sub.parent_id, country_code = sub.country_code, level = 4
FROM (SELECT country_code, osm_id AS parent_id, UNNEST(subareas) AS osm_id FROM :scm.osm_admin WHERE level = 3) AS sub
WHERE a.osm_id = sub.osm_id;

UPDATE :scm.osm_admin a SET parent_id = sub.parent_id, country_code = sub.country_code, level = 5
FROM (SELECT country_code, osm_id AS parent_id, UNNEST(subareas) AS osm_id FROM :scm.osm_admin WHERE level = 4) AS sub
WHERE a.osm_id = sub.osm_id;

UPDATE :scm.osm_admin a SET parent_id = sub.parent_id, country_code = sub.country_code, level = 6
FROM (SELECT country_code, osm_id AS parent_id, UNNEST(subareas) AS osm_id FROM :scm.osm_admin WHERE level = 5) AS sub
WHERE a.osm_id = sub.osm_id;

UPDATE :scm.osm_admin a SET parent_id = sub.parent_id, country_code = sub.country_code, level = 7
FROM (SELECT country_code, osm_id AS parent_id, UNNEST(subareas) AS osm_id FROM :scm.osm_admin WHERE level = 6) AS sub
WHERE a.osm_id = sub.osm_id;

\echo '\nAdmin: Children'
UPDATE :scm.osm_admin a SET children = sub.children
FROM (SELECT
a1.osm_id, ARRAY_AGG(a2.osm_id) AS children
FROM :scm.osm_admin a1
LEFT JOIN :scm.osm_admin a2 ON (a1.admin_level < a2.admin_level AND ST_Contains(a1.boundary, a2.center))
GROUP BY a1.osm_id) AS sub
WHERE sub.osm_id = a.osm_id;

CREATE INDEX osm_children_idx ON :scm.osm_admin USING GIN(children);


VACUUM ANALYZE :scm.osm_admin;

--\i new/admin_:scm.sql