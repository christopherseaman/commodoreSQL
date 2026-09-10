-- Canonical Material Costs rows for the stable 10% section-cluster sample (#81).
-- Membership is md5-prefix64-mod10-v1 over the canonical material section key.
SELECT material.*
FROM master_material material
WHERE CAST('0x' || LEFT(md5(material.section_id), 16) AS UBIGINT) % 10 = 0;
