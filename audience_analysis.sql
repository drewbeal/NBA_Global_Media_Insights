-- ============================================================
-- NBA Global Media Insights
-- Audience Analysis SQL Pipeline
-- Season: 2025-26
-- Engine: DuckDB
--
-- Purpose:
-- Create a clean, game-level analytical dataset for studying
-- national NBA television audience.
--
-- Source tables registered in DuckDB:
--   master_audience
--   master_schedule
--   dataset2
--   star_absence_wide
-- ============================================================


-- ============================================================
-- 1. CLEAN AUDIENCE DATA
-- ============================================================

CREATE OR REPLACE VIEW audience_clean AS
SELECT
    *,
    
    -- Normalize NBC naming across source datasets
    CASE
        WHEN national_tv IN ('NBC', 'NBC/Peacock', 'NBC | Peacock')
            THEN 'NBC | Peacock'
        ELSE national_tv
    END AS network_clean,

    -- Standardize away-team names
    CASE
        WHEN away_team LIKE 'BOS%' THEN 'BOS'
        WHEN away_team LIKE 'BKN%' THEN 'BKN'
        WHEN away_team LIKE 'NYK%' THEN 'NYK'
        WHEN away_team LIKE 'PHI%' THEN 'PHI'
        WHEN away_team LIKE 'TOR%' THEN 'TOR'
        WHEN away_team LIKE 'CHI%' THEN 'CHI'
        WHEN away_team LIKE 'CLE%' THEN 'CLE'
        WHEN away_team LIKE 'DET%' THEN 'DET'
        WHEN away_team LIKE 'IND%' THEN 'IND'
        WHEN away_team LIKE 'MIL%' THEN 'MIL'
        WHEN away_team LIKE 'ATL%' THEN 'ATL'
        WHEN away_team LIKE 'CHA%' THEN 'CHA'
        WHEN away_team LIKE 'MIA%' THEN 'MIA'
        WHEN away_team LIKE 'ORL%' THEN 'ORL'
        WHEN away_team LIKE 'WAS%' THEN 'WAS'
        WHEN away_team LIKE 'DEN%' THEN 'DEN'
        WHEN away_team LIKE 'MIN%' THEN 'MIN'
        WHEN away_team LIKE 'OKC%' THEN 'OKC'
        WHEN away_team LIKE 'POR%' THEN 'POR'
        WHEN away_team LIKE 'SAC%' THEN 'SAC'
        WHEN away_team LIKE 'PHX%' THEN 'PHX'
        WHEN away_team LIKE 'LAL%' THEN 'LAL'
        WHEN away_team LIKE 'LAC%' THEN 'LAC'
        WHEN away_team LIKE 'GSW%' THEN 'GSW'
        WHEN away_team LIKE 'HOU%' THEN 'HOU'
        WHEN away_team LIKE 'DAL%' THEN 'DAL'
        WHEN away_team LIKE 'MEM%' THEN 'MEM'
        WHEN away_team LIKE 'NOP%' THEN 'NOP'
        WHEN away_team LIKE 'SAS%' THEN 'SAS'
        WHEN away_team LIKE 'UTA%' THEN 'UTA'
        ELSE away_team
    END AS away_team_clean,

    -- Standardize home-team names
    CASE
        WHEN home_team LIKE 'BOS%' THEN 'BOS'
        WHEN home_team LIKE 'BKN%' THEN 'BKN'
        WHEN home_team LIKE 'NYK%' THEN 'NYK'
        WHEN home_team LIKE 'PHI%' THEN 'PHI'
        WHEN home_team LIKE 'TOR%' THEN 'TOR'
        WHEN home_team LIKE 'CHI%' THEN 'CHI'
        WHEN home_team LIKE 'CLE%' THEN 'CLE'
        WHEN home_team LIKE 'DET%' THEN 'DET'
        WHEN home_team LIKE 'IND%' THEN 'IND'
        WHEN home_team LIKE 'MIL%' THEN 'MIL'
        WHEN home_team LIKE 'ATL%' THEN 'ATL'
        WHEN home_team LIKE 'CHA%' THEN 'CHA'
        WHEN home_team LIKE 'MIA%' THEN 'MIA'
        WHEN home_team LIKE 'ORL%' THEN 'ORL'
        WHEN home_team LIKE 'WAS%' THEN 'WAS'
        WHEN home_team LIKE 'DEN%' THEN 'DEN'
        WHEN home_team LIKE 'MIN%' THEN 'MIN'
        WHEN home_team LIKE 'OKC%' THEN 'OKC'
        WHEN home_team LIKE 'POR%' THEN 'POR'
        WHEN home_team LIKE 'SAC%' THEN 'SAC'
        WHEN home_team LIKE 'PHX%' THEN 'PHX'
        WHEN home_team LIKE 'LAL%' THEN 'LAL'
        WHEN home_team LIKE 'LAC%' THEN 'LAC'
        WHEN home_team LIKE 'GSW%' THEN 'GSW'
        WHEN home_team LIKE 'HOU%' THEN 'HOU'
        WHEN home_team LIKE 'DAL%' THEN 'DAL'
        WHEN home_team LIKE 'MEM%' THEN 'MEM'
        WHEN home_team LIKE 'NOP%' THEN 'NOP'
        WHEN home_team LIKE 'SAS%' THEN 'SAS'
        WHEN home_team LIKE 'UTA%' THEN 'UTA'
        ELSE home_team
    END AS home_team_clean

FROM master_audience;


-- ============================================================
-- 2. CREATE GAME-LEVEL AUDIENCE TABLE
-- ============================================================

CREATE OR REPLACE TABLE game_audience AS
SELECT
    a.match_key,
    CAST(a.date AS DATE) AS game_date,

    a.away_team_clean AS away_team,
    a.home_team_clean AS home_team,

    a.viewership AS audience_viewers,
    ROUND(a.viewership / 1000000, 3) AS audience_millions,

    a.network_clean AS network,

    s.season_type,
    s.tip_et,

    DAYOFWEEK(CAST(a.date AS DATE)) AS day_of_week_num,
    DAYNAME(CAST(a.date AS DATE)) AS day_of_week,

    EXTRACT(
        HOUR FROM CAST(s.tip_et AS TIMESTAMP)
    ) AS tip_hour,

    a.measurement_source,
    a.source AS audience_source,
    a.source_url

FROM audience_clean a

LEFT JOIN master_schedule s
    ON a.match_key = s.match_key

WHERE a.measurement_type = 'average'
  AND a.measurement_scope = 'game';


-- ============================================================
-- 3. SELECT ONE AUDIENCE OBSERVATION PER GAME
--    Measurement hierarchy:
--      1. Nielsen Big Data
--      2. Nielsen Panel
--      3. Other / unspecified
-- ============================================================

CREATE OR REPLACE TABLE game_audience_clean AS

WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY match_key
            ORDER BY
                CASE
                    WHEN measurement_source = 'Nielsen Big Data' THEN 1
                    WHEN measurement_source = 'Nielsen Panel' THEN 2
                    ELSE 3
                END,
                audience_source
        ) AS rn

    FROM game_audience
)

SELECT
    match_key,
    game_date,

    away_team,
    home_team,

    audience_viewers,
    audience_millions,

    network,
    season_type,
    tip_et,

    day_of_week_num,
    day_of_week,
    tip_hour,

    measurement_source,
    audience_source,
    source_url

FROM ranked
WHERE rn = 1;


-- ============================================================
-- 4. CORRECT MISSING NETWORK VALUES
-- ============================================================

CREATE OR REPLACE TABLE game_audience_clean AS

SELECT
    *,
    CASE
        WHEN match_key = '2025-12-30_DET_LAL' THEN 'NBC | Peacock'
        WHEN match_key = '2026-01-07_BOS_DEN' THEN 'ESPN'
        WHEN match_key = '2026-01-16_CLE_PHI' THEN 'ESPN'
        WHEN match_key = '2026-01-30_ORL_TOR' THEN 'ESPN'
        WHEN match_key = '2026-01-30_DET_GSW' THEN 'ESPN'
        WHEN match_key = '2026-02-11_GSW_SAS' THEN 'ESPN'
        WHEN match_key = '2026-02-25_DET_OKC' THEN 'ESPN'
        WHEN match_key = '2026-03-01_BOS_PHI' THEN 'NBC | Peacock'
        WHEN match_key = '2026-03-28_DET_MIN' THEN 'ABC'
        WHEN match_key = '2026-04-01_BOS_MIA' THEN 'ESPN'
        WHEN match_key = '2026-04-08_ATL_CLE' THEN 'ESPN'
        WHEN match_key = '2026-04-08_DAL_PHX' THEN 'ESPN'
        ELSE network
    END AS network_fixed

FROM game_audience_clean;


-- Replace the original network column with the corrected value

CREATE OR REPLACE TABLE game_audience_clean AS

SELECT
    match_key,
    game_date,
    away_team,
    home_team,
    audience_viewers,
    audience_millions,
    network_fixed AS network,
    season_type,
    tip_et,
    day_of_week_num,
    day_of_week,
    tip_hour,
    measurement_source,
    audience_source,
    source_url

FROM game_audience_clean;


-- ============================================================
-- 5. CREATE GAME FEATURE TABLE
-- ============================================================

CREATE OR REPLACE TABLE game_features AS

SELECT
    match_key,
    game_date,
    away_team,
    home_team,
    network,
    season_type,
    tip_et,
    day_of_week,
    tip_hour,
    audience_millions,

    -- Calendar / timing features
    CASE
        WHEN day_of_week IN ('Saturday', 'Sunday') THEN 1
        ELSE 0
    END AS is_weekend,

    CASE
        WHEN tip_hour >= 18 AND tip_hour < 22 THEN 1
        ELSE 0
    END AS is_prime_time,

    CASE
        WHEN tip_hour < 18 THEN 1
        ELSE 0
    END AS is_early_game,

    -- High-exposure matchup indicator
    CASE
        WHEN away_team IN ('LAL', 'NYK', 'OKC', 'GSW', 'DAL')
          OR home_team IN ('LAL', 'NYK', 'OKC', 'GSW', 'DAL')
        THEN 1
        ELSE 0
    END AS has_high_exposure_team

FROM game_audience_clean;


-- ============================================================
-- 6. CREATE INDIVIDUAL HIGH-EXPOSURE TEAM FLAGS
-- ============================================================

CREATE OR REPLACE TABLE game_features AS

SELECT
    *,

    CASE
        WHEN away_team = 'LAL' OR home_team = 'LAL' THEN 1
        ELSE 0
    END AS has_lal,

    CASE
        WHEN away_team = 'NYK' OR home_team = 'NYK' THEN 1
        ELSE 0
    END AS has_nyk,

    CASE
        WHEN away_team = 'OKC' OR home_team = 'OKC' THEN 1
        ELSE 0
    END AS has_okc,

    CASE
        WHEN away_team = 'GSW' OR home_team = 'GSW' THEN 1
        ELSE 0
    END AS has_gsw,

    CASE
        WHEN away_team = 'DAL' OR home_team = 'DAL' THEN 1
        ELSE 0
    END AS has_dal,

    (
        CASE WHEN away_team = 'LAL' OR home_team = 'LAL' THEN 1 ELSE 0 END +
        CASE WHEN away_team = 'NYK' OR home_team = 'NYK' THEN 1 ELSE 0 END +
        CASE WHEN away_team = 'OKC' OR home_team = 'OKC' THEN 1 ELSE 0 END +
        CASE WHEN away_team = 'GSW' OR home_team = 'GSW' THEN 1 ELSE 0 END +
        CASE WHEN away_team = 'DAL' OR home_team = 'DAL' THEN 1 ELSE 0 END
    ) AS high_exposure_team_count

FROM game_features;


-- ============================================================
-- 7. EVENT FLAGS
-- ============================================================

CREATE OR REPLACE TABLE game_features AS

SELECT
    *,
    
    CASE
        WHEN game_date = '2025-10-21' THEN 1
        ELSE 0
    END AS is_opening_night,

    CASE
        WHEN game_date = '2025-12-25' THEN 1
        ELSE 0
    END AS is_christmas,

    CASE
        WHEN season_type = 'NBA Cup' THEN 1
        ELSE 0
    END AS is_nba_cup

FROM game_features;


-- ============================================================
-- 8. SPLIT NBA CUP INTO FINAL VS. OTHER
-- ============================================================

CREATE OR REPLACE TABLE game_features AS

SELECT
    *,
    
    CASE
        WHEN is_nba_cup = 1
         AND match_key = '2025-12-16_NYK_SAS'
        THEN 1
        ELSE 0
    END AS is_nba_cup_final,

    CASE
        WHEN is_nba_cup = 1
         AND match_key <> '2025-12-16_NYK_SAS'
        THEN 1
        ELSE 0
    END AS is_nba_cup_other

FROM game_features;


-- ============================================================
-- 9. INTEGRATE STAR-PLAYER ABSENCE DATA
--
-- star_absence_wide is created upstream in Python from
-- Basketball-Reference game logs and registered with DuckDB.
-- It contains one row per game.
-- ============================================================

ALTER TABLE game_features
ADD COLUMN IF NOT EXISTS star_absence_count INTEGER;

ALTER TABLE game_features
ADD COLUMN IF NOT EXISTS star_absence_team_count INTEGER;


UPDATE game_features AS g

SET
    star_absence_count = s.star_absence_count,
    star_absence_team_count = s.star_absence_team_count

FROM star_absence_wide AS s

WHERE g.match_key = s.match_key;


-- ============================================================
-- 10. FINAL ANALYTICAL DATASET
-- ============================================================

SELECT
    match_key,
    game_date,
    away_team,
    home_team,
    network,
    season_type,
    tip_et,
    day_of_week,
    tip_hour,
    audience_millions,

    -- Matchup exposure
    high_exposure_team_count,
    has_lal,
    has_nyk,
    has_okc,
    has_gsw,
    has_dal,

    -- Timing
    is_weekend,
    is_prime_time,
    is_early_game,

    -- Events
    is_opening_night,
    is_christmas,
    is_nba_cup_other,
    is_nba_cup_final,

    -- Player availability
    star_absence_count,
    star_absence_team_count

FROM game_features

ORDER BY game_date;