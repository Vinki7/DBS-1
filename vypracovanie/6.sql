WITH selected_records AS (-- vyber zaznamov, ktorych typ sezony spada pod 'Regular Season'
    SELECT
        pr.player1_id,
        pr.event_msg_type,
        g.game_id,
        g.season_id
    FROM (
        SELECT
            g.id AS game_id,
            g.season_id
        FROM games AS g
        WHERE g.season_type = 'Regular Season'
    ) AS g
    JOIN play_records AS pr ON pr.game_id = g.game_id
),
player_data AS (-- vyber dat pre daneho hraca
    SELECT 
        pl.player_id,
        pr.event_msg_type,
        pr.game_id,
        pr.season_id
    FROM (-- vyber konkretneho hraca podla mena a priezviska
        SELECT
            pl.id AS player_id,
            pl.first_name,
            pl.last_name
        FROM players AS pl
        WHERE pl.first_name ILIKE 'Lebron' AND pl.last_name ILIKE 'james'--'Jaylen', 'Brown' | 'Lebron', 'James' | '{{first_name}}' AND pl.last_name ILIKE '{{last_name}}'
    ) pl
    JOIN selected_records AS pr ON pl.player_id = pr.player1_id
),
stats AS (-- vypocet presnosti striel hraca
    SELECT
    ge.season_id,
    ge.game_id,
    (100.00 * COUNT(
            CASE
                WHEN ge.event_msg_type = 'FIELD_GOAL_MADE'
                    THEN 1
            END
        )
        / COUNT(ge.event_msg_type)
    ) AS accuracy
    FROM (-- vyber dat pre sezony, v ktorych hrac odohral aspon 50 zapasov
        SELECT
            pd.season_id,
            pd.game_id,
            pd.event_msg_type
        FROM (-- vyber len tych sezon, kde hrac odohral aspon 50 zapasov
            SELECT 
                pd.season_id
                FROM player_data AS pd
                GROUP BY pd.season_id
                HAVING COUNT(DISTINCT pd.game_id) >= 50
            ) AS seasons
        JOIN player_data AS pd ON seasons.season_id = pd.season_id
    ) AS ge
    WHERE ge.event_msg_type IN ('FIELD_GOAL_MADE', 'FIELD_GOAL_MISSED')
    GROUP BY ge.game_id, ge.season_id
),
stability AS (-- vypocet stability hraca pre kazdu sezonu
    SELECT
        season_id,
        ROUND(AVG(diff), 2) AS stability
    FROM (-- vypocet rozdielu presnosti striel medzi dvomi po sebe iducimi zapasmi
        SELECT
            season_id,
            game_id,
            (
                ABS(accuracy - previous_game_accuracy)
            ) AS diff
        FROM (-- nacitanie presnosti striel z predchadzajuceho zapasu pre kazdu hru
            SELECT
                stats.season_id,
                stats.game_id,
                stats.accuracy,
            LAG(stats.accuracy, 1, stats.accuracy) 
            OVER (
                PARTITION BY stats.season_id
                ORDER BY stats.game_id ASC
            ) AS previous_game_accuracy
            FROM stats
            ORDER BY stats.season_id ASC, stats.game_id ASC
        )
    ) AS differences
    GROUP BY season_id
)
SELECT -- vypis stability hraca pre kazdu sezonu
    st.season_id,
    st.stability
FROM stability AS st
ORDER BY stability ASC, season_id ASC;