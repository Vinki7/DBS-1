WITH selected_records as (-- selekcia potrebnych dat
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
        games.season_id = '{{season_id}}'--'22018'
        AND
        pr.event_msg_type IN ('FIELD_GOAL_MADE', 'FREE_THROW', 'REBOUND')
    ORDER BY pr.game_id ASC, pr.player1_id ASC
),
game_statistics AS (-- vypocet statistik pre kazdy zapas
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
is_td AS (-- zistenie ci hrac dosiahol triple double
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
        SUM(st.streak_start) OVER (PARTITION BY st.player_id ORDER BY st.game_id) AS streak_group -- za kazdy streak start sa prirata 1 => viem trackovat dlzku jendotlivych streakov
    FROM (
        SELECT -- zaznamenavanie zaciatku streak-u
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
            SELECT DISTINCT player_id -- vyber vsetkych hracov, ktori dosiahli triple double
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
    MAX(longest_streak) AS longest_streak -- vyber najvacsieho streaku pre kazdeho hraca
FROM (
    SELECT -- zoskupenie streakov podla streak_group a zistenie dlzky streaku vdaka count(*)
        sg.player_id,
        COUNT(*) AS longest_streak
    FROM streak_groups AS sg
    WHERE sg.is_triple_double = 1
    GROUP BY sg.player_id, sg.streak_group
    ORDER BY sg.player_id DESC, sg.streak_group ASC
)
GROUP BY player_id
ORDER BY longest_streak DESC, player_id ASC;
