/*
Triple Double = 3 typy statistik, ktore dosiahli 2-cifernu hodnotu v jendom zapase
Focus teraz len na pocet bodov, asistencie, doskoky
    points, assists, rebounds

1. Vyebraju sa vsetci hraci pre vybranu sezonu, kotry dosiahli triple double
2. Pre vybranych hracov treba urcit najdlhsiu seriu triple double bez prerusenia
    - ak dva zapasy posebe triple double, seria = 2
    - ak v dalsom zapase da opat triple double, seria sa natahuje na 3, inak ostava 2
    - ak je seria prerusena a hrac da triple double, zacina sa zasa od 1

Vypocet:
    'FIELD_GOAL_MADE' = 2 body
    'FREE_THROW' = 1 ak bol premeneny
    'REBOUND' = pocita sa kazdy hadam

Vystup:
player_id | longest_streak
order:
1. longest_streak DESC
2. player_id ASC
*/

WITH selected_records as (
    SELECT
        pr.player1_id AS player1_id,
        pr.player2_id AS player2_id,
        pr.event_number AS event_number,
        pr.event_msg_type AS event_type,
        pr.score AS score,
        pr.game_id AS game_id
    FROM play_records AS pr
    JOIN games ON games.id = pr.game_id
    WHERE 
        games.season_id = '22018'--{{season_id}}
        AND
        pr.event_msg_type IN ('FIELD_GOAL_MADE', 'FREE_THROW', 'REBOUND')
    ORDER BY pr.game_id ASC, pr.player1_id ASC, pr.player2_id ASC
)
SELECT
    pl.id AS player_id,
    sr.game_id AS game_id,
    COUNT(
        CASE 
            WHEN (sr.event_type = 'FIELD_GOAL_MADE' AND pl.id = sr.player1_id) 
                THEN 1
        END
    ) AS field_goals_made,
    COUNT(
        CASE
            WHEN (sr.event_type = 'FIELD_GOAL_MADE' AND pl.id = sr.player2_id)
                THEN 1
        END
    ) AS assists_made,
    COUNT(
        CASE 
            WHEN (sr.event_type = 'FREE_THROW' AND sr.score IS NOT NULL) 
                THEN 1
        END
    ) AS free_throws_scored,
    COUNT(
        CASE
            WHEN (sr.event_type = 'REBOUND')
                THEN 1
        END
    ) AS rebounds_made
FROM selected_records AS sr
JOIN players AS pl ON pl.id = (
        CASE 
            WHEN pl.id = sr.player1_id 
                THEN sr.player1_id 
            WHEN pl.id = sr.player2_id 
                THEN sr.player2_id  
        END
    )
GROUP BY sr.game_id, pl.id;