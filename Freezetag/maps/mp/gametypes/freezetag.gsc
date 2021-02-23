#include maps\mp\gametypes\_hud_util;
#include maps\mp\_utility;
#include maps\common_scripts\utility;
#include maps\mp\gametypes\_globallogic;

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
    Unfreeze behaviour (With progress bar).
    Last team with an unfrozen player wins.
 */

init(){
    if ( getDvarInt("freezetag_railgun_mode") == 1){
        level.freezetaguserailgunmode = true;
    }
    else{
        level.freezetaguserailgunmode = false;
    }
    initializefreezetagteamstructs();
    level thread trackremainingteams();
    //Set the elimate enemy players (or etc) to freeze enemy players.
    setscoreboardcolumns("", "", "score", "captures", "killsdenied");
    level.playerdamagestub = level.callbackplayerdamage;
    level.callbackplayerdamage = ::callbackplayerdamagehook;
    level.givecustomloadout = ::loadout;
    level.loadoutkillstreaksenabled = 0;
    level.scorelimit = 0;
    level.overrideteamscore = 1;
    level.endgameonscorelimit = 0;
    level.mayspawn = ::freezetagmayspawn;
    level thread connect();
}

connect(){
    for(;;){
        level waittill("connected", player);
        if (level.freezetaguserailgunmode){
            self setplayerspread( 0 );
            self setspreadoverride( 1 );
        }
        player thread spawn();
    }
}

spawn(){
    level endon("game_ended");
    self endon("disconnect");
    for(;;){
        self waittill("spawned_player");
        self thread ammo();
        self.frozen = false;
        self.progressbar = createsecondaryprogressbar();
        self.progressbartext = createsecondaryprogressbartext();
        self.progressbar hideelem();
        self.progressbartext hideelem();
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

//this is messy tidy it
frozen(){
    self endon("disconnect");
    self enableinvulnerability();
    self freezecontrols(1);
    self setclientthirdperson(1);
    self takeallweapons();
    self.frozen = true;
    level.freezetagteams[self.team].numfrozen++;
    if(level.freezetagteams[self.team].numfrozen == getplayers(self.team).size){
        level.freezetagteams[self.team].eliminated = true;
        level notify("freezetagteameliminated", self.team);
        return;
    }
    self.progressbartext settext("BEING UNFROZEN");
    progress = 0;
    for(;;){
        near = [];
        //less efficient but god help me the other version didnt work
        for(i = 0; i < level.players.size; i++){
            if(self.team == level.players[i].team){
                if(self != level.players[i] && distance(self.origin, level.players[i].origin) < 75){
                    near[near.size] = level.players[i];
                }
                level.player[i].progressbar hideelem();
                level.player[i].progressbartext hideelem();
            }
        }
        if(near.size > 0){
            progress += near.size;
        }else{
            progress--;
        }
        if(progress < 0){
            progress = 0;
            self.progressbar hideelem();
            self.progressbartext hideelem();
        }else if(progress < 50){
            self.progressbar showelem();
            self.progressbartext showelem();
            self.progressbar updatebar(progress / 50, 0.5);
            for(i = 0; i < near.size; i++){
                near[i].progressbartext settext("SAVING TEAMMATE");
                near[i].progressbar updatebar(progress / 50, 0.5);
                near[i].progressbartext showelem();
                near[i].progressbar showelem();
            }
        }else{
            self.progressbar hideelem();
            self.progressbartext hideelem();
             for(i = 0; i < near.size; i++){
                near[i].progressbartext hideelem();
                near[i].progressbar hideelem();
            }
            break;
        }
        wait 0.05;
    }
    self loadout();
    self setclientthirdperson(0);
    self freezecontrols(0);
    self disableinvulnerability();
    level.freezetagteams[self.team].numfrozen--;
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

trackremainingteams(){
    level.totalteamseliminated = 0;
    while(true){
        level waittill("freezetagteameliminated", team);
        level.totalteamseliminated++;
        if(level.multiTeam){
            foreach(player in getplayers(team)){
                    player setclientthirdperson(0);
                    player freezecontrols(0);
                    player disableinvulnerability();
                    player.freezetageliminated = true;
                    player [[level.spawnspectator]]();
            }
        }
        if(level.totalteamseliminated == (level.teams.size - 1)){
            winner = level.teams["allies"];
            foreach(team in level.teams){
                if(!level.freezetagteams[team].eliminated){
                    winner = level.teams[team];
                }
            }
            [[ level._setteamscore ]]( winner, game[ "roundswon" ][ winner ] );
            endGame( winner );
        }
    }
}

isplayervalid(){
    if(self.frozen){
        return false;
    }
    if(self.freezetagteam.eliminated){
        return false;
    }
    foreach(team in level.teams){
        if(self.team == team && level.freezetagteams[team].eliminated){
            return false;
        }
    }
    return true;
}

initializefreezetagteamstructs(){
    level.freezetagteams = [];
    foreach(team in level.teams){
        level.freezetagteams[team] = spawnstruct();
        level.freezetagteams[team].eliminated = false;
        level.freezetagteams[team].numfrozen = 0;
    }
}

freezetagmayspawn(){
    if(is_true(player.freezetageliminated)){
        return false;
    }
}