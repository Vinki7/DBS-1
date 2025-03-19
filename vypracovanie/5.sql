WITH team_data AS(
    SELECT
        th.team_id,
        CONCAT(th.city, ' ', th.nickname) AS team_name,
        (CONCAT(th.year_founded, '-07-01')::DATE) AS year_founded,
        (CONCAT(th.year_active_till, '-06-30')::DATE) AS year_active_till
    FROM team_history AS th
    ORDER BY team_id, year_founded, year_active_till
),
team_matches AS (
    SELECT
        td.team_id,
        td.team_name,
        COUNT(
            CASE
                WHEN g.away_team_id = td.team_id AND ('2019-1-1'::DATE <= td.year_active_till) AND ('2019-1-1' <= g.game_date::DATE)
                    THEN 1
                WHEN g.away_team_id = td.team_id AND (td.year_founded <= g.game_date::DATE) AND (g.game_date::DATE <= td.year_active_till) 
                    THEN 1
            END
        ) AS number_away_matches,
        COUNT(
            CASE
                WHEN g.home_team_id = td.team_id AND ('2019-1-1'::DATE <= td.year_active_till) AND ('2019-1-1' <= g.game_date::DATE)
                    THEN 1
                WHEN g.home_team_id = td.team_id AND (td.year_founded <= g.game_date::DATE) AND (g.game_date::DATE <= td.year_active_till) 
                    THEN 1
            END
        ) AS number_home_matches,
        COUNT(
            CASE 
                WHEN td.team_id IN (g.home_team_id, g.away_team_id) AND ('2019-1-1'::DATE <= td.year_active_till) AND ('2019-1-1' <= g.game_date::DATE)
                    THEN 1
                WHEN td.team_id IN (g.home_team_id, g.away_team_id) AND (td.year_founded <= g.game_date::DATE) AND (g.game_date::DATE <= td.year_active_till) 
                    THEN 1  
            END
        ) AS total_games
    FROM team_data AS td
    JOIN games AS g ON td.team_id IN (g.home_team_id, g.away_team_id)
    GROUP BY td.team_id, td.team_name
)
SELECT
    team_id,
    team_name,
    number_away_matches,
    ROUND(
        CASE
            WHEN total_games = 0 THEN 0
            ELSE (number_away_matches::NUMERIC / total_games) * 100
        END, 2
    ) AS percentage_away_matches,
    number_home_matches,
    ROUND(
        CASE
            WHEN total_games = 0 THEN 0
            ELSE (number_home_matches::NUMERIC / total_games) * 100
        END, 2
    ) AS percentage_home_matches,
    total_games    
FROM team_matches
ORDER BY team_id ASC, team_name ASC;
