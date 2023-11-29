\! echo "=== Une requête sur 3 tables ===\nLes noms, dates et pays des futurs évènements musicaux, ordonnés de celui qui se déroulera dans le moins de temps, à celui qui se déroulera dans le plus de temps.\n"
SELECT DISTINCT Event.name, Event.date_start, Address.country 
FROM Event 
NATURAL JOIN Place 
NATURAL JOIN Address 
WHERE Event.date_start > NOW()
ORDER BY Event.date_start;

\! echo "=== Une jointure réflexive ===\nTous les évènements qui se déroulent en même temps qu'un autre.\n"
SELECT DISTINCT 
	E1.name as event1, 
	date(E1.date_start) as debut1, 
	date(E1.date_end) as fin1, 
	E2.name as event2, 
	date(E2.date_start) as debut2, 
	date(E2.date_end) as fin2
FROM Event E1 JOIN Event E2 ON E1.event_id <> E2.event_id
WHERE E1.date_start <= E2.date_start AND E1.date_end >= E2.date_start;

\! echo "=== Une sous-requête corrélée ===\nLes concerts qui ont eu lieu dans un même pays que n'importe quel concert où est allé un certain utilisateur."
\prompt "L'identifiant de l'utilisateur en question (par exemple 9) > " uid
SELECT DISTINCT event_id, name, date_start, country
FROM (
	SELECT event_id, name, date_start, country
	FROM Event E
	JOIN Place P ON E.place_id=P.place_id
	JOIN Address A ON P.address_id=A.address_id) AS EventLocation
WHERE EXISTS (
	SELECT * 
	FROM UserAccount U
	JOIN EventInscription EI ON U.user_id=EI.user_id
	JOIN Event E ON E.event_id=EI.event_id
	JOIN Place P ON E.place_id=P.place_id
	JOIN Address A ON A.address_id=P.address_id
	WHERE U.user_id= :uid
	AND A.country=EventLocation.country
) 
ORDER BY date_start;

\! echo "=== Une sous-requête dans le FROM ===\nLa moyenne du nombre d'inscrits par évènement musical.\n"
SELECT ROUND(AVG(nb_inscrits), 2) AS nb_inscrits_moyen
FROM (
	SELECT COUNT(user_id) AS nb_inscrits
	FROM EventInscription
	GROUP BY (event_id)
) AS T1;

\! echo "=== Une sous-requête dans le WHERE ===\nLes artistes ayant joué en concert dans le même pays que là où ils habitent. \n"
SELECT DISTINCT user_id, pseudo, country
FROM Artist A1
JOIN UserAccount U ON A1.artist_id=U.user_id
JOIN Address D ON U.address_id=D.address_id
WHERE D.country IN (
	SELECT DISTINCT D2.country
	FROM Address D2
	JOIN Place P ON D2.address_id=P.address_id
	JOIN Event E ON P.place_id=E.place_id
	JOIN Performance Perf ON E.event_id=Perf.event_id
	JOIN PerfAuthor PA ON Perf.perf_id=PA.perf_id
	WHERE A1.artist_id=PA.artist_id);

\! echo "=== Deux agrégats nécessitant GROUP BY et HAVING ===\nLe pseudo des artistes ayant publié au moins un certain nombre de musiques, et leur nombre de musiques. \n"
\prompt "Le nombre minimal de musiques (10) > " nmusic
SELECT t1.pseudo, t2.nb_music                                                                      
FROM 
	(SELECT U.pseudo, U.user_id FROM UserAccount U) t1
JOIN
	(SELECT A.artist_id, count(music_id) as nb_music
	FROM MusicAuthor A
	NATURAL JOIN Music
	GROUP BY (A.artist_id)
	HAVING COUNT(DISTINCT music_id) >= :nmusic) t2
ON (t1.user_id = t2.artist_id);

\! echo "Les identifiants des organisateurs ayant annoncé le plus grand nombre d'évènements, ainsi que le nombre d'évènement qu'ils ont organisés, et la moyenne des prix de leurs évènements. L'une des deux requêtes utilise une répétition dans la sous-requête, et l'autre utilise une table temporaire. \n\t - avec une sous-requête\n"
SELECT O.orga_id, COUNT(E.event_id) AS nb_event, ROUND(AVG(E.price),2) AS avg_price
FROM Organiser O
JOIN EventAnnouncement EA ON O.orga_id=EA.orga_id
JOIN Event E ON E.event_id=EA.event_id
GROUP BY (O.orga_id)
HAVING COUNT(E.event_id) >= ALL(
	SELECT COUNT(E.event_id)
	FROM Organiser O
	JOIN EventAnnouncement EA ON O.orga_id=EA.orga_id
	JOIN Event E ON E.event_id=EA.event_id
	GROUP BY (O.orga_id)
);

\! echo "\t - avec une table temporaire\n"
WITH X (orga_id, event_id, price) AS (
	SELECT O.orga_id, E.event_id, E.price
	FROM Organiser O
	JOIN EventAnnouncement EA ON O.orga_id=EA.orga_id
	JOIN Event E ON E.event_id=EA.event_id
)
SELECT orga_id, COUNT(event_id) AS nb_event, ROUND(AVG(price),2) AS avg_price
FROM X
GROUP BY (orga_id)
HAVING COUNT(event_id) >= ALL (
	SELECT COUNT(event_id) FROM X GROUP BY (orga_id)
);

\! echo "=== Une requête impliquant le calcul de deux agrégats ===\nL'identifiant des artistes, et leur nombre de musiques ayant au moins un certain nombre de commentaires."
\prompt "Le nombre minimal de commentaires (2) > " ncomm
SELECT A.artist_id, COUNT(M.music_id) AS nb_music_comments
FROM Artist A 
JOIN UserAccount U ON A.artist_id=U.user_id
JOIN MusicAuthor MA ON MA.artist_id=A.artist_id
JOIN Music M ON M.music_id=MA.music_id
WHERE M.music_id IN (
	SELECT M.music_id
	FROM Review R JOIN Music M ON M.music_id=R.commented_id
	WHERE R.commented_type='music'
	GROUP BY M.music_id
	HAVING COUNT(DISTINCT R.review_id) >= :ncomm
)
GROUP BY (A.artist_id);

\! echo "=== Une jointure externe (LEFT JOIN, RIGHT JOIN ou FULL JOIN) ===\nTous les évènements musicaux, et leur lineup s'il en ont, sous forme de liste des pseudo des artistes, ou de leur prénom et nom s'ils n'ont pas de pseudo. \n"
\prompt "Cliquer sur entrée pour voir la grande table." tmp
WITH X AS (
	SELECT U.user_id, 
		CASE WHEN pseudo IS NOT NULL THEN pseudo
		ELSE CONCAT(CONCAT(U.firstname,' '),U.lastname)
	END AS name
	FROM UserAccount U
)
SELECT COALESCE(E.name) AS event, COUNT(X.user_id) AS size_lineup, STRING_AGG(X.name, ',') AS lineup
FROM Event E
LEFT JOIN Lineup L ON E.event_id=L.event_id
LEFT JOIN X ON L.artist_id=X.user_id
GROUP BY (E.event_id)
ORDER BY (COUNT(X.user_id)) DESC;

\! echo "\n=== Deux requêtes équivalentes utilisant la totalité, l’une avec des sous requêtes corrélées et l’autre avec de l’agrégation ===\nLes utilisateurs inscrits à tous les concerts gratuits. \n\nIci le nombre de concerts gratuits où ils sont inscrits est égal au nombre total de concerts gratuits, avec l'aggrégation.\n"
SELECT U.pseudo, U.user_id, U.firstname, U.lastname
FROM UserAccount U
JOIN EventInscription EI ON U.user_id=EI.user_id
JOIN Event E ON E.event_id=EI.event_id
WHERE E.price=0
GROUP BY (U.user_id)
HAVING COUNT(E.event_id) = (
	SELECT COUNT(*) 
	FROM Event E
	WHERE E.price = 0
);

\! echo "Ici la requête utilise l'inverse des utilisateurs qui ne sont pas inscrit à certains évènements gratuits, avec des sous-requêtes corrélées.\n"
SELECT pseudo, user_id, firstname, lastname 
FROM UserAccount Ua
WHERE NOT EXISTS (
	SELECT * 
	FROM Event E 
	JOIN EventInscription Ei ON E.event_id = Ei.event_id
	WHERE E.price = 0 
	AND E.price IS NOT NULL 
	AND Ua.user_id NOT IN (
		SELECT Ei2.user_id 
		FROM Event E2 
		JOIN EventInscription Ei2 ON E2.event_id = Ei2.event_id
		WHERE E.event_id = E2.event_id
	)
);

\! echo "=== Deux requêtes aux résultats différents à cause des NULL ===\nLes places de concerts qui ont la plus grande capacité d'accueil. S'il n'y avait aucun NULL dans les capacités intérieure et extérieure des places, alors ces deux requêtes renverraient la même chose. Mais cette première requête renvoie seulement les places dont la capacité est connue et maximale.\n"
SELECT place_id, 
	interior_capacity,
	exterior_capacity,
	interior_capacity+exterior_capacity AS capacity
FROM Place
WHERE interior_capacity+exterior_capacity = (
	SELECT MAX(interior_capacity+exterior_capacity)
	FROM Place
) ORDER BY capacity;

\! echo "Tandis que cette deuxième requête renvoie les places dont la capacité est maximale ou inconnue.\n"
SELECT place_id, 
	interior_capacity,
	exterior_capacity,
	interior_capacity+exterior_capacity AS capacity
FROM Place P1
WHERE NOT EXISTS (
	SELECT * FROM Place P2
	WHERE P2.interior_capacity+P2.exterior_capacity > 
		P1.interior_capacity+P1.exterior_capacity
) ORDER BY capacity;

\! echo "On peut modifier la 2e requête pour qu'elle renvoie comme la première en vérifiant que la capacité est non-nulle.\n"
SELECT place_id, 
	interior_capacity,
	exterior_capacity,
	interior_capacity+exterior_capacity AS capacity
FROM Place P1
WHERE NOT EXISTS (
	SELECT * FROM Place P2
	WHERE P2.interior_capacity+P2.exterior_capacity > 
		P1.interior_capacity+P1.exterior_capacity
) 
AND interior_capacity+exterior_capacity IS NOT NULL
ORDER BY capacity;

\! echo "=== Une requête récursive ===\nTous les genres qui descendent d'un genre particulier, ou d'un de ses descendants au sens large."
\prompt "Le genre en question ('EDM') > " g
WITH RECURSIVE Near_electro (id_rec) AS (
	SELECT tag_id
	FROM Tag
	WHERE tagname=:g
UNION
	SELECT tchild
	FROM TagParent, Near_electro
	WHERE TagParent.tparent=Near_electro.id_rec
)
SELECT tagname
FROM Tag 
JOIN Near_electro ON Near_electro.id_rec=Tag.tag_id;

\! echo "Tous les concerts taggés avec un genre spécifique ou un de ses descendants, ordonné par le nombre de tags correspondants puis par la date de l'évènement.\n"
WITH RECURSIVE Near_electro (id_rec) AS (
	SELECT tag_id
	FROM Tag
	WHERE tagname=:g
UNION
	SELECT tchild
	FROM TagParent, Near_electro
	WHERE TagParent.tparent=Near_electro.id_rec
)
SELECT Event.name, DATE(Event.date_start), nb_tags, tags FROM (
	SELECT Event.event_id, 
		COUNT(Tag.tag_id) AS nb_tags, 
		STRING_AGG(Tag.tagname, ',') AS tags
	FROM Event 
	JOIN Tagging ON Tagging.tagged_id=Event.event_id
	JOIN Tag ON Tagging.tag_id=Tag.tag_id
	JOIN Near_electro ON Near_electro.id_rec=Tag.tag_id
	WHERE Tagging.tagged_type='event'
	GROUP BY Event.event_id
) AS T1
JOIN Event ON Event.event_id=T1.event_id
ORDER BY (nb_tags, Event.date_start) DESC;

\! echo "La distance de chaque genre par rapport à un genre spécifique. Elle est calculée avec le nombre de liens nécessaires pour aller du genre EDM à l'autre genre, soit en montant soit en descendant seulement. Par exemple EDM a une distance de 0 avec lui même, +2 avec house (un de ses descendants) et -1 avec electronic music (un de ses ancêtres).\n"
WITH RECURSIVE Genre_down (id_child, dist) AS (
	SELECT tag_id, 0
	FROM Tag
	WHERE tagname=:g
UNION
	SELECT tchild, dist+1
	FROM TagParent, Genre_down
	WHERE TagParent.tparent=Genre_down.id_child 
), 
Genre_up (id_child, dist) AS (
	SELECT tag_id, 0
	FROM Tag
	WHERE tagname='EDM'
UNION
	SELECT tparent, dist-1
	FROM TagParent, Genre_up
	WHERE TagParent.tchild=Genre_up.id_child 
)
SELECT tagname, dist
FROM (
	SELECT * FROM Genre_down 
	UNION 
	SELECT * FROM Genre_up) AS Genre
JOIN Tag ON Genre.id_child=Tag.tag_id
ORDER BY dist;

\prompt "Cliquer sur entrée pour voir la suite." tmp
\! echo "=== Une requête avec du fenêtrage ===\nLa ou les musiques ayant la meilleure note moyenne de chaque playlist.\n"
WITH X (playlist_id, music_id, evaluation) AS (
	SELECT PC.playlist_id,
		PC.music_id, 
		AVG(evaluation) OVER (PARTITION BY PC.music_id) AS evaluation
	FROM PlaylistComposition PC
	JOIN Review R ON PC.music_id=R.commented_id
	WHERE R.commented_type='music' 
	AND R.evaluation IS NOT NULL
)
SELECT X1.playlist_id, X1.music_id, ROUND(X1.evaluation, 1)
FROM X X1
WHERE X1.evaluation = (
	SELECT DISTINCT MAX(evaluation) OVER (PARTITION BY X2.playlist_id) 
	FROM X X2
	WHERE X1.playlist_id=X2.playlist_id
) ORDER BY playlist_id;

\! echo "=== Une requête impossible avec notre modélisation ===\nOn ne peut pas savoir si une Review a été modifiée avec notre modélisation actuelle. Pour cela on pourrait garder à jour une date de dernière modification dans la table Review, par exemple.\n"


\! echo "=== D'autres requêtes utiles pour un tel logiciel ===\nLes pays ordonnés par leur nombre de concerts à venir.\n"
SELECT country, COUNT(event_id)
FROM Address
NATURAL JOIN Place
NATURAL JOIN Event
WHERE date_start > NOW()
GROUP BY (country)
ORDER BY COUNT(event_id) DESC;

\! echo "Les musiques avec la meilleure note moyenne, ainsi que leur nombre de notes.\n"
WITH X (music_id, avg_eval, nb_eval) AS (
	SELECT M.music_id, ROUND(AVG(evaluation), 1), COUNT(R.review_id)
	FROM Music M
	JOIN Review R ON M.music_id=R.commented_id
	WHERE R.commented_type='music'
	GROUP BY M.music_id
)
SELECT M.music_id, title, avg_eval, nb_eval
FROM X JOIN Music M ON X.music_id=M.music_id
WHERE avg_eval = (SELECT MAX(avg_eval) FROM X);

\! echo "Pour chaque artiste, la liste des tags qu'il s'est lui-même associé et la liste des tags qui lui ont été associé dans les commentaires.\n"
SELECT OT.artist_id, 
	U.pseudo, 
	OT.official_tags, 
	CT.commented_tags 
FROM (
	SELECT A.artist_id, STRING_AGG(T.tagname, ',') AS official_tags
	FROM Artist A 
	JOIN Tagging G ON A.artist_id=G.tagged_id
	JOIN Tag T ON T.tag_id=G.tag_id
	WHERE G.tagged_type='artist'
	GROUP BY A.artist_id
) AS OT 
JOIN (
	SELECT A.artist_id, STRING_AGG(T.tagname, ',') AS commented_tags
	FROM Artist A
	JOIN Review R ON R.commented_id=A.artist_id
	JOIN Tagging G ON R.review_id=G.tagged_id
	JOIN Tag T ON T.tag_id=G.tag_id
	WHERE R.commented_type='artist'
	AND G.tagged_type='review'
	GROUP BY A.artist_id
) AS CT ON OT.artist_id=CT.artist_id
JOIN UserAccount U ON OT.artist_id=U.user_id;

\! echo "Les tags de chaque artiste qui sont présents dans ses commentaires mais pas dans ses tags officiels. Cela permet de repérer les tags qui pourraient être ajoutés à chaque artist.\n"
SELECT D2.artist_id, 
	U.pseudo, 
	D2.tags AS new_tags
FROM UserAccount U
JOIN (
	SELECT artist_id, STRING_AGG(tags, ',') AS tags FROM ((
		SELECT A.artist_id, T.tagname AS tags
		FROM Artist A
		JOIN Review R ON R.commented_id=A.artist_id
		JOIN Tagging G ON R.review_id=G.tagged_id
		JOIN Tag T ON T.tag_id=G.tag_id
		WHERE R.commented_type='artist'
		AND G.tagged_type='review'
	) EXCEPT (
		SELECT A.artist_id, T.tagname AS tags
		FROM Artist A 
		JOIN Tagging G ON A.artist_id=G.tagged_id
		JOIN Tag T ON T.tag_id=G.tag_id
		WHERE G.tagged_type='artist'
	)) AS D1
	GROUP BY (artist_id)
) AS D2
ON D2.artist_id=U.user_id;