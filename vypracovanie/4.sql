-- Active: 1740996226560@@localhost@5433@nba@public
WITH selected_records as (
    SELECT
        pl.id AS player_id,
        pr.player1_id,
        pr.player2_id,
        pr.event_number,
        pr.event_msg_type AS event_type,
        pr.score,
        pr.game_id
    FROM players AS pl
    JOIN play_records AS pr ON pl.id = pr.player1_id OR pl.id = pr.player2_id
    JOIN games ON games.id = pr.game_id
    WHERE 
        games.season_id = '22018'--{{season_id}}
        AND
        pr.event_msg_type IN ('FIELD_GOAL_MADE', 'FREE_THROW', 'REBOUND')
    ORDER BY pr.game_id ASC, pr.player1_id ASC
),
game_statistics AS (
    SELECT
        sr.player_id AS player_id,
        sr.game_id AS game_id,
        (SUM(
            CASE 
                WHEN (sr.event_type = 'FIELD_GOAL_MADE' AND sr.player_id = sr.player1_id) 
                    THEN 2
                ELSE 0
            END
        )
        +
        COUNT(
            CASE 
                WHEN (sr.event_type = 'FREE_THROW' AND sr.player_id = sr.player1_id AND sr.score IS NOT NULL) 
                    THEN 1
            END
        )) AS points,
        COUNT(
            CASE
                WHEN (sr.event_type = 'FIELD_GOAL_MADE' AND sr.player_id = sr.player2_id)
                    THEN 1
            END
        ) AS assists_made,
        COUNT(
            CASE
                WHEN (sr.event_type = 'REBOUND')
                    THEN 1
            END
        ) AS rebounds_made
    FROM selected_records AS sr
    GROUP BY sr.game_id, sr.player_id
),
is_td AS (
    SELECT
        game_id,
        player_id,
        CASE
            WHEN points >= 10 AND assists_made >= 10 AND rebounds_made >= 10
                THEN 1
            ELSE 0
        END AS is_triple_double
    FROM game_statistics
),
streak_groups AS (
    SELECT
        st.player_id,
        st.game_id,
        st.is_triple_double,
        st.streak_start,
        SUM(st.streak_start) OVER (PARTITION BY st.player_id ORDER BY st.game_id) AS streak_group
    FROM (
        SELECT 
            pl.player_id,
            td.game_id,
            td.is_triple_double,
            CASE 
                WHEN td.is_triple_double = 1
                AND LAG(td.is_triple_double, 1, 0) OVER (PARTITION BY pl.player_id ORDER BY td.game_id) = 0 
                    THEN 1
                ELSE 0
            END AS streak_start

        FROM (
            SELECT DISTINCT player_id
            FROM is_td
            GROUP BY game_id, player_id
            HAVING SUM(is_triple_double) > 0
            ORDER BY player_id ASC
        ) AS pl
        JOIN is_td AS td ON td.player_id = pl.player_id
    ) AS st
)
SELECT
    player_id,
    MAX(longest_streak) AS longest_streak
FROM (
    SELECT
        sg.player_id,
        sg.streak_group,
        COUNT(*) AS longest_streak
    FROM streak_groups AS sg
    WHERE sg.is_triple_double = 1
    GROUP BY sg.player_id, sg.streak_group
    ORDER BY sg.player_id DESC, sg.streak_group ASC
)
GROUP BY player_id
ORDER BY longest_streak DESC, player_id ASC;
,
-- streaks AS (
--     SELECT
--         pl.player_id,
--         td.game_id,
--         td.is_triple_double,
--         CASE 
--             WHEN td.is_triple_double = 1 
--             AND LAG(td.is_triple_double, 1, 0) OVER (PARTITION BY pl.player_id ORDER BY td.game_id) = 0
--                 THEN 1
--             ELSE 0  
--             END AS streak_start
--     FROM (
--         SELECT DISTINCT player_id
--         FROM is_td
--         GROUP BY game_id, player_id
--         HAVING SUM(is_triple_double) > 0
--         ORDER BY player_id ASC
--     ) AS pl
--     JOIN is_td AS td ON td.player_id = pl.player_id
-- ),
-- grouped_streaks AS (
--     SELECT
--         player_id,
--         game_id,
--         is_triple_double,
--         streak_start,
--         SUM(streak_start) OVER (PARTITION BY player_id ORDER BY game_id) AS streak_group
--     FROM streaks
-- )
-- SELECT
--     player_id,
--     MAX(longest_streak) AS longest_streak
-- FROM (
--     SELECT
--         player_id,
--         streak_group,
--         COUNT(*) AS longest_streak
--     FROM grouped_streaks
--     WHERE is_triple_double = 1
--     GROUP BY player_id, streak_group
--     ORDER BY player_id DESC, streak_group ASC
-- )
-- GROUP BY player_id
-- ORDER BY longest_streak DESC, player_id ASC

