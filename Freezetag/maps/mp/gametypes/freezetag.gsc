
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
    level.playerdamagestub = level.callbackplayerdamage;
    level.callbackplayerdamage = ::callbackplayerdamagehook;
    level.givecustomloadout = ::loadout;
    level.loadoutkillstreaksenabled = 0;
    setscoreboardcolumns("", "", "score", "captures", "killsdenied");
    level thread connect();
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
        self thread ammo();
    }
}

ammo(){
    self endon("disconnect");
    for(;;){
        wait 0.1;
        weapon = self getcurrentweapon();
        self givemaxammo(weapon);
    }
}

frozen(){
    self endon("disconnect");
    self enableinvulnerability();
    self freezecontrols(1);
    self setclientthirdperson(1);
    self takeallweapons();
    wait 5; //TODO: Monitor teammates for distance etc etc, place waypoint for self above their head
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