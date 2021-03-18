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
    Updated: 17/03/2021.
    Version: 1.0.
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
	-Radar sweep activated when one survivor is left.
	-Add survived column instead of death to track how long a player lived for (Future).
	-Specialist streaks (Fast hands gives fast mag).
	-M.O.A.B.
 */

 /**
	TODO (Not all possible as of 17/03/2021):
	-Team names (Not possible).
	-Gamemode name (Not possible).
	-Score popup for surviving (Future).
  */

  /**	
  	Test feedback: 
	-Rejoining players get the survivor class (Fixed).
	-If somebody self infects, the first infected does not lose their gun (Fixed).
	-Limit lethals and tacticals to 1 (Unfixed, likely only solution is manually reducing grenades on scav notify).
	-Radar sweep in late game (Added).
	-If you are the only infected as a result of someone quitting, give you a gun (Maybe).
	-Equipment thrown before the first infected chosen will be lethal if they are no longer teammates (Maybe).
	-Dead silence / No tactical insertion placement annoucement (Maybe).
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
	setscoreboardcolumns("score", "kills", "deaths", "assists", "survived");
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
	precacheshellshock("mortarblast_enemy");
	level.onspawnplayer = ::onspawnplayer;
	level.onplayerkilled = ::onplayerkilled;
	level.ontimelimit = ::ontimelimit;
	level.gettimelimit = ::gettimelimit;
	level.givecustomloadout = ::loadout;
	level.loadout = [];
	level.loadout["primary"] = randomelement(strtok(getdvarstringdefault("infected_primary", "mp7_mp+fastads"), ","));
	level.loadout["secondary"] = randomelement(strtok(getdvarstringdefault("infected_secondary", "fnp45_mp"), ","));
	level.loadout["lethal"] = randomelement(strtok(getdvarstringdefault("infected_lethal", "sticky_grenade_mp"), ","));
	level.loadout["tactical"] = randomelement(strtok(getdvarstringdefault("infected_tactical", "flash_grenade_mp"), ","));
	level.allowtac = getdvarintdefault("infected_allowtac", 1);
	level.allowtomo = getdvarintdefault("infected_allowtomo", 1);
	level.devmode = getdvarintdefault("infected_devmode", 1);
	level.minplayers = getdvarintdefault("infected_minplayers", 2);
	level.moabvision = getdvarstringdefault("infected_moabvision", "tvguided_sp");
	level.infectedtable = [];
	level.infectedtext = createserverfontstring("objective", 1.4);
	level.infectedtext setgamemodeinfopoint();
	level.infectedtext.hidewheninmenu = 1;
	level.infectedtext.alpha = 0;
	level.quotamet = 0;
	level.activecountdown = 0;
	level.moabstarted = 0;
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
	if(level.activecountdown == 1){
		return;
	}else{
		level.activecountdown = 1;
	}
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
	level.activecountdown = 0;
}

detonatemoab(detonator){
	level endon("game_ended");
	level notify("stop_countdown");
	level.moabstarted = 1;
	level.activecountdown = 1;
	level.infectedtext.label = &"M.O.A.B. Inbound: ";
	level.infectedtext.alpha = 1;
	infectednotify(&"M.O.A.B.", detonator);
	for(i = 10; i > 0; i--){
		level.infectedtext setvalue(i);
		thread playsoundonplayers("mpl_flagcapture_sting_enemy");
		wait 1;
	}
	level.infectedtext.alpha = 0;
	thread playsoundonplayers("wpn_emp_bomb");
	earthquake(0.2, 5, (0,0,0), 900000);
	setdvar("timescale", 0.8);
	wait 0.1;
	setdvar("timescale", 0.6);
	wait 0.1;
	foreach(player in level.players){
		player shellshock("mortarblast_enemy", 4);
	}
	setdvar("timescale", 0.4);
	wait 0.1;
	setdvar("timescale", 0.2);
	visionsetnaked(level.moabvision, 2);
	wait 0.75;
	foreach(player in level.players){
		if(player.infected){
			player dodamage(9999, (0,0,0), detonator, detonator, "none", "MOD_SUICIDE");
			player stopshellshock();
		}
	}
	setdvar("timescale", 0.4);
	wait 0.05;
	setdvar("timescale", 0.8);
	wait 0.1;
	setdvar("timescale", 1);
	level.activecountdown = 0;
}

connect(){
	for(;;){
		level waittill("connected", player);
		if(level.devmode == 1) player thread devmode();
		player.firstinfected = false;
		if(isinarray(level.infectedtable, player.guid)){
			level notify("stop_countdown");
			level.infectedtext.alpha = 0;
			player.infected = true;
			player addtoteam("axis", true);
			player loadout();
		}else{
			player.infected = false;
			player addtoteam("allies", true);
		}
		updatescore();
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
	self maps/mp/gametypes/_wager::clearpowerups();
	if(level.quotamet == 0){
		return;
	}
	if(!self.infected){
		if (self.suicide == 1){
			level notify("stop_countdown");
			level.infectedtext.alpha = 0;
			foreach(player in level.players){
				if(player.firstinfected && (player != self)){
					player.firstinfected = false;
					player loadout();
				}
			}
		}else if(attacker.firstinfected){
				attacker.firstinfected = false;
				attacker loadout();
		}
		thread playsoundonplayers("mpl_flagcapture_sting_enemy", "allies");
		thread playsoundonplayers("mpl_flagcapture_sting_friend", "axis");
		self.infected = true;
		self addtoteam("axis", false);
		foreach(player in level.players){
			if(!player.infected){
				player.pers["survived"]++;
                player.survived = player.pers["survived"];
			}
		}
		infectednotify(&"Infected", self);
	}else{
		if(self.suicide == 0){
			if(!isdefined(attacker.infectedbonus)){
				attacker.infectedbonus = 0;
			}
			if(attacker.infectedbonus < level.poweruplist.size){
				attacker maps/mp/gametypes/_wager::givepowerup(level.poweruplist[attacker.infectedbonus]);
				attacker thread maps/mp/gametypes/_wager::wagerannouncer( "wm_bonus" + attacker.infectedbonus);
				attacker.infectedbonus++;
			}
			if(attacker.infectedbonus >= level.poweruplist.size){
				if(isdefined(attacker.powerups) && isdefined(attacker.powerups.size) && attacker.powerups.size > 0){
					attacker thread maps/mp/gametypes/_wager::pulsepowerupicon(attacker.powerups.size - 1);
				}
			}
			if(attacker.kills > 23){
				level thread detonatemoab(attacker);
			}
		}
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
	}else if(survivors == 1){
		foreach(player in level.players){
			if(player.infected) player setclientuivisibilityflag("g_compassShowEnemies", 1);
		}
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
		if(level.allowtomo) self giveweapon("hatchet_mp");
		if(level.allowtac) self giveWeapon("tactical_insertion_mp");
		if(self.firstinfected){
			self giveweapon(level.loadout["primary"]);
			self switchtoweapon(level.loadout["primary"]);
		}else{
			self switchtoweapon("knife_held_mp");
		}
	}else{
		foreach(weapon in level.loadout){
			self giveweapon(weapon);
		}
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
	maps/mp/gametypes/_wager::addpowerup("specialty_movefaster", "perk", &"PERKS_LIGHTWEIGHT", "perk_lightweight");
	maps/mp/gametypes/_wager::addpowerup("specialty_fallheight", "perk", &"PERKS_LIGHTWEIGHT", "perk_lightweight");
	maps/mp/gametypes/_wager::addpowerup("specialty_scavenger", "perk", &"PERKS_SCAVENGER", "perk_scavenger");
	maps/mp/gametypes/_wager::addpowerup("specialty_fastequipmentuse", "perk", &"PERKS_FAST_HANDS", "perk_fast_hands");
	maps/mp/gametypes/_wager::addpowerup("specialty_fasttoss", "perk", &"PERKS_FAST_HANDS", "perk_fast_hands");
	maps/mp/gametypes/_wager::addpowerup("specialty_fastweaponswitch", "perk", &"PERKS_FAST_HANDS", "perk_fast_hands");
	maps/mp/gametypes/_wager::addpowerup("specialty_fastreload", "perk", &"PERKS_FAST_HANDS", "perk_fast_hands");
	maps/mp/gametypes/_wager::addpowerup("specialty_longersprint", "perk", &"PERKS_EXTREME_CONDITIONING", "perk_marathon");
	maps/mp/gametypes/_wager::addpowerup("specialty_sprintrecovery", "perk", &"PERKS_DEXTERITY", "perk_dexterity");
	maps/mp/gametypes/_wager::addpowerup("specialty_fastmantle", "perk", &"PERKS_DEXTERITY", "perk_dexterity");
	maps/mp/gametypes/_wager::addpowerup("specialty_fastladderclimb", "perk", &"PERKS_DEXTERITY", "perk_dexterity");
	maps/mp/gametypes/_wager::addpowerup("specialty_earnmoremomentum", "perk", &"PERKS_HARDLINE", "perk_hardline");
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
	self notifyonplayercommand("radar", "radar");
	self notifyonplayercommand("moab", "moab");
    for(;;){
        command = self waittill_any_return("bot", "time", "radar", "moab");
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
			case "radar":
				self setclientuivisibilityflag("g_compassShowEnemies", 2);
				break;
			case "moab":
				level thread detonatemoab(self);
				break;
		}
    } 
}