WITH selected_records AS (
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
player_data AS (
    SELECT 
        pl.player_id,
        pr.event_msg_type,
        pr.game_id,
        pr.season_id
    FROM (
        SELECT
            pl.id AS player_id,
            pl.first_name,
            pl.last_name
        FROM players AS pl
        WHERE pl.first_name ILIKE '{{first_name}}' AND pl.last_name ILIKE '{{last_name}}'--'Jaylen', 'Brown' | 'Lebron', 'James'
    ) pl
    JOIN selected_records AS pr ON pl.player_id = pr.player1_id
),
stats AS (
    SELECT
    ge.season_id,
    ge.game_id,
    ROUND(
        100.00 * COUNT(
            CASE
                WHEN ge.event_msg_type = 'FIELD_GOAL_MADE'
                    THEN 1
            END
        )
        / COUNT(ge.event_msg_type)
    ,2) AS accuracy
    FROM (
        SELECT
            pd.season_id,
            pd.game_id,
            pd.event_msg_type
        FROM (
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
stability AS (
    SELECT
        season_id,
        ROUND(AVG(diff), 2) AS stability
    FROM (
        SELECT
            season_id,
            game_id,
            (
                ABS(accuracy - previous_game_accuracy)
            ) AS diff
        FROM (
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
SELECT
    *
FROM stability
ORDER BY stability ASC, season_id ASC;