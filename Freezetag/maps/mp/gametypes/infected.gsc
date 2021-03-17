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
    T6 Infected.
    Updated: 15/03/2021.
    Version: 0.3.
    Authors: Birchy & JezuzLizard.
	Description: Eliminated survivors become infected. 
	Infect everyone, or survive the game to win.

	Features:
	-Player quota.
	-Infection countdown.
	-Survivor/Infected/First infected loadouts.
	-Infection behaviour (Handles edge cases like suicides, quitting early, etc).
	-First infected doesn't suicide (Like MW3).
	-Client class and team select menu prompts removed.
	-Survivor/Infected win condition and end text.
	-Team score is player count.
	-Audio queues.
	-Random, configurable loadouts.
	-Randomised first spawn.
	-Custom popup cards.
	-Remember rejoining infected players.
 */

 /**
	TODO (Not all possible as of 15/03/2021):
	-Score popup for surviving.
	-Specialist streaks.
	-MOAB.
	-Equipment limit for survivors.
	-Team names.
	-Gamemode name.
	-Radar sweep in late game.
  */

  /**	
  	Feedback: Rejoining infected get survivor class.
   sticky nade when stuff swaps
   if someone self infects firstinfected doesnt lose gun.
   if u are only infected (bc someone rage quit) give u gun.
   dead silence for infect
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
	setscoreboardcolumns("score", "kills", "deaths", "kdratio", "assists");
	level.scoreroundbased = getgametypesetting("roundscorecarry") == 0;
	level.teamscoreperkill = getgametypesetting("teamScorePerKill");
	level.teamscoreperdeath = getgametypesetting("teamScorePerDeath");
	level.teamscoreperheadshot = getgametypesetting("teamScorePerHeadshot");
	level.teambased = 1;
	level.overrideteamscore = 1;
	level.onstartgametype = ::onstartgametype;
	level.onspawnplayerunified = ::onspawnplayerunified;
	setupinfected();
}

setupinfected(){
	precachestring(&"Infected");
	precachestring(&"First Infected");
	precachestring(&"M.O.A.B.");
	level.onspawnplayer = ::onspawnplayer;
	level.onplayerkilled = ::onplayerkilled;
	level.ontimelimit = ::ontimelimit;
	level.gettimelimit = ::gettimelimit;
	level.givecustomloadout = ::loadout;
	level.loadout = [];
	level.loadout["primary"] = randomelement(strtok(getdvarstringdefault("infected_primary", "mp7_mp+dualclip+fastads"), ","));
	level.loadout["secondary"] = randomelement(strtok(getdvarstringdefault("infected_secondary", "fnp45_mp"), ","));
	level.loadout["lethal"] = randomelement(strtok(getdvarstringdefault("infected_lethal", "sticky_grenade_mp"), ","));
	level.loadout["tactical"] = randomelement(strtok(getdvarstringdefault("infected_tactical", "flash_grenade_mp"), ","));
	level.allowtac = getdvarintdefault("infected_allowtac", 1);
	level.allowtomo = getdvarintdefault("infected_allowtomo", 1);
	level.devmode = getdvarintdefault("infected_devmode", 1);
	level.minplayers = getdvarintdefault("infected_minplayers", 8);
	level.moabvision = getdvarstringdefault("infected_moabvision", "tvguided_sp");
	level.infectedtable = [];
	level.infectedtext = createserverfontstring("objective", 1.4);
	level.infectedtext setgamemodeinfopoint();
	level.infectedtext.hidewheninmenu = 1;
	level.infectedtext.alpha = 0;
	level.quotamet = 0;
	level thread quota();
	level thread connect();
	level thread disconnect();
}

quota(){
	level endon("game_ended");
	level waittill("prematch_over");
	level.addtime = false;
	level.addedtime = 0;
	if(level.players.size < level.minplayers){
		level.infectedtext.label = &"Extra survivors required: ";
		while(level.players.size < level.minplayers){
			wait 1;
			level.infectedtext.alpha = 1;
			level.infectedtext setvalue(level.minplayers - level.players.size);
			level.addedtime++;
		}
		level.addedtime /= 60;
		level.addtime = true;
		level.infectedtext.alpha = 0;
	}
	level.quotamet = 1;
	updatescore();
}


infectfirst(){
	level endon("game_ended");
	level endon("stop_countdown");
	level.infectedtext.label = &"Infection countdown: ";
	level.infectedtext.alpha = 1;
	for(i = 10; i > 0; i--){
		level.infectedtext setvalue(i);
		wait 1;
	}
	level.infectedtext.alpha = 0;
	if(level.players.size < 2) map_restart();
	first = level.players[randomint(level.players.size)];
	first.firstinfected = true;
	first.infected = true;
	first addtoteam("axis", false);
	first loadout();
	thread playsoundonplayers("mpl_flagcapture_sting_enemy", "allies");
	first iprintlnbold("^1First infected!");
	infectednotify(&"First Infected", first);
	updatescore();
}

connect(){
	for(;;){
		level waittill("connected", player);
		logprint("DEBUG: connected player\n");
		if(level.devmode == 1) player thread devmode();
		if(isinarray(level.infectedtable, player.guid)){
			level notify("stop_countdown");
			level.infectedtext.alpha = 0;
			player addtoteam("axis", true);
			logprint("DEBUG: should have made them axis\n");
			player.infected = true;
		}else{
			player addtoteam("allies", true);
			logprint("DEBUG: should have made them allies\n");
			player.infected = false;
		}
		player.firstinfected = false;
		updatescore();
		logprint("DEBUG: should have updated score\n");
	}
}

disconnect(){
	level waittill("disconnect", player);
	if(player.infected && !isinarray(level.infectedtable, player.guid)){
		level.infectedtable[level.infectedtable.size] = player.guid;
	}
	updatescore();
}

addtoteam(team, firstconnect){
    self.pers["team"] = team;
    self.team = team;
	self.sessionteam = self.pers["team"];
    self maps/mp/gametypes/_globallogic_ui::updateobjectivetext();
	//if(firstconnect) waittillframeend;
	self notify("end_respawn");
}

ontimelimit(){
	level.infectedtext.alpha = 0;
	thread maps/mp/gametypes/_globallogic::endgame("allies", "Survivors win");
}

gettimelimit(){
    timelimit = maps/mp/gametypes/_globallogic_defaults::default_gettimelimit();
    if(level.addtime) return timelimit + level.addedtime;
	return timelimit;
}

getdvarstringdefault(dvar, dval){
	if(getdvar(dvar) == ""){
		return dval;
	}
	return getdvar(dvar);
}

randomelement(array){
	return array[randomint(array.size)];
}

onplayerkilled(inflictor, attacker, damage, meansofdeath, weapon, dir, hitloc, offsettime, deathanimduration){
	if(level.quotamet == 0){
		return;
	}
	if(!self.infected){
		if (self.suicide == 1){
			level notify("stop_countdown");
			level.infectedtext.alpha = 0;
		}else{
			if(attacker.firstinfected){
				attacker.firstinfected = false;
				attacker loadout();
			}
		}
		thread playsoundonplayers("mpl_flagcapture_sting_enemy", "allies");
		thread playsoundonplayers("mpl_flagcapture_sting_friend", "axis");
		self.infected = true;
		self addtoteam("axis", false);
		infectednotify(&"Infected", self);
	}
	updatescore();
}

updatescore(){
	survivors = 0;
	infected = 0;
	foreach(player in level.players){
		if(player.team == "allies"){
			survivors++;
		}
		if(player.team == "axis"){
			infected++;
		}
	}
	game["teamScores"]["allies"] = survivors;
	maps/mp/gametypes/_globallogic_score::updateteamscores("allies");
	game["teamScores"]["axis"] = infected;
	maps/mp/gametypes/_globallogic_score::updateteamscores("axis");
	if(survivors == 0){
		thread endgame("axis", "Survivors eliminated");
	}else if(infected == 0 && survivors > 1 && level.quotamet){
		infectfirst();
	}
}

loadout(){
	self clearperks();
	self takeallweapons();
	self giveweapon("knife_mp");
	if(is_true(self.infected)){
		self setperk("specialty_fallheight");
		self setperk("specialty_fastequipmentuse");
		self setperk("specialty_fastladderclimb");
		self setperk("specialty_fastmantle");
		self setperk("specialty_fastmeleerecovery");
		self setperk("specialty_fasttoss");
		self setperk("specialty_fastweaponswitch");
		self setperk("specialty_longersprint");
		self setperk("specialty_sprintrecovery");
		self giveweapon("knife_held_mp");
		if(level.allowtomo){
			self giveweapon("hatchet_mp");
			self setweaponammoclip("hatchet_mp", 1);
		}
		if(level.allowtac) self giveWeapon("tactical_insertion_mp");
		if(self.firstinfected){
			self giveweapon(level.loadout["primary"]);
			self switchtoweapon(level.loadout["primary"]);
		}else{
			self switchtoweapon("knife_held_mp");
		}
	}else{
		self setperk("specialty_scavenger");
		foreach(weapon in level.loadout){
			self giveweapon(weapon);
		}
		self setweaponammoclip(level.loadout["lethal"], 1);
		self setweaponammoclip(level.loadout["tactical"], 1);
		self switchtoweapon(level.loadout["primary"]);
	}
}

onspawnplayer(predictedspawn){
	pixbeginevent("TDM:onSpawnPlayer");
	self.usingobj = undefined;
	spawnpoints = maps/mp/gametypes/_spawnlogic::getteamspawnpoints(self.pers["team"]);
	spawnpoint = maps/mp/gametypes/_spawnlogic::getspawnpoint_nearteam(spawnpoints);
	if(predictedspawn){
		self predictspawnpoint(spawnpoint.origin, spawnpoint.angles);
	}else{
		self spawn(spawnpoint.origin, spawnpoint.angles, "tdm");
	}
	pixendevent();
}

onstartgametype(){
	setclientnamemode("auto_change");
	allowed = [];
	allowed[0] = "tdm";
	level.displayroundendtext = 0;
	maps/mp/gametypes/_gameobjects::main(allowed);
	maps/mp/gametypes/_spawning::create_map_placed_influencers();
	level.spawnmins = (0, 0, 0);
	level.spawnmaxs = (0, 0, 0);
	foreach(team in level.teams){
		maps/mp/gametypes/_spawnlogic::addspawnpoints(team, "mp_tdm_spawn");
		maps/mp/gametypes/_spawnlogic::placespawnpoints(maps/mp/gametypes/_spawning::gettdmstartspawnname(team));
	}
	maps/mp/gametypes/_spawning::updateallspawnpoints();
	level.mapcenter = maps/mp/gametypes/_spawnlogic::findboxcenter(level.spawnmins, level.spawnmaxs);
	setmapcenter(level.mapcenter);
	spawnpoint = maps/mp/gametypes/_spawnlogic::getrandomintermissionpoint();
	setdemointermissionpoint(spawnpoint.origin, spawnpoint.angles);
}

onspawnplayerunified(){
	self.usingobj = undefined;
	maps/mp/gametypes/_spawning::onspawnplayer_unified();
}

infectednotify(string, origin){
	foreach(player in level.players){
		player luinotifyevent(&"player_callout", 2, string, origin.entnum);
	}
}

devmode(){
    self endon("disconnect");
    self notifyonplayercommand("bot", "bot");
	self notifyonplayercommand("time", "time");
	self setclientuivisibilityflag("g_compassShowEnemies", 2);
    for(;;){
        command = self waittill_any_return("bot", "time");
		switch(command){
			case "bot":
				maps\mp\bots\_bot::spawn_bot(self.team);
				break;
			case "time":
				if(getdvarfloat("timescale") == 1.0){
					setdvar("timescale", 5.0);
				}else{
					setdvar("timescale", 1.0);
				}
				break;
		}
    } 
}