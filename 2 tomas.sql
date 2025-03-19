/* Pre vybranu sezonu najdite vsetkych hracov, ktory pocas sezony zmenili tim.
Zmena timu je povazovana, ak hrac odohral za iny tim nejaky zapas,
a to ak v tabulke play_records sa nachadza hracove ID na atributoch player1_id
alebo player2_id a to pre typy udalosti 'FREE_THROW', 'FIELD_GOAL_MADE',
'FIELD_GOAL_MISSED', 'REBOUND'.

Pre tychto hracov spocitajte, kolko krat zmenili tim pocas danej sezony.
Pre prvych piatich hracov, ktory najviac zmenili tim, vypocitajte priemerny pocet
bodov na zapas (udalost typu FIELD GOAL MADE berte za 2 body - nie je
potrebne rozlisovat 2 a 3 body), priemerny pocet asistencii a pocet zapasov,
ktore dany hrac odohral za konkretny tim.

Vo vystupe uvedte nasledovne informacie:
	player_id - id hraca
	first_name - krstne meno hraca
	last_name - priezvisko hraca
	team_id - id timu
	team_name - plne meno timu (full_name)
	PPG - points per game - priemerny pocet bodov na zapas pre dany tim.
		Zaokruhlene na dve desatine miesta.
	APG - assists per game - priemerny pocet asistencii na zapas pre dany tim.
		Zaokruhlene na dve desatine miesta.
	games - pocet hier, ktore odohral hrac za dany tim v sezone.

Vystup je potrebne primarne zoradit podla player_id vzostupne (Ascending) a
nasledne podla team_id vzostupne (Ascending).

Kvoli testovaniu je potrebne uviest v odovzdanom SQL subore ID sezony ako {{season_id}}.*/

WITH 
player_records AS ( 
	SELECT 	pla.id player_id,
			pla.full_name player_full,
			pla.first_name player_first,
			pla.last_name player_last,
			pre.game_id game_id,
			pre.event_msg_type,
			pre.score,
			pre.player1_id,
			pre.player2_id,
			pre.player1_team_id,
			pre.player2_team_id,
			tea.id team_id,
			tea.full_name team_name
	FROM players pla
	JOIN play_records pre ON (pla.id = pre.player1_id OR pla.id = pre.player2_id) 
							AND pre.event_msg_type IN ('FREE_THROW', 'FIELD_GOAL_MADE', 'FIELD_GOAL_MISSED', 'REBOUND')
	JOIN games ON games.id = pre.game_id 
					AND CAST(games.season_id AS int) = {{season_id}}--{{season_id}} /*22017*/
	JOIN teams tea ON tea.id = (CASE 
									WHEN pla.id = pre.player1_id THEN pre.player1_team_id
									WHEN pla.id = pre.player2_id THEN pre.player2_team_id
								END)
),
top5_players AS (
	SELECT 	player_id, player_full,
			COUNT (DISTINCT team_id) count_team
	FROM player_records
	GROUP BY player_id, player_full
	ORDER BY count_team DESC
	LIMIT 5
),
games_count AS (
	SELECT 
		player_id, 
		team_id, 
		COUNT(DISTINCT game_id) AS count_games
	FROM player_records
	WHERE player_id IN (SELECT player_id FROM top5_players)
	GROUP BY player_id, team_id
),
clean_data AS(
SELECT 
		pla_rec.player_id,
		pla_rec.player_first,
		pla_rec.player_last,
		pla_rec.team_id,
		pla_rec.team_name,
		
		SUM(
			CASE
				WHEN pla_rec.event_msg_type = 'FIELD_GOAL_MADE' AND pla_rec.player_id = pla_rec.player1_id THEN 2
				WHEN pla_rec.event_msg_type = 'FREE_THROW' AND pla_rec.score IS NOT NULL THEN 1
			END
		) AS total_points,
		
		SUM(
			CASE
				WHEN pla_rec.event_msg_type = 'FIELD_GOAL_MADE' AND pla_rec.player_id = pla_rec.player2_id THEN 1
			END
		) AS total_assists

	FROM player_records pla_rec
	JOIN top5_players top ON pla_rec.player_id = top.player_id
	GROUP BY pla_rec.player_id, pla_rec.player_first, pla_rec.player_last, pla_rec.team_id, pla_rec.team_name
)
SELECT 
		cd.player_id,
		cd.player_first,
		cd.player_last,
		cd.team_id,
		cd.team_name,
		ROUND(SUM(cd.total_points) * 1.0 / NULLIF(SUM(gc.count_games), 0), 2) AS PPG,
		ROUND(SUM(cd.total_assists) * 1.0 / NULLIF(SUM(gc.count_games), 0), 2) AS APG,
		SUM(gc.count_games) AS games
FROM clean_data cd
JOIN games_count gc ON cd.player_id = gc.player_id AND cd.team_id = gc.team_id
GROUP BY cd.player_id, cd.player_first, cd.player_last, cd.team_id, cd.team_name
ORDER BY cd.player_id ASC, cd.team_id ASC;




















