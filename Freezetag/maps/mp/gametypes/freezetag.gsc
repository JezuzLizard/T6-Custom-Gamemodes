#include maps/mp/gametypes/_globallogic_audio;
#include maps/mp/gametypes/_globallogic_score;
#include maps/mp/gametypes/_spawnlogic;
#include maps/mp/gametypes/_spawning;
#include maps/mp/gametypes/_gameobjects;
#include maps/mp/gametypes/_callbacksetup;
#include maps/mp/gametypes/_globallogic;
#include maps/mp/gametypes/_hud_util;
#include maps/mp/_utility;
#include maps/mp/gametypes/_gameobjects;
#include maps/mp/gametypes/dom;

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
    level.flagmodel[ "allies" ] = maps/mp/teams/_teams::getteamflagmodel( "allies" );
	level.flagmodel[ "axis" ] = maps/mp/teams/_teams::getteamflagmodel( "axis" );
	level.flagmodel[ "neutral" ] = maps/mp/teams/_teams::getteamflagmodel( "neutral" );
	precachemodel( level.flagmodel[ "allies" ] );
	precachemodel( level.flagmodel[ "axis" ] );
	precachemodel( level.flagmodel[ "neutral" ] );
    level.freezetagfx = [];
    level.freezetagfx[0] = loadfx( "misc/fx_ui_oneflag_flagbase" );
    level.freezetagfx[1] = loadfx( "misc/fx_ui_flagbase_" + game[ "axis" ] );
}

connect(){
    for(;;){
        level waittill("connected", player);
        player.hud_damagefeedback.color = ( 0.2, 0.5, 0.8 );
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

    trigger = spawn("trigger_radius",self.origin,0,160,128);
    trigger.targetname = "flag_primary";
    visuals = [];
    visuals[0] = spawn("script_model", trigger.origin); 
	visuals[0].angles = trigger.angles;
	visuals[0] setmodel(level.flagmodel["neutral"]); //we probably don't need a model here but

    //an attempt at getting proximity triggers like dom to work for us
    freeze_trigger = maps/mp/gametypes/_gameobjects::createuseobject(self.team,trigger,visuals,(0,0,0),"_a");
    freeze_trigger maps/mp/gametypes/_gameobjects::allowuse( "friendly" );
    freeze_trigger maps/mp/gametypes/_gameobjects::setusetime( 3 );
    freeze_trigger maps/mp/gametypes/_gameobjects::setusetext( &"MP_CAPTURING_FLAG" );
    label = freeze_trigger maps/mp/gametypes/_gameobjects::getlabel();
    freeze_trigger maps/mp/gametypes/_gameobjects::setvisibleteam( "friendly" );
    tracestart = visuals[0].origin + vectorScale((0,0,1),32);
    traceend = visuals[0].origin + vectorScale((0,0,-1),32);
    trace = bullettrace(tracestart,traceend,0,undefined);
    upangles = vectorToAngles(trace["normal" ]);
    freeze_trigger.baseeffectforward = anglesToForward( upangles );
    freeze_trigger.baseeffectright = anglesToRight( upangles );
    freeze_trigger.baseeffectpos = trace[ "position" ];
    freeze_trigger.label = label;
    freeze_trigger.flagindex = 0; //trigger.script_index
    freeze_trigger.onuse = ::onuse; //crashes the server 
    freeze_trigger.onbeginuse = ::onbeginuse;
    freeze_trigger.onuseupdate = ::onuseupdate;
    freeze_trigger.onenduse = ::onenduse;
    freeze_trigger.onupdateuserate = ::onupdateuserate;

    fx = [];
    //this fx is only visible to your team
    fx[0] = spawnfx( level.freezetagfx[0], freeze_trigger.baseeffectpos, freeze_trigger.baseeffectforward, freeze_trigger.baseeffectright );
	triggerfx( fx[0] );
    //this fx is visible to everyone except your team
    fx[1] = spawnfx( level.freezetagfx[1], freeze_trigger.baseeffectpos, freeze_trigger.baseeffectforward, freeze_trigger.baseeffectright );
	triggerfx( fx[1] );
    //visuals[0] setinvisibletoall();
    for(i=0; i<level.players.size; i++)
    {
        if(level.players[i].team != self.team)
        {
            visuals[0] setinvisibletoplayer(level.players[i]);
            fx[0] setinvisibletoplayer(level.players[i]);
        }
        else
        {
            fx[1] setinvisibletoplayer(level.players[i]);
        }
    }

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
    fx[0] delete();
    fx[1] delete();
    freeze_trigger destroyobject( true, true );
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
    if(self.team == eattacker.team){
        return;
    }
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
            /*
            first = getsubstr(activeteams[0], 0, 1);
            first = toupper(first);
            rest = getsubstr(activeteams[0], 1);
            */
            thread endgame(activeteams[0], /*first + rest*/ toupper(game[activeteams[0]]) + " froze all enemies"); //this can probably be changed to go off team score so it works for tdm with rounds.
            break;
        }
    }
}

onuse( player )
{
	team = player.pers[ "team" ];
	oldteam = self maps/mp/gametypes/_gameobjects::getownerteam();
	label = self maps/mp/gametypes/_gameobjects::getlabel();
	player logstring( "flag captured: " + self.label );
	self maps/mp/gametypes/_gameobjects::setownerteam( team );
	setdvar( "scr_obj" + self maps/mp/gametypes/_gameobjects::getlabel(), team );
	self resetflagbaseeffect();
	level.usestartspawns = 0;
	isbflag = 0;
	string = &"";
	switch( label )
	{
		case "_a":
			string = &"MP_DOM_FLAG_A_CAPTURED_BY";
			break;
		case "_b":
			string = &"MP_DOM_FLAG_B_CAPTURED_BY";
			isbflag = 1;
			break;
		case "_c":
			string = &"MP_DOM_FLAG_C_CAPTURED_BY";
			break;
		case "_d":
			string = &"MP_DOM_FLAG_D_CAPTURED_BY";
			break;
		case "_e":
			string = &"MP_DOM_FLAG_E_CAPTURED_BY";
			break;
		default:
			break;
	}
	touchlist = [];
	touchkeys = getarraykeys( self.touchlist[ team ] );
	for ( i = 0; i < touchkeys.size; i++ )
	{
		touchlist[ touchkeys[ i ] ] = self.touchlist[ team ][ touchkeys[ i ] ];
	}
}

onbeginuse( player )
{
	ownerteam = self maps/mp/gametypes/_gameobjects::getownerteam();
	self.didstatusnotify = 0;
	if ( ownerteam == "allies" )
	{
		otherteam = "axis";
	}
	else
	{
		otherteam = "allies";
	}
	if ( ownerteam == "neutral" )
	{
		otherteam = getotherteam( player.pers[ "team" ] );
		statusdialog( "securing" + self.label, player.pers[ "team" ], "gamemode_changing" + self.label );
		return;
	}
}

onuseupdate( team, progress, change )
{
	if ( progress > 0.05 && change && !self.didstatusnotify )
	{
		ownerteam = self maps/mp/gametypes/_gameobjects::getownerteam();
		if ( ownerteam == "neutral" )
		{
			otherteam = getotherteam( team );
			statusdialog( "securing" + self.label, team, "gamemode_changing" + self.label );
		}
		else
		{
			statusdialog( "losing" + self.label, ownerteam, "gamemode_changing" + self.label );
			statusdialog( "securing" + self.label, team, "gamemode_changing" + self.label );
		}
		self.didstatusnotify = 1;
	}
}

onenduse( team, player, success )
{
	if ( !success )
	{
		maps/mp/gametypes/_globallogic_audio::flushgroupdialog( "gamemode_changing" + self.label );
	}
}

onupdateuserate()
{
	if ( !isDefined( self.contested ) )
	{
		self.contested = 0;
	}
	numother = getnumtouchingexceptteam( self.ownerteam );
	numowners = self.numtouching[ self.claimteam ];
	previousstate = self.contested;
	if ( numother > 0 && numowners > 0 )
	{
		self.contested = 1;
	}
	else if ( previousstate == 1 )
	{
		self notify( "contest_over" );
	}
	self.contested = 0;
}