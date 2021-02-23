#include maps/mp/gametypes/_globallogic_audio;
#include maps/mp/gametypes/_globallogic_score;
#include maps/mp/gametypes/_spawnlogic;
#include maps/mp/gametypes/_spawning;
#include maps/mp/gametypes/_gameobjects;
#include maps/mp/gametypes/_callbacksetup;
#include maps/mp/gametypes/_globallogic;
#include maps/mp/gametypes/_hud_util;
#include maps/mp/_utility;

/**
    T6 Freezetag.
    Description: Shoot enemies to freeze them, stand near your 
    frozen allies to free them. Last team with unfrozen players wins!
    Updated: 22/02/2021.
    Version: 0.1.
    Authors: Birchy & JezuzLizard.
 */

 /**
    Features:
    -Infinite ammo.
    -Server provided loadout.
    -Players freeze when shot.
    -Scores, captures and denies increase as a result 
    of freezing an enemy and unfreezing an ally.
  */

/**
    Intended features:
    Display frozen enemies/allies.
    'Ice' coloured hitmarkers.
    Visual sugar (frozen indicator to enemies and allies,
    objective progres bar for player unfreeze, visual fx
    at frozen players origin, sound effects for freezing, 
    unfreezing, trigger the +100 score visual if possible)
    Last team with an unfrozen player wins.
 */

init(){
    //Set the elimate enemy players text(or etc) to freeze enemy players.
    setscoreboardcolumns("", "", "score", "captures", "killsdenied");
    level.playerdamagestub = level.callbackplayerdamage;
    level.callbackplayerdamage = ::callbackplayerdamagehook;
    level.givecustomloadout = ::loadout;
    level.loadoutkillstreaksenabled = 0;
    level thread connect();
    level thread freezetag();
}

connect(){
    for(;;){
        level waittill("connected", player);
        player thread spawn();
    }
}

spawn(){
    level endon("game_ended");
    self endon("disconnect");
    for(;;){
        self waittill("spawned_player");
        self.frozen = false;
        self thread ammo();
    }
}

ammo(){
    self endon("disconnect");
    for(;;){
        weapon = self getcurrentweapon();
        self givemaxammo(weapon);
        wait 0.1;
    }
}

frozen(){
    self endon("disconnect");
    self enableinvulnerability();
    self freezecontrols(1);
    self setclientthirdperson(1);
    self takeallweapons();
    self.frozen = true;
    progress = 0;
    for(;;){
        wait 0.05;
        near = [];
        for(i = 0; i < level.players.size; i++){
            if(self.team == level.players[i].team){
                if(self != level.players[i] && distance(self.origin, level.players[i].origin) < 75){
                    near[near.size] = level.players[i];
                }
            }
        }
        if(near.size == 0 && progress < 50){
            progress--;
        }else if(progress < 50){
            progress += near.size;
        }else{
            for(i = 0; i < level.players.size; i++){
                level.players[i].killsdenied++;
                level.players[i].score += 100;
            }
            break;
        }
    }
    self loadout();
    self setclientthirdperson(0);
    self freezecontrols(0);
    self disableinvulnerability();
}

loadout(){
    camo = randomintrange(1,45);
    weapon = "ballista_mp";
    self takeallweapons();
    self clearperks();
    self giveweapon(weapon, 0, true(camo, 0, 0, 0, 0));
    self giveweapon("knife_mp", 0, true(camo, 0, 0, 0, 0));
    self giveweapon("knife_held_mp");
    self setspawnweapon(weapon);
    self setperk("specialty_fallheight");
    self setperk("specialty_fastladderclimb");
    self setperk("specialty_fastmantle");
    self setperk("specialty_unlimitedsprint");
    self setperk("specialty_sprintrecovery");
    return weapon;
}

callbackplayerdamagehook(einflictor, eattacker, idamage, idflags, smeansofdeath, sweapon, vpoint, vdir, shitloc, timeoffset, boneindex){
    self thread frozen();
    idamage = 0;
    eattacker.captures++;
    eattacker.score += 200;
    [[level.playerdamagestub]](einflictor, eattacker, idamage, idflags, smeansofdeath, sweapon, vpoint, vdir, shitloc, timeoffset, boneindex);
}

//VERY ugly method please refactor me, just a proof of concept
freezetag(){
    level waittill("prematch_over");
    for(;;){
        wait 0.1;
        activeteams = [];
        foreach(team in level.teams){
            frozenplayers = 0;
            totalplayers = 0;
            for(i = 0; i < level.players.size; i++){
                if(level.players[i].team == team){
                    totalplayers++;
                    if(level.players[i].frozen){
                        frozenplayers++;
                    }
                }
            }
            if(frozenplayers != totalplayers){
                activeteams[activeteams.size] = team;
            }
            game["teamScores"][team] = totalplayers - frozenplayers;
            maps/mp/gametypes/_globallogic_score::updateteamscores(team);
        }
        if(activeteams.size == 1){
            first = getsubstr(activeteams[0], 0, 1);
            first = toupper(first);
            rest = getsubstr(activeteams[0], 1);
            thread endgame(activeteams[0], first + rest + " froze all enemies"); //this can probably be changed to go off team score so it works for tdm with rounds.
            break;
        }
    }
}