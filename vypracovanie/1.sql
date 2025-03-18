WITH selection AS (
    SELECT
        pr.player1_id AS player_id,
        pr.period AS period,
        pr.pctimestring AS period_time,
        pr.event_msg_type AS event_type,
        pr.event_number AS event_number,
        LAG(pr.event_msg_type, 1) 
        OVER (ORDER BY pr.event_number) AS prev_event,
        LAG(pr.player1_id, 1)
        OVER (ORDER BY pr.event_number) AS prev_player
    FROM play_records AS pr
    WHERE pr.game_id = {{game_id}}::INTEGER--22000516, 22000529
    ORDER BY pr.event_number
)
SELECT 
    sel.player_id, 
    pl.first_name,
    pl.last_name,
    sel.period, 
    sel.period_time
FROM selection AS sel
JOIN players AS pl ON sel.player_id = pl.id
WHERE sel.player_id = sel.prev_player AND (event_type = 'FIELD_GOAL_MADE' AND prev_event = 'REBOUND')
ORDER BY sel.period ASC, sel.period_time DESC;
