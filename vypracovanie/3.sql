WITH event_data AS (-- selekcia potrebnych dat a konverzia score_margin v jednom kroku
    SELECT
        pr.player1_id AS player_id,
        pl.first_name AS first_name,
        pl.last_name AS last_name,
        pr.game_id AS game_id,
        pr.player1_team_id AS team_id,
        pr.event_msg_type AS event_type,
        pr.event_number AS event_number,
        pr.score AS score,
        CASE 
            WHEN pr.score_margin <> 'TIE' THEN pr.score_margin::INTEGER 
            WHEN pr.score_margin = 'TIE' THEN 0 
            ELSE NULL
        END AS score_margin
    FROM play_records AS pr
    JOIN players AS pl ON pl.id = pr.player1_id
    WHERE pr.game_id = {{game_id}}--21701185, 21701180
    ORDER BY pr.event_number ASC
),
game_players AS (-- vyber vsetkych hracov, ktori sa zucastnili daneho zapasu
    SELECT DISTINCT
        ed.player_id AS player_id,
        ed.first_name AS first_name,
        ed.last_name AS last_name,
        ed.game_id AS game_id,
        ed.team_id AS team_id
    FROM event_data AS ed
    ORDER BY ed.team_id
),
successfull_shots AS (-- vypocet poctu bodov ziskanych v jednotlivych eventoch
    SELECT
        ed.player_id AS player_id,
        ed.first_name AS first_name,
        ed.last_name AS last_name,
        ed.game_id AS game_id,
        ed.team_id AS team_id,
        ed.event_type AS event_type,
        ed.event_number AS event_number,
        ed.score AS score,
        ABS(
            COALESCE(
                LAG(ed.score_margin) 
                OVER (
                    ORDER BY ed.event_number ASC
                )
            , 0)
            -
            ed.score_margin
        ) AS points_scored
    FROM event_data AS ed
    WHERE ed.score IS NOT NULL
),
shots_missed AS (-- vypocet poctu neuspesnych pokusov
    SELECT
        ed.player_id AS player_id,
        ed.team_id AS team_id,
        SUM(
            CASE 
                WHEN (ed.event_type = 'FIELD_GOAL_MISSED' AND ed.score IS NULL) 
                    THEN 1
                ELSE 0
            END
        ) AS missed_shots,
        SUM(
            CASE 
                WHEN (ed.event_type = 'FREE_THROW' AND ed.score IS NULL) 
                    THEN 1
                ELSE 0
            END
        ) AS missed_free_throws
    FROM event_data AS ed
    GROUP BY ed.player_id, ed.team_id
),
point_statistics AS (-- finalizacia statistik bodov
    SELECT
        gp.player_id AS player_id,
        gp.team_id AS team_id,
        COALESCE(SUM(ss.points_scored), 0) AS total_points_scored,
        SUM(
            CASE 
                WHEN ss.points_scored = 2 
                    THEN 1
                ELSE 0
            END
        ) AS two_points_made,
        SUM(
            CASE 
                WHEN ss.points_scored = 3 
                    THEN 1
                ELSE 0
            END
        ) AS three_points_made,
        SUM(
            CASE 
                WHEN ss.points_scored = 1 
                    THEN 1
                ELSE 0
            END
        ) AS free_throws_made
    FROM game_players AS gp
    LEFT JOIN successfull_shots AS ss ON ss.player_id = gp.player_id
    GROUP BY gp.player_id, gp.team_id
)
SELECT 
    raw_data.player_id AS player_id,
    raw_data.first_name AS first_name,
    raw_data.last_name AS last_name,
    raw_data.points AS points,
    raw_data.two_points_made AS "2PM",
    raw_data.three_points_made AS "3PM",
    raw_data.missed_shots AS missed_shots,
    raw_data.shooting_percentage AS shooting_percentage,
    raw_data.free_throws_made AS "FTM",
    raw_data.missed_free_throws AS missed_free_throws,
    raw_data.ft_percentage AS "FT_percentage"
FROM (-- vypocet finalnych statistik hracov
    SELECT 
        gp.player_id AS player_id,
        gp.first_name AS first_name,
        gp.last_name AS last_name,
        ps.total_points_scored AS points,
        ps.two_points_made AS two_points_made,
        ps.three_points_made AS three_points_made,
        sm.missed_shots AS missed_shots,
        ROUND(
            CASE 
                WHEN (ps.two_points_made + ps.three_points_made + sm.missed_shots) = 0 
                    THEN CAST(0 AS DECIMAL)
                ELSE 
                    (CAST(ps.two_points_made + ps.three_points_made AS DECIMAL) 
                    / 
                    CAST(ps.two_points_made + ps.three_points_made + sm.missed_shots AS DECIMAL)) * 100
            END
        , 2) AS shooting_percentage,
        ps.free_throws_made AS free_throws_made,
        sm.missed_free_throws AS missed_free_throws,
        ROUND(
            CASE 
                WHEN (ps.free_throws_made + sm.missed_free_throws) = 0 
                    THEN CAST(0 AS DECIMAL)
                ELSE 
                    (CAST(ps.free_throws_made AS DECIMAL) 
                    / 
                    CAST(ps.free_throws_made + sm.missed_free_throws AS DECIMAL)) * 100
            END
        , 2) AS ft_percentage
    FROM game_players as gp
    JOIN point_statistics AS ps ON ps.player_id = gp.player_id
    JOIN shots_missed AS sm ON sm.player_id = gp.player_id
) AS raw_data
ORDER BY 
    raw_data.points DESC, 
    raw_data.shooting_percentage DESC, 
    raw_data.ft_percentage DESC,
    raw_data.player_id ASC;