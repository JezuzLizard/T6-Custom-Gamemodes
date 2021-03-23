#include maps/mp/gametypes/_globallogic_audio;
#include maps/mp/gametypes/_globallogic_score;
#include maps/mp/gametypes/_spawnlogic;
#include maps/mp/gametypes/_spawning;
#include maps/mp/gametypes/_gameobjects;
#include maps/mp/gametypes/_callbacksetup;
#include maps/mp/gametypes/_globallogic;
#include maps/mp/gametypes/_hud_util;
#include common_scripts/utility;
#include maps/mp/_utility;

/**
	T6 Freezetag.
	Description: Shoot enemies to freeze them, stand near your 
	frozen allies to unfreeze them. Last team standing wins.
	Updated: 23/03/2021
	Version: 0.5.
	Authors: Birchy & JezuzLizard.

	Features:
	-Modified scoreboard.
	-Score events (Captures, denies).
	-Players frozen when shot.
	-Last team standing win condition.
	-Team score is how many players are unfrozen.
	-Round support.

	Todo:
	-Head icon for frozen players.
	-Progress bar for unfreezing players.
	-Unfreezing players behaviour.
	-Visual and sound fx.
	-Suicide behaviour.
	-Fix round support.
 */

main(){
	maps/mp/gametypes/_globallogic::init();
	maps/mp/gametypes/_callbacksetup::setupcallbacks();
	maps/mp/gametypes/_globallogic::setupcallbacks();
	maps/mp/_utility::registerroundswitch(0, 9);
	maps/mp/_utility::registertimelimit(0, 1440);
	maps/mp/_utility::registerscorelimit(0, 50000);
	maps/mp/_utility::registerroundlimit(0, 10);
	maps/mp/_utility::registerroundwinlimit(0, 10);
	maps/mp/_utility::registernumlives(0, 100);
	maps/mp/gametypes/_globallogic::registerfriendlyfiredelay(level.gametype, 15, 0, 1440);
	level.scoreroundbased = getgametypesetting("roundscorecarry") == 0;
	level.teamscoreperkill = getgametypesetting("teamScorePerKill");
	level.teamscoreperdeath = getgametypesetting("teamScorePerDeath");
	level.teamscoreperheadshot = getgametypesetting("teamScorePerHeadshot");
	level.teambased = 1;
	level.overrideteamscore = 1;
	level.onstartgametype = ::onstartgametype;
	level.onspawnplayer = ::onspawnplayer;
	level.onspawnplayerunified = ::onspawnplayerunified;
	level.onroundendgame = ::onroundendgame;
	level.onroundswitch = ::onroundswitch;
	setscoreboardcolumns("", "", "score", "captures", "killsdenied");
	level.sdamage = level.callbackplayerdamage;
	level.callbackplayerdamage = ::damage;
	level.givecustomloadout = ::loadout;
	level.loadoutkillstreaksenabled = 0;
	level thread updatescore();
}

freeze(){
	level endon("game_ended");
	self endon("disconnect");
	self enableinvulnerability();
	self allowsprint(0);
	self allowattack(0);
	self setmovespeedscale(0);
	self setclientthirdperson(1);
	self.frozen = true;
	foreach(player in level.players){
		player luinotifyevent(&"player_callout", 2, &"Frozen", self.entnum);
	}
	wait 5;
	self disableinvulnerability();
	self allowsprint(1);
	self setmovespeedscale(1);
	self setclientthirdperson(0);
	self allowattack(1);
	self givemaxammo(self getcurrentweapon());
	self.frozen = false;
	foreach(player in level.players){
		player luinotifyevent(&"player_callout", 2, &"Unfrozen", self.entnum);
	}
}

loadout(){
	self takeallweapons();
	self clearperks();
	self giveweapon("ballista_mp+is");
	self switchtoweapon("ballista_mp+is");
	self setperk("specialty_fallheight");
    self setperk("specialty_fastladderclimb");
    self setperk("specialty_fastmantle");
    self setperk("specialty_unlimitedsprint");
    self setperk("specialty_sprintrecovery");
}

damage(inflictor, attacker, damage, flags, meansofdeath, weapon, point, dir, hitloc, timeoffset, boneindex){
	if(!isplayer(attacker) || attacker.team == self.team) return;
	attacker.score += 100;
	attacker.captures += 1;
	//TODO: Score popup.
	//obituary(self, attacker, weapon, meansofdeath);
	self thread freeze();
	[[level.sdamage]](inflictor, attacker, 0, flags, meansofdeath, weapon, point, dir, hitloc, timeoffset, boneindex);
}

updatescore(){
	level endon("game_ended");
	level waittill("prematch_over");
	for(;;){
		teamsleft = [];
		foreach(team in level.teams){
			unfrozen = 0;
			for(i = 0; i < level.players.size; i++){
				if(level.players[i].team == team && !is_true(level.players[i].frozen)){
					unfrozen++;
				}
			}
			game["teamScores"][team] = unfrozen;
			maps/mp/gametypes/_globallogic_score::updateteamscores(team);
			if(unfrozen != 0) teamsleft[teamsleft.size] = team;
		}
		if(teamsleft.size == 1){
			thread endgame(teamsleft[0], toupper(game[teamsleft[0]]) + " froze all enemies");
		}else if(teamsleft.size < 1){
			thread endgame(undefined, "All players frozen"); //Edge case.
		}
		wait 0.1;
	}
}

onstartgametype(){
	precachestring(&"Unfrozen");
	precachestring(&"Frozen");
	precachestring(&"FREEZE ALL ENEMIES");
	setclientnamemode("auto_change");
	if(!isDefined(game["switchedsides"])){
		game["switchedsides"] = 0;
	}
	if(game["switchedsides"]){
		oldattackers = game["attackers"];
		olddefenders = game["defenders"];
		game["attackers"] = olddefenders;
		game["defenders"] = oldattackers;
	}
	allowed = [];
	allowed[0] = "tdm";
	level.displayroundendtext = 0;
	maps/mp/gametypes/_gameobjects::main(allowed);
	maps/mp/gametypes/_spawning::create_map_placed_influencers();
	level.spawnmins = (0, 0, 0);
	level.spawnmaxs = (0, 0, 0);
	foreach(team in level.teams){
		maps/mp/_utility::setobjectivetext(team, &"FREEZE ALL ENEMIES");
		maps/mp/_utility::setobjectivehinttext(team, &"FREEZE ALL ENEMIES");
		maps/mp/_utility::setobjectivescoretext(team, &"FREEZE ALL ENEMIES");
		maps/mp/gametypes/_spawnlogic::addspawnpoints(team, "mp_tdm_spawn");
		maps/mp/gametypes/_spawnlogic::placespawnpoints(maps/mp/gametypes/_spawning::gettdmstartspawnname(team));
	}
	maps/mp/gametypes/_spawning::updateallspawnpoints();
	level.mapcenter = maps/mp/gametypes/_spawnlogic::findboxcenter(level.spawnmins, level.spawnmaxs);
	setmapcenter(level.mapcenter);
	spawnpoint = maps/mp/gametypes/_spawnlogic::getrandomintermissionpoint();
	setdemointermissionpoint(spawnpoint.origin, spawnpoint.angles);
	if(!maps/mp/_utility::isoneround()){
		level.displayroundendtext = 1;
		if (maps/mp/_utility::isscoreroundbased()){
			maps/mp/gametypes/_globallogic_score::resetteamscores();
		}
	}
}

onspawnplayerunified(){
	self.usingobj = undefined;
	maps/mp/gametypes/_spawning::onspawnplayer_unified();
}

onspawnplayer(predictedspawn){
	pixbeginevent("TDM:onSpawnPlayer");
	self.usingobj = undefined;
	spawnteam = self.pers["team"];
	if(level.ingraceperiod){
		spawnpoints = maps/mp/gametypes/_spawnlogic::getspawnpointarray(maps/mp/gametypes/_spawning::gettdmstartspawnname(spawnteam));
		if(!spawnpoints.size){
			spawnpoints = maps/mp/gametypes/_spawnlogic::getspawnpointarray(maps/mp/gametypes/_spawning::getteamstartspawnname(spawnteam, "mp_sab_spawn"));
		}
		if(!spawnpoints.size){
			if (game["switchedsides"]){
				spawnteam = maps/mp/_utility::getotherteam(spawnteam);
			}
			spawnpoints = maps/mp/gametypes/_spawnlogic::getteamspawnpoints(spawnteam);
			spawnpoint = maps/mp/gametypes/_spawnlogic::getspawnpoint_nearteam(spawnpoints);
		}else{
			spawnpoint = maps/mp/gametypes/_spawnlogic::getspawnpoint_random(spawnpoints);
		}
	}else {
		if(game["switchedsides"]){
			spawnteam = maps/mp/_utility::getotherteam(spawnteam);
		}
		spawnpoints = maps/mp/gametypes/_spawnlogic::getteamspawnpoints(spawnteam);
		spawnpoint = maps/mp/gametypes/_spawnlogic::getspawnpoint_nearteam(spawnpoints);
	}
	if(predictedspawn){
		self predictspawnpoint(spawnpoint.origin, spawnpoint.angles);
	}else{
		self spawn(spawnpoint.origin, spawnpoint.angles, "tdm");
	}
	pixendevent();
}

onroundswitch(){
	game["switchedsides"] = !game["switchedsides"];
	if(level.roundscorecarry == 0){
		foreach (team in level.teams){
			[[level._setteamscore]](team, game["roundswon"][team]);
		}
	}
}

onroundendgame(roundwinner){
	if(level.roundscorecarry == 0){
		foreach (team in level.teams){
			[[level._setteamscore]](team, game["roundswon"][team]);
		}
		winner = maps/mp/gametypes/_globallogic::determineteamwinnerbygamestat("roundswon");
	}else{
		winner = maps/mp/gametypes/_globallogic::determineteamwinnerbyteamscore();
	}
	return winner;
}