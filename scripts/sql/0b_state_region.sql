-- Static reference: US state -> Census region / division, for geography filters (#10).
-- Covers the 50 states + DC (Census), US territories (Outlying Areas), and non-US (Other).
-- state is the 2-letter code as it appears in the catalog / IPEDS.

${CONFIG}

DROP TABLE IF EXISTS state_region;
CREATE TABLE state_region (state VARCHAR PRIMARY KEY, region VARCHAR, division VARCHAR);
INSERT INTO state_region VALUES
  -- Northeast: New England
  ('CT','Northeast','New England'),('ME','Northeast','New England'),('MA','Northeast','New England'),
  ('NH','Northeast','New England'),('RI','Northeast','New England'),('VT','Northeast','New England'),
  -- Northeast: Middle Atlantic
  ('NJ','Northeast','Middle Atlantic'),('NY','Northeast','Middle Atlantic'),('PA','Northeast','Middle Atlantic'),
  -- Midwest: East North Central
  ('IL','Midwest','East North Central'),('IN','Midwest','East North Central'),('MI','Midwest','East North Central'),
  ('OH','Midwest','East North Central'),('WI','Midwest','East North Central'),
  -- Midwest: West North Central
  ('IA','Midwest','West North Central'),('KS','Midwest','West North Central'),('MN','Midwest','West North Central'),
  ('MO','Midwest','West North Central'),('NE','Midwest','West North Central'),('ND','Midwest','West North Central'),
  ('SD','Midwest','West North Central'),
  -- South: South Atlantic
  ('DE','South','South Atlantic'),('DC','South','South Atlantic'),('FL','South','South Atlantic'),
  ('GA','South','South Atlantic'),('MD','South','South Atlantic'),('NC','South','South Atlantic'),
  ('SC','South','South Atlantic'),('VA','South','South Atlantic'),('WV','South','South Atlantic'),
  -- South: East South Central
  ('AL','South','East South Central'),('KY','South','East South Central'),('MS','South','East South Central'),
  ('TN','South','East South Central'),
  -- South: West South Central
  ('AR','South','West South Central'),('LA','South','West South Central'),('OK','South','West South Central'),
  ('TX','South','West South Central'),
  -- West: Mountain
  ('AZ','West','Mountain'),('CO','West','Mountain'),('ID','West','Mountain'),('MT','West','Mountain'),
  ('NV','West','Mountain'),('NM','West','Mountain'),('UT','West','Mountain'),('WY','West','Mountain'),
  -- West: Pacific
  ('AK','West','Pacific'),('CA','West','Pacific'),('HI','West','Pacific'),('OR','West','Pacific'),('WA','West','Pacific'),
  -- US territories / outlying areas
  ('PR','Outlying Areas','Outlying Areas'),('GU','Outlying Areas','Outlying Areas'),
  ('VI','Outlying Areas','Outlying Areas'),('AS','Outlying Areas','Outlying Areas'),
  ('MP','Outlying Areas','Outlying Areas'),
  -- Non-US (stray catalog value)
  ('CAN','Other','Other');

CREATE INDEX idx_state_region ON state_region (state);

-- DQ: every catalog state must map to a region (unmapped_states should be 0).
SELECT 'state_region coverage' AS metric,
       COUNT(*)                                   AS catalog_states,
       COUNT(*) FILTER (WHERE sr.state IS NULL)    AS unmapped_states
FROM (SELECT DISTINCT state FROM comprehensive_data WHERE state IS NOT NULL) c
LEFT JOIN state_region sr ON c.state = sr.state;
