#include maps/mp/_utility;
#include common_scripts/utility;
#include maps/mp/gametypes/_globallogic;
#include maps/mp/gametypes/_hud_util;

/**
    T6 Infected.
    Updated: 15/03/2021.
    Version: 0.3.
    Authors: Birchy & JezuzLizard.
	Features:
	-Player quota.
	-Infection countdown.
	-Survivor/Infected/First infected loadouts.
	-Infection behaviour.
	-First infected doesn't suicide (Like MW3).
	-Client class and team select menu prompts removed.
	-Survivor/Infected win condition and end text.
	-Team score is player count.
	-Audio queues.
	-Random, configurable loadouts.
	-Randomised first spawn.
 */

 /**
	TODO (Not all possible as of 15/03/2021):
	-Popups for infection.
	-Score for surviving.
	-Specialist streaks.
	-MOAB.
	-Team names.
	-Gamemode name.
  */

init(){
	level.devmode = getdvarintdefault("infected_devmode", 0);
	level.minplayers = getdvarintdefault("infected_minplayers", 8);
	level.loadout = [];
	level.loadout["primary"] = randomelement(strtok(getdvarstringdefault("infected_primary", "mp7_mp+dualclip+fastads"), ","));
	level.loadout["secondary"] = randomelement(strtok(getdvarstringdefault("infected_secondary", "fnp45_mp"), ","));
	level.loadout["lethal"] = randomelement(strtok(getdvarstringdefault("infected_lethal", "sticky_grenade_mp"), ","));
	level.loadout["tactical"] = randomelement(strtok(getdvarstringdefault("infected_tactical", "flash_grenade_mp"), ","));
	level.allowtac = getdvarintdefault("infected_allowtac", 1);
	level.allowtomo = getdvarintdefault("infected_allowtomo", 1);
	level.ontimelimit = ::ontimelimit;
	level.gettimelimit = ::gettimelimit;
	level.usestartspawns = 0;
	level.onplayerkilled = ::killed;
	level.givecustomloadout = ::loadout;
	level thread infected();
	level thread connect();
}

infected(){
	level waittill("prematch_over");
	infectedtext = createserverfontstring("objective", 1.4);
	infectedtext.label = &"Extra survivors required: ";
	infectedtext setgamemodeinfopoint();
	infectedtext setvalue(2);
	infectedtext.hidewheninmenu = 1;
	level.addtime = false;
	level.addedtime = 0;
	if(level.players.size < level.minplayers){
		while(level.players.size < level.minplayers){
			wait 1;
			infectedtext setvalue(level.minplayers - level.players.size);
			level.addedtime++;
		}
	}
	level.addedtime /= 60;
	level.addtime = true;
	infectedtext.label = &"Infection countdown: ";
	for(i = 10; i > 0; i--){
		infectedtext setvalue(i);
		wait 1;
	}
	infectedtext destroy();
	infect();
	for(;;){
		foreach(team in level.teams){
			members = 0;
			for(i = 0; i < level.players.size; i++){
				if(level.players[i].team == team) members++;
			}
			game["teamScores"][team] = members;
			maps/mp/gametypes/_globallogic_score::updateteamscores(team);
			if(team == "allies" && members == 0){ 
				endgame("axis", "Survivors eliminated");
			}else if(team == "axis" && members == 0){
				infect();
			}
		}
		wait 0.5;
	}
}

connect(){
	for(;;){
		level waittill("connected", player);
		if(level.devmode == 1) player thread devmode();
		player addtoteam("allies", true);
		player.infected = false;
		player.firstinfected = false;
	}
}

infect(){
	first = level.players[randomint(level.players.size)];
	first.firstinfected = true;
	first.infected = true;
	first addtoteam("axis", false);
	first loadout();
	iprintlnbold(first.name + " infected!");
	thread playsoundonplayers("mpl_flagcapture_sting_enemy", "allies");
	thread playsoundonplayers("mpl_flagcapture_sting_friend", "axis");
}

addtoteam(team, firstconnect){
    self.pers["team"] = team;
    self.team = team;
	self.sessionteam = self.pers["team"];
    self maps/mp/gametypes/_globallogic_ui::updateobjectivetext();
	if(firstconnect) waittillframeend;
	self notify("end_respawn");
}

killed(inflictor, attacker, damage, meansofdeath, weapon, dir, hitloc, timeoffset, deathanimduration){
	//TODO: return if waiting for players, make them first infected if during countdown, make them infected if live (this will mean making the first infected guy not first infected loadout).
	if(!self.infected){
		thread playsoundonplayers("mpl_flagcapture_sting_enemy", "allies");
		thread playsoundonplayers("mpl_flagcapture_sting_friend", "axis");
		if(attacker.firstinfected){
			attacker.firstinfected = false;
			attacker loadout();
		}
		self.infected = true;
		self addtoteam("axis", false);
	}
	//maps/mp/gametypes/_globallogic_audio::leaderdialogonplayer("encourage_last"); //TODO: Audio doesn't work.
}

loadout(){
	self clearperks();
	self takeallweapons();
	self giveweapon("knife_mp");
	if(is_true(self.infected)){
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

ontimelimit(){
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