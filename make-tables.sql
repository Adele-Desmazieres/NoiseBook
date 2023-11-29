set client_min_messages = warning; 
/* supprime l'annonce du drop de table inexistante */

DROP TABLE IF EXISTS UserAccount CASCADE;
DROP TABLE IF EXISTS Following CASCADE;
DROP TABLE IF EXISTS Friendship CASCADE;
DROP TABLE IF EXISTS Artist CASCADE;
DROP TABLE IF EXISTS Organiser CASCADE;
DROP TABLE IF EXISTS Address CASCADE;
DROP TABLE IF EXISTS Place CASCADE;
DROP TABLE IF EXISTS Event CASCADE;
DROP TABLE IF EXISTS EventAnnouncement CASCADE;
DROP TABLE IF EXISTS EventInscription CASCADE;
DROP TABLE IF EXISTS Lineup CASCADE;
DROP TABLE IF EXISTS PassedEvent CASCADE;
DROP TABLE IF EXISTS File CASCADE;
DROP TABLE IF EXISTS Performance CASCADE;
DROP TABLE IF EXISTS PerfAuthor CASCADE;
DROP TABLE IF EXISTS PerfMusic CASCADE;
DROP TABLE IF EXISTS Music CASCADE;
DROP TABLE IF EXISTS MusicAuthor CASCADE;
DROP TABLE IF EXISTS Playlist CASCADE;
DROP TABLE IF EXISTS PlaylistComposition CASCADE;
DROP TABLE IF EXISTS ListeningHistory CASCADE;
DROP TABLE IF EXISTS Review CASCADE;
DROP TABLE IF EXISTS Tag CASCADE;
DROP TABLE IF EXISTS TagParent CASCADE;
DROP TABLE IF EXISTS Tagging CASCADE;

DROP TYPE IF EXISTS taggable CASCADE;
DROP TYPE IF EXISTS commentable CASCADE;


CREATE TABLE Address (
	address_id serial PRIMARY KEY,
	house_number integer NOT NULL,
	street text NOT NULL,
	city text NOT NULL,
	zipcode text NOT NULL,
	country text NOT NULL,
	UNIQUE (house_number, street, city, zipcode, country)
);

CREATE TABLE Place (
	place_id serial PRIMARY KEY,
	address_id integer NOT NULL REFERENCES Address ON DELETE CASCADE ON UPDATE CASCADE,
	place_name varchar(200),
	interior_capacity integer CHECK (interior_capacity >= 0),
	exterior_capacity integer CHECK (exterior_capacity >= 0),
	nb_toilets integer CHECK (nb_toilets >= 0),
	disabled_access boolean,
	drinks boolean,
	food boolean,
	camping_spots integer CHECK (camping_spots >= 0),
	place_description text
);

CREATE TABLE UserAccount (
	user_id serial PRIMARY KEY,
	firstname text NOT NULL,
	lastname text NOT NULL,
	email text NOT NULL UNIQUE,
	pseudo varchar(100) CHECK (pseudo <> ''), /* si NULL, affiche firstname lastname */
	birthdate date NOT NULL CHECK (birthdate < NOW()),
	inscription_date date NOT NULL DEFAULT NOW(),
	address_id integer REFERENCES Address ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE Following (
	follower integer NOT NULL REFERENCES UserAccount ON DELETE CASCADE ON UPDATE CASCADE,
	followed integer NOT NULL REFERENCES UserAccount ON DELETE CASCADE ON UPDATE CASCADE,
	PRIMARY KEY (follower, followed),
	CONSTRAINT no_self_follow CHECK (follower != followed)
);

CREATE TABLE Friendship (
	friend1 integer NOT NULL REFERENCES UserAccount ON DELETE CASCADE ON UPDATE CASCADE,
	friend2 integer NOT NULL REFERENCES UserAccount ON DELETE CASCADE ON UPDATE CASCADE,
	PRIMARY KEY (friend1, friend2),
	CONSTRAINT asymetrie CHECK (friend1 < friend2)
);

CREATE TABLE Artist (
	artist_id integer PRIMARY KEY REFERENCES UserAccount ON DELETE CASCADE ON UPDATE CASCADE,
	artist_description text
);

CREATE TABLE Organiser (
	orga_id integer PRIMARY KEY REFERENCES UserAccount ON DELETE CASCADE ON UPDATE CASCADE,
	place_id integer REFERENCES Place ON DELETE SET NULL ON UPDATE CASCADE,
	orga_description text
);

CREATE TABLE Event (
	event_id serial PRIMARY KEY,
	place_id integer REFERENCES Place,
	date_start timestamp,
	date_end timestamp,
	name varchar(200) NOT NULL DEFAULT 'Musical Event',
	price integer CHECK (price >= 0),
	nb_places integer CHECK (nb_places >= 0),
	nb_volunteer_needed integer CHECK (nb_volunteer_needed >= 0),
	event_description text, 
	CHECK (date_start <= date_end)
);

CREATE TABLE EventAnnouncement (
	orga_id integer NOT NULL REFERENCES Organiser ON DELETE CASCADE ON UPDATE CASCADE,
	event_id integer NOT NULL REFERENCES Event ON DELETE CASCADE ON UPDATE CASCADE,
	PRIMARY KEY (orga_id, event_id)
);

CREATE TABLE EventInscription (
	user_id integer NOT NULL REFERENCES UserAccount ON DELETE CASCADE ON UPDATE CASCADE,
	event_id integer NOT NULL REFERENCES Event ON DELETE CASCADE ON UPDATE CASCADE,
	type varchar(20) CHECK (type in ('registrant', 'volunteer')) DEFAULT 'registrant' NOT NULL,
	PRIMARY KEY (user_id, event_id)
);

CREATE TABLE Lineup (
	artist_id integer NOT NULL REFERENCES Artist ON DELETE CASCADE ON UPDATE CASCADE,
	event_id integer NOT NULL REFERENCES Event ON DELETE CASCADE ON UPDATE CASCADE,
	PRIMARY KEY (artist_id, event_id)
);

CREATE TABLE PassedEvent (
	event_id integer PRIMARY KEY REFERENCES Event ON DELETE CASCADE ON UPDATE CASCADE,
	nb_participants integer CHECK(nb_participants >= 0),
	post_event_description text
);

CREATE TABLE File (
	file_id serial PRIMARY KEY,
	event_id integer REFERENCES PassedEvent ON DELETE SET NULL ON UPDATE CASCADE,
	title varchar(200) NOT NULL DEFAULT 'File',
	file_location text NOT NULL
);

CREATE TABLE Performance (
	perf_id serial PRIMARY KEY,
	event_id integer NOT NULL REFERENCES PassedEvent ON DELETE CASCADE ON UPDATE CASCADE,
	date_hour timestamp NOT NULL,
	perf_description text
);

CREATE TABLE Music (
	music_id serial PRIMARY KEY,
	title varchar(200) NOT NULL,
	duration integer NOT NULL CHECK (duration > 0),
	publication_date timestamp NOT NULL DEFAULT NOW(),
	is_live boolean
);

CREATE TABLE PerfAuthor (
	artist_id integer NOT NULL REFERENCES Artist ON DELETE CASCADE ON UPDATE CASCADE,
	perf_id integer NOT NULL REFERENCES Performance ON DELETE CASCADE ON UPDATE CASCADE,
	PRIMARY KEY (artist_id, perf_id)
);

CREATE TABLE PerfMusic (
	music_id integer NOT NULL REFERENCES Music ON DELETE CASCADE ON UPDATE CASCADE,
	perf_id integer NOT NULL REFERENCES Performance ON DELETE CASCADE ON UPDATE CASCADE,
	PRIMARY KEY (music_id, perf_id)
);

CREATE TABLE MusicAuthor (
	music_id integer NOT NULL REFERENCES Music ON DELETE CASCADE ON UPDATE CASCADE,
	artist_id integer NOT NULL REFERENCES Artist ON DELETE CASCADE ON UPDATE CASCADE,
	PRIMARY KEY (music_id, artist_id)
);

CREATE TABLE Playlist (
	playlist_id serial PRIMARY KEY,
	user_id integer NOT NULL REFERENCES UserAccount ON DELETE CASCADE ON UPDATE CASCADE,
	title varchar(200) NOT NULL
);

CREATE TABLE PlaylistComposition (
	playlist_id integer NOT NULL REFERENCES Playlist ON DELETE CASCADE ON UPDATE CASCADE,
	music_id integer NOT NULL REFERENCES Music ON DELETE CASCADE ON UPDATE CASCADE,
	music_number integer NOT NULL CHECK (music_number >= 0 AND music_number <= 20),
	PRIMARY KEY (playlist_id, music_number)
);

CREATE TABLE ListeningHistory (
	music_id integer NOT NULL REFERENCES Music ON DELETE CASCADE ON UPDATE CASCADE,
	user_id integer NOT NULL REFERENCES UserAccount ON DELETE CASCADE ON UPDATE CASCADE,
	listening_date timestamp NOT NULL DEFAULT NOW(),
	duration integer NOT NULL CHECK (duration >= 1),
	PRIMARY KEY (music_id, user_id, listening_date)
);

CREATE TYPE commentable AS ENUM ('music', 'artist', 'place', 'event', 'performance');

CREATE TABLE Review (
	review_id serial PRIMARY KEY,
	publication_date timestamp NOT NULL DEFAULT NOW(),
	comment text,
	evaluation integer CHECK (evaluation >= 0 AND evaluation <= 10),
	commented_id integer NOT NULL,
	commented_type commentable NOT NULL
);

CREATE TABLE Tag (
	tag_id serial PRIMARY KEY,
	tagname varchar(200) NOT NULL UNIQUE,
	is_genre boolean NOT NULL
);

CREATE TABLE TagParent (
	tparent integer NOT NULL REFERENCES Tag ON DELETE CASCADE ON UPDATE CASCADE,
	tchild integer NOT NULL REFERENCES Tag ON DELETE CASCADE ON UPDATE CASCADE,
	PRIMARY KEY (tparent, tchild)
);

CREATE TYPE taggable AS ENUM ('review', 'playlist', 'artist', 'place', 'event');

CREATE TABLE Tagging (
	tag_id integer NOT NULL REFERENCES Tag ON DELETE CASCADE ON UPDATE CASCADE,
	tagged_id integer NOT NULL,
	tagged_type taggable NOT NULL,
	PRIMARY KEY (tag_id, tagged_id, tagged_type)
);


\copy Address(house_number, street, city, zipcode, country) FROM './CSV/Address.csv' csv header; /* 250 */

\copy Place(address_id, place_name, interior_capacity, exterior_capacity, nb_toilets, disabled_access, drinks, food, camping_spots, place_description) FROM './CSV/Place.csv' csv header; /* 250 */

\copy UserAccount(firstname, lastname, email, pseudo, birthdate, inscription_date, address_id) FROM './CSV/UserAccount.csv' csv header; /* 200 */

\copy Following(follower, followed) FROM './CSV/Following.csv' csv header; /* 500 */

\copy Friendship(friend1, friend2) FROM './CSV/Friendship.csv' csv header; /* 400 */

\copy Artist(artist_id, artist_description) FROM './CSV/Artist.csv' csv header; /* 80 */

\copy Organiser(orga_id, place_id, orga_description) FROM './CSV/Organiser.csv' csv header; /* 80 */

\copy Event(place_id, date_start, date_end, name, price, nb_places, nb_volunteer_needed, event_description) FROM './CSV/Event.csv' csv header; /* 100 */

\copy EventAnnouncement(orga_id, event_id) FROM './CSV/EventAnnouncement.csv' csv header; /* 150 */

\copy EventInscription(user_id, event_id, type) FROM './CSV/EventInscription.csv' csv header; /* 400 */

\copy Lineup(artist_id, event_id) FROM './CSV/Lineup.csv' csv header; /* 300 */

\copy PassedEvent(event_id, nb_participants, post_event_description) FROM './CSV/PassedEvent.csv' csv header; /* 50 */

\copy File(event_id, title, file_location) FROM './CSV/File.csv' csv header; /* 200 */

\copy Performance(event_id, date_hour, perf_description) FROM './CSV/Performance.csv' csv header; /* 200 */

\copy Music(title, duration, publication_date, is_live) FROM './CSV/Music.csv' csv header; /* 300 */

\copy PerfAuthor(artist_id, perf_id) FROM './CSV/PerfAuthor.csv' csv header; /* 300 */

\copy PerfMusic(music_id, perf_id) FROM './CSV/PerfMusic.csv' csv header; /* 300 */

\copy MusicAuthor(music_id, artist_id) FROM './CSV/MusicAuthor.csv' csv header; /* 400 */

\copy Playlist(user_id, title) FROM './CSV/Playlist.csv' csv header; /* 100 */

\copy PlaylistComposition(playlist_id, music_id, music_number) FROM './CSV/PlaylistComposition.csv' csv header; /* 400 */

\copy ListeningHistory(music_id, user_id, listening_date, duration) FROM './CSV/ListeningHistory.csv' csv header; /* 1000 */

\copy Review(publication_date, comment, evaluation, commented_id, commented_type) FROM './CSV/Review.csv' csv header; /* 250 */

\copy Tag(tagname, is_genre) FROM './CSV/Tag.csv' csv header; /* 50 */

\copy TagParent(tparent, tchild) FROM './CSV/TagParent.csv' csv header; /* 37 */

\copy Tagging(tag_id, tagged_id, tagged_type) FROM './CSV/Tagging.csv' csv header; /* 500 */

