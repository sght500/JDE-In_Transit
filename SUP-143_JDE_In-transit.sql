-- Name:        SUP-143_JDE_In-transit
-- Description: This view lists all the In-Transit inventory in the Amway Network at detail level.
--              It provides the item, lot, source location, shipto location, sales order and status.
-- ============================================================================================================================
-- Jira:      SUP-143
-- URL:       https://amwaycloud.atlassian.net/browse/SUP-143
-- Author:    Mario Montoya
-- Created:   01/26/2024

-- Change History:
-- ------------|-----|---------------------|--------------------------------------------------------
-- Date        |Ver# |Name                 |Remarks
-- ------------|-----|---------------------|--------------------------------------------------------
-- 01/26/2024  | 1.0 |Mario Montoya        |Initial development. Translation from Oracle query. Date fixed.
-- 01/31/2024  | 1.1 |Mario Montoya        |Created the view in "gcp-vc-planning.scdw_curated_reports" as requested by Tumul.
-- 02/23/2024  | 1.2 |Mario Montoya        |Productionizing. Using amw-dna-ingestion-prd.jde.f4211 and amw-dna-coe-curated.
-- 03/07/2024  | 1.3 |Mario Montoya        |Getting base_item from amw-dna-ingestion-prd.jde.f4101
-- 03/08/2024  | 1.4 |Mario Montoya        |Getting item_root from gcp-vc-planning-prod.pricing.pricing_split_item_numbers
-- 03/08/2024  | 1.5 |Mario Montoya        |Applying Regular Expression sustitution in Item and Item Description.
-- ============================================================================================================================
-- Input Tables
--      amw-dna-ingestion-prd.jde.f4211   - Sales Order Detail File
--      amw-dna-ingestion-prd.jde.f0006   - Business Unit Master
--      amw-dna-ingestion-prd.jde.f4101   - Item Master
--      gcp-vc-planning-prod.pricing.pricing_split_item_numbers   - Item Construct (Root, Base, Revision) - Nick Seguin
-- Output View
--      amw-dna-coe-curated.jde.jde_intransit
-- ============================================================================================================================
CREATE OR REPLACE VIEW amw-dna-coe-curated.jde.jde_intransit AS
SELECT
  TRIM(f.root_item) AS item_root,
  d.IMSRTX AS base_item,  
  REGEXP_REPLACE(TRIM(a.SDLITM), "(.*)( )([A-Z])$", '\\1\\3') itm,
  REGEXP_REPLACE(TRIM(a.SDDSC1), " +", " ") itm_desc,
  a.SDDOCO AS sls_ordno,
  TRIM(a.SDDCTO) AS sls_ordtype,
  CAST(a.SDSOQS AS INT64)/100 AS shipped_qty,
  TRIM(a.SDLOTN) AS lot,
  TRIM(a.SDMOT) AS freight_code,
  CASE TRIM(a.SDMOT)
    WHEN '1' THEN 'Air'
    WHEN '2' THEN 'Truck'
    WHEN '5' THEN 'Sea'
  ELSE
    'Unknown'
  END AS freight_desc,
  TRIM(a.SDMCU) AS shipfrom_code,
  TRIM(b.mcdc) AS shipfrom_desc,
  a.SDAN8 AS shipto_code,
  TRIM(c.mcdc) AS shipto_desc,
  DATE_ADD(DATE(CAST ( CAST(SDADDJ/1000 AS INT64) + 1900 AS STRING) || '-01-01'), 
    INTERVAL MOD(SDADDJ, 1000)-1 DAY) AS act_shipdate,
  DATE_ADD(DATE(CAST ( CAST(SDDRQJ/1000 AS INT64) + 1900 AS STRING) || '-01-01'), 
    INTERVAL MOD(SDDRQJ, 1000)-1 DAY) AS eta,
  DATE_ADD(DATE(CAST ( CAST(SDOPDJ/1000 AS INT64) + 1900 AS STRING) || '-01-01'), 
    INTERVAL MOD(SDOPDJ, 1000)-1 DAY) AS prom_date,
  TRIM(a.SDPRP1) AS value_chain,
  TRIM(a.SDLTTR) AS last_status,
  TRIM(a.SDNXTR) AS next_status
FROM
  amw-dna-ingestion-prd.jde.f4211 a
JOIN
  amw-dna-ingestion-prd.jde.f0006 b
    ON a.SDMCU=b.mcmcu
JOIN
  amw-dna-ingestion-prd.jde.f0006 c
    ON CAST(a.SDAN8 AS STRING)=TRIM(c.mcmcu)
JOIN
  amw-dna-ingestion-prd.jde.f4101 d
    ON a.SDLITM = d.IMLITM
JOIN
  gcp-vc-planning-prod.pricing.pricing_split_item_numbers f
    ON TRIM(a.SDLITM) = f.item
WHERE
  1=1
  AND a.SDMOT IS NOT NULL
  AND a.SDADDJ <> 0
  AND a.SDPRP1 <> 'CAT'
  AND a.SDLTTR >= '570'
  AND a.SDNXTR <= '584'
