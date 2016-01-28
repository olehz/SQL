\echo '\nMark as updated'
UPDATE :scm.osm_admin SET nadoloni_updated = 't' WHERE NOT nadoloni_updated;
UPDATE :scm.osm_buildings SET nadoloni_updated = 't' WHERE NOT nadoloni_updated;
UPDATE :scm.osm_point_places SET nadoloni_updated = 't' WHERE NOT nadoloni_updated;
UPDATE :scm.osm_polygon_places SET nadoloni_updated = 't' WHERE NOT nadoloni_updated;

UPDATE :scm.osm_polygon_poi SET nadoloni_updated = 't' WHERE NOT nadoloni_updated;
UPDATE :scm.osm_point_poi SET nadoloni_updated = 't' WHERE NOT nadoloni_updated;
UPDATE :scm.osm_linestring_poi SET nadoloni_updated = 't' WHERE NOT nadoloni_updated;