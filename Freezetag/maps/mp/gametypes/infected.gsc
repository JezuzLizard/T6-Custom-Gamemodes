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
	level thread pre_game();
}

infected(){ //TODO: Tidy the inf loop.
	thread add_bots(); //temp
	level waittill( "gdm_player_quota_reached" );
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

on_player_disconnect()
{
	self waittill( "disconnect" );
	level.gdm_player_num_required++;
	level notify( "gdm_update_wait_message" );
}

connect(){
	for(;;){
		level waittill("connected", player);
		player thread on_player_disconnect();
		level.gdm_player_num_required--;
		level notify( "gdm_update_wait_message" );
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
	while ( level.players.size < 1 )
	{
		wait 1;
	}
	thread spawnBot( 16 );
}

spawnBot( value )
{
	for( i = 0; i < value; i++ )
	{
		self thread maps\mp\bots\_bot::spawn_bot( "axis" );
		wait 5;
	}
}

pre_game(){
	level.gdm_player_num_required = getDvarIntDefault( "infected_min_players", 3 );
	level waittill( "prematch_over" );
	maps/mp/_utility::registertimelimit( 0, 0 );
	level thread wait_message_text_updater();
	while ( level.gdm_player_num_required > 0 ){
		wait 1;
	}
	level notify( "gdm_player_quota_reached" );
	if ( isDefined( level.gdm_wait_message ) ){
		level.gdm_wait_message destroy();
	}
	maps/mp/_utility::registertimelimit( 0, 720 );
}

create_wait_message_hud(){
	waiting = newHudElem();
   	waiting.horzAlign = "center";
   	waiting.vertAlign = "middle";
   	waiting.alignX = "center";
   	waiting.alignY = "middle";
   	waiting.y = 0;
   	waiting.x = -1;
   	waiting.foreground = 1;
   	waiting.fontscale = 3.0;
   	waiting.alpha = 1;
   	waiting.color = ( 1.000, 1.000, 1.000 );
	waiting.hidewheninmenu = 1;
	return waiting;
}

wait_message_text_updater(){
	level endon( "game_ended" );
	level endon( "gdm_player_quota_reached" );
	while ( 1 ){
		if ( level.gdm_player_num_required > 1 ){
			player_text = "Players";
		}
		else{
			player_text = "Player";
		}
		level.gdm_wait_message = create_wait_message_hud();
		level.gdm_wait_message setText( "Waiting For " + level.gdm_player_num_required + " More " + player_text );
		level waittill( "gdm_update_wait_message" );
		if ( isDefined( level.gdm_wait_message ) ){
			level.gdm_wait_message destroy();
		}
	}
}