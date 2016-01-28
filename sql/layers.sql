\echo '\nIntersection layer'

DROP TABLE IF EXISTS import.inter CASCADE;
CREATE TABLE import.inter AS SELECT row_number() OVER () id,
    CASE WHEN array_length(boundary_id, 1) = 1 THEN 0 ELSE 1 END AS color,
    s.name,
    geometry,
    ST_Boundary(boundary) AS boundary,
    ST_Intersection(geometry, ST_Boundary(boundary)) AS points
FROM osm_streets s
INNER JOIN osm_places p ON s.place_id = p.osm_id
WHERE crossed_boundary;
CREATE INDEX inter_geometry ON import.inter USING GIST(geometry);
CREATE INDEX inter_boundary ON import.inter USING GIST(boundary);
CREATE INDEX inter_points ON import.inter USING GIST(points);

----------------------

DROP TABLE IF EXISTS import.test CASCADE;

CREATE TABLE import.test AS SELECT row_number() OVER () id,
place_id,
name,
addr_suburb,
ST_Union(ST_buffer(geometry, 800)) AS buffer,
ST_Union(geometry) AS line
FROM osm_streets WHERE segments_gaps
GROUP BY place_id, addr_suburb, name
HAVING st_geometrytype(ST_Union(ST_buffer(geometry, 800))) = 'ST_MultiPolygon';

CREATE INDEX test_buffer ON import.test USING GIST(buffer);
CREATE INDEX test_line ON import.test USING GIST(line);

-----------------------------

DROP TABLE IF EXISTS import.test2 CASCADE;

CREATE TABLE import.test2 AS SELECT
    id, name, center, ST_Collect(the_geom) AS geometry FROM (
        SELECT
          id,
          name,
          ST_MakeLine(center, point) AS the_geom,
          center
        FROM (
            SELECT id, name, ST_Centroid(the_geom) AS center, (ST_DUMP(the_geom)).geom AS point
            FROM (
                SELECT id, name, ST_Collect(the_geom) AS the_geom
                FROM (
                    SELECT id, name, ST_PointOnSurface((ST_DUMP(buffer)).geom) AS the_geom FROM import.test
                ) AS sub1
              GROUP BY id, name
            ) AS sub2
        ) AS sub3
    ) AS sub4
    GROUP BY id, name, center;

CREATE INDEX test_geometry ON import.test2 USING GIST(geometry);
CREATE INDEX test_center ON import.test2 USING GIST(center);


--------------------------------------

DROP TABLE IF EXISTS import.bug_places CASCADE;
CREATE TABLE import.bug_places AS SELECT p1.id AS id,
ST_Collect(ST_MakeLine(p1.centre, p2.centre)) AS lines
FROM osm_places p1
INNER JOIN osm_places p2 ON ST_Contains(p1.boundary, p2.centre)
WHERE p1.id != p2.id AND p1.place IN ('city', 'town', 'village', 'hamlet') AND p2.place IN ('city', 'town', 'village', 'hamlet')
GROUP BY p1.id;
CREATE INDEX bug_places_lines ON import.bug_places USING GIST(lines);

--------------------------------------------

\echo '\ndbl_buildings'

DROP TABLE IF EXISTS import.dbl_buildings CASCADE;
CREATE TABLE import.dbl_buildings AS 
SELECT id, addr_housenumber, geometry, ST_MakeLine(ST_CENTROID(geometry), ST_CENTROID((ST_DUMP(geometry)).geom)) AS line FROM (
SELECT s.id AS id, b.addr_housenumber, ST_Collect(geometry) AS geometry FROM (
SELECT id, ARRAY(
    SELECT buildings[i]
    FROM generate_series(1, array_length(numbers, 1)) AS i
    WHERE numbers[i] = ANY(dbl)
  ) AS osm_ids 
FROM (
SELECT id, buildings, numbers, ARRAY(SELECT a FROM (SELECT UNNEST(numbers) AS a) dbl GROUP BY a HAVING COUNT(a) > 1) AS dbl
FROM osm_streets
WHERE numbers IS NOT NULL
AND (array_length(numbers, 1) != array_length(ARRAY(SELECT DISTINCT UNNEST(numbers)), 1))
) sub) s
INNER JOIN osm_buildings b ON
b.street_id = s.id AND
b.osm_id = ANY(s.osm_ids)
GROUP BY s.id, b.addr_housenumber
) foo;

CREATE INDEX dbl_buildings_geometry ON import.dbl_buildings USING GIST(geometry);
CREATE INDEX dbl_buildings_line ON import.dbl_buildings USING GIST(line);


--------------------------------------------------

DROP TABLE IF EXISTS import.unplaced CASCADE;
CREATE TABLE import.unplaced AS SELECT r.osm_id AS id, r.geometry AS line FROM osm_roads r
LEFT JOIN (SELECT DISTINCT UNNEST(osm_ids) AS osm_id FROM osm_streets) AS s ON r.osm_id = s.osm_id
WHERE s.osm_id IS NULL;

CREATE INDEX unplaced_line ON import.unplaced USING GIST(line);

DROP TABLE IF EXISTS import.unaddressed CASCADE;
CREATE TABLE import.unaddressed AS SELECT b.osm_id AS id, ST_Centroid(b.geometry) AS center FROM osm_buildings b
LEFT JOIN (SELECT DISTINCT UNNEST(buildings) AS osm_id FROM osm_streets) AS s ON b.osm_id = s.osm_id
WHERE s.osm_id IS NULL;

CREATE INDEX unaddressed_center ON import.unaddressed USING GIST(center);



\echo '\nVACUUM'
VACUUM FULL ANALYZE;

SELECT pg_size_pretty(pg_database_size(current_database())) AS size_pretty;