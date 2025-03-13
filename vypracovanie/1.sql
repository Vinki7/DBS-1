-- Active: 1740996226560@@localhost@5433@nba@public

WITH p_selection AS (
    SELECT 
        pr1.player1_id AS player_id,
        pr2.period AS period,
        pr2.pctimestring AS period_time
    FROM play_records AS pr1
        JOIN play_records AS pr2 
            ON pr1.game_id = pr2.game_id
            AND pr1.player1_id = pr2.player1_id
            AND pr2.event_number = pr1.event_number + 1
    WHERE pr1.game_id = {{game_id}} AND pr1.event_msg_type = 'REBOUND' AND pr2.event_msg_type = 'FIELD_GOAL_MADE'
)
SELECT 
    p_selection.player_id, 
    players.first_name,
    players.last_name,
    p_selection.period, 
    p_selection.period_time
FROM p_selection
    JOIN players ON p_selection.player_id = players.id
ORDER BY p_selection.period ASC, p_selection.period_time DESC;