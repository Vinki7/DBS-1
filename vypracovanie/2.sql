WITH selected_records AS (-- selekcia vsetkych potrebnych dat => redukovanie dalsich dopytov a prace s velkym datasetom
    SELECT
        pl.id AS player_id,
        pl.first_name AS first_name,
        pl.last_name AS last_name,
        pl.is_active AS is_active,
        teams.id AS team_id,
        teams.full_name AS team_name,
        pr.game_id AS game_id,
        pr.score AS score,
        pr.event_msg_type AS event_msg_type,
        pr.player1_id AS player1_id,
        pr.player2_id AS player2_id
    FROM play_records AS pr
    JOIN players AS pl ON pl.id = pr.player1_id OR pl.id = pr.player2_id
    JOIN teams ON teams.id = (
        CASE
            WHEN pl.id = pr.player1_id THEN pr.player1_team_id
            WHEN pl.id = pr.player2_id THEN pr.player2_team_id
        END
    )
    JOIN games ON pr.game_id = games.id
    WHERE games.season_id = {{season_id}}::TEXT--22017,22016,22015,22010
        AND pr.event_msg_type IN (
            'FREE_THROW',
            'FIELD_GOAL_MADE',
            'FIELD_GOAL_MISSED',
            'REBOUND'
        )
),
all_changes AS (-- pocet timov za ktore hrac nastupil
    SELECT 
        sr.player_id AS player_id,
        sr.first_name AS first_name,
        sr.last_name AS last_name,
        sr.is_active AS is_active,
        COUNT(DISTINCT sr.team_id) AS teams_attended
    FROM selected_records AS sr
    GROUP BY sr.player_id, sr.first_name, sr.last_name, sr.is_active
),
top5_changes AS (
    SELECT
        ch.player_id AS player_id,
        ch.first_name AS first_name,
        ch.last_name AS last_name,
        ch.teams_attended AS teams_attended
    FROM all_changes AS ch
    WHERE ch.teams_attended > 1
    ORDER BY teams_attended DESC, ch.is_active DESC, ch.last_name ASC, ch.first_name ASC
    LIMIT 5
),
activity_per_game AS (-- vypocet statistik hraca za jednotlive zapasy
    SELECT
        sr.player_id AS player_id,
        sr.first_name AS first_name,
        sr.last_name AS last_name,
        sr.team_id AS team_id,
        sr.team_name AS team_name,
        sr.game_id AS game_id,
        SUM(
            CASE 
                WHEN sr.event_msg_type = 'FIELD_GOAL_MADE' 
                    AND sr.player_id = sr.player1_id THEN 2
                WHEN sr.event_msg_type = 'FREE_THROW' 
                    AND sr.score IS NOT NULL THEN 1
                ELSE 0
            END
        ) AS total_points,    
        COUNT(
            CASE 
                WHEN sr.event_msg_type = 'FIELD_GOAL_MADE' 
                    AND sr.player_id = sr.player2_id THEN 1  
                ELSE NULL 
            END
        ) AS total_assists
    FROM selected_records AS sr
    JOIN top5_changes AS top5 ON sr.player_id = top5.player_id
    GROUP BY sr.player_id, sr.last_name, sr.first_name, sr.team_id, sr.team_name, sr.game_id
)
SELECT 
    act.player_id AS player_id,
    act.first_name AS first_name,
    act.last_name AS last_name,
    act.team_id AS team_id,
    act.team_name AS "full_name",
    ROUND(AVG(act.total_points)::NUMERIC, 2) AS "PPG",
    ROUND(AVG(act.total_assists)::NUMERIC, 2) AS "APG",
    COUNT(*) AS games
FROM activity_per_game AS act
GROUP BY act.player_id, act.first_name, act.last_name, act.team_id, act.team_name
ORDER BY player_id ASC, team_id ASC;