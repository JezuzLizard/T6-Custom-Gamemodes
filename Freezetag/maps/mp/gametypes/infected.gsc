#include maps/mp/_utility;
#include maps/mp/gametypes/_globallogic;

/**
    T6 Infected.
    Updated: 15/03/2021.
    Version: 0.2.
    Authors: Birchy & JezuzLizard.
	Features:
	-Player quota.
	-Infection countdown.
	-Survivor/Infected/First infected loadouts.
	-Infection behaviour.
	-Survivor/Infected win condition and end text.
	-Team score is player count.
 */

 /**
	TODO (Not all possible as of 12/03/2021):
	-Popups for infection.
	-Score for surviving.
	-Audio queues.
	-Remove class select prompt.
	-Remove team switch ui.
	-Time limit reached should favour survivors and game end text should show this.
	-Countdown improved/Player quota moved to same place.
	-Randomised loadouts.
	-Randomised first spawn.
	-Specialist streaks.
	-MOAB.
	-Winners text.
	-Team names.
	-Gamemode name.
  */

init(){
	level.devmode = 1;
	level.minplayers = getdvarintdefault("infected_min_players", 3);
	level.loadoutkillstreaksenabled = 0;
	level.disableweapondrop = 1;
	level.allow_teamchange = "0";
	level.killedstub = level.onplayerkilled;
	level.onTimeLimit = ::survivors_win;
	level.onplayerkilled = ::killed();
	level.givecustomloadout = ::loadout();
	level thread infected();
	level thread connect();
}

infected(){
	level waittill("prematch_over");
	level thread server_wait_timeout();
	while(level.players.size < level.minplayers){
		iprintlnbold("Survivors ready " + level.players.size + "/" + level.minplayers);
		wait 1;
	}
	level notify( "gdm_player_quota_reached" );
	setgametypesetting("timelimit", 5); //This function makes no sense. The more you use it, the more confusing it gets.
	for(i = 10; i > 0; i--){
		iprintlnbold("Infection countdown: " + i);
		wait 1;
	}
	infect();
	for(;;){
		foreach(team in level.teams){
			members = 0;
			for(i = 0; i < level.players.size; i++){
				if(level.players[i].team == team) members++;
			}
			game["teamScores"][team] = members;
			maps/mp/gametypes/_globallogic_score::updateteamscores(team);
			if(team == "axis" && members == 0){ 
				endgame("allies", "Survivors eliminated");
			}else if(team == "allies" && members == 0){
				infect();
			}
		}
		wait 0.05;
	}
}

connect(){
	for(;;){
		level waittill("connected", player);
		player thread bot();
		player maps\mp\teams\_teams::changeteam("axis");
		player.infected = false;
		player.firstinfected = false;
	}
}

infect(){
	first = level.players[randomint(level.players.size)];
	first.firstinfected = true;
	first maps\mp\teams\_teams::changeteam("allies");
	iprintlnbold(first.name + " infected!");
}

killed(inflictor, attacker, damage, meansofdeath, weapon, dir, hitloc, timeoffset, deathanimduration){
	if(!self.infected){
		if(attacker.firstinfected){
			attacker.firstinfected = false;
			attacker loadout();
		}
		self.infected = true;
		self maps\mp\teams\_teams::changeteam("allies");
	}
	[[level.killedstub]](inflictor, attacker, damage, meansofdeath, weapon, dir, hitloc, timeoffset, deathanimduration);
}

loadout(){
	self clearperks();
	self setperk("specialty_fallheight");
	self setperk("specialty_fastequipmentuse");
	self setperk("specialty_fastladderclimb");
	self setperk("specialty_fastmantle");
	self setperk("specialty_fastmeleerecovery");
	self setperk("specialty_fasttoss");
	self setperk("specialty_fastweaponswitch");
	self setperk("specialty_longersprint");
	self setperk("specialty_sprintrecovery");
	self setperk("specialty_unlimitedsprint");
	self setperk("specialty_scavenger");
	self takeallweapons();
	self giveweapon("knife_mp");
	if(self.infected){
		self giveweapon("knife_held_mp");
		self giveweapon("hatchet_mp");
		self giveWeapon("tactical_insertion_mp");
		if(self.firstinfected){
			self giveweapon("pdw57_mp+silencer+extclip");
			self switchtoweapon("pdw57_mp+silencer+extclip");
		}else{
			self switchtoweapon("knife_held_mp");
		}
	}else{
		self giveweapon("pdw57_mp+silencer+extclip");
		self giveweapon("fiveseven_mp+fmj+extclip");
		self giveweapon("claymore_mp");
		self giveWeapon("flash_grenade_mp");
		self switchtoweapon("pdw57_mp+silencer+extclip");
	}
}

bot(){
	if(level.devmode == 0) return;
    self endon("disconnect");
    self notifyOnPlayerCommand( "bot", "bot");
    for(;;){
        self waittill("bot"); 
        maps\mp\bots\_bot::spawn_bot(self.team);
    } 
}

survivors_win(){
	makedvarserverinfo( "ui_text_endreason", "Survivors Win" );
	setdvar( "ui_text_endreason", "Survivors Win" );
	thread maps/mp/gametypes/_globallogic::endgame( "allies", "Survivors Win" );
}

server_wait_timeout()
{
	level endon( "gdm_player_quota_reached" );
	for ( i = 0; i < 300; i++ )
	{
		wait 1;
	}
	map_restart( false );
}