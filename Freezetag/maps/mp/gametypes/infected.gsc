#include maps/mp/_utility;
#include maps/mp/gametypes/_globallogic;

/**
    T6 Infected.
    Updated: 12/03/2021.
    Version: 0.1.
    Authors: Birchy & JezuzLizard.
 */

 /**
	TODO (Not all possible as of 12/03/2021):
	-Popups for infection.
	-Score for surviving.
	-Audio queues.
	-Time limit reached should favour survivors and game end text should show this.
	-Countdown improved.
	-Randomised loadouts.
	-Randomised first spawn.
	-Specialist streaks.
	-MOAB.
	-Winners text.
	-Team names.
	-Gamemode name.
  */

init(){//Should work as barebones infected implementation.
	level.killedstub = level.onplayerkilled;
	level.onplayerkilled = ::killed();
	level.givecustomloadout = ::loadout();
	level.loadoutkillstreaksenabled = 0;
	level.disableweapondrop = 1;
	level thread infected();
	level thread connect();
}

infected(){ //TODO: Tidy the inf loop.
	thread add_bots(); //temp
	level waittill("prematch_over");
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

infect(){
	first = level.players[randomint(level.players.size)];
	first.firstinfected = true;
	first maps\mp\teams\_teams::changeteam("allies");
	iprintlnbold(first.name + " infected!");
}

connect(){
	for(;;){
		level waittill("connected", player);
		player maps\mp\teams\_teams::changeteam("axis");
		player.infected = false;
		player.firstinfected = false;
	}
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

//temp 
add_bots()
{
	players = get_players();
	while ( players.size < 1 )
	{
		players = get_players();
		wait 1;
	}
	thread spawnBot( 16 );
}

spawnBot( value )
{
	for( i = 0; i < value; i++ )
	{
		self thread maps\mp\bots\_bot::spawn_bot( "axis" );
	}
}