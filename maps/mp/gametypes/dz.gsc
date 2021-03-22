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
	level.onspawnplayer = ::onspawnplayer;
	level.onspawnplayerunified = ::onspawnplayerunified;
	level.numzones = getdvarintdefault("dropzone_zones", 3);
	level.cratefreq = getdvarintdefault("dropzone_cratefreq", 15);
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
		maps/mp/_utility::setobjectivetext(team, &"OBJECTIVES_TDM");
		maps/mp/_utility::setobjectivehinttext(team, &"OBJECTIVES_TDM_HINT");
		maps/mp/_utility::setobjectivescoretext(team, &"OBJECTIVES_TDM_SCORE");
		maps/mp/gametypes/_spawnlogic::addspawnpoints(team, "mp_tdm_spawn");
		maps/mp/gametypes/_spawnlogic::placespawnpoints(maps/mp/gametypes/_spawning::gettdmstartspawnname(team));
	}
	maps/mp/gametypes/_spawning::updateallspawnpoints();
	level.mapcenter = maps/mp/gametypes/_spawnlogic::findboxcenter(level.spawnmins, level.spawnmaxs);
	setmapcenter(level.mapcenter);
	spawnpoint = maps/mp/gametypes/_spawnlogic::getrandomintermissionpoint();
	setdemointermissionpoint(spawnpoint.origin, spawnpoint.angles);
	precacheshader("waypoint_captureneutral");
	precacheshader("waypoint_capture");
	precacheshader("waypoint_defend");
	precachestring(&"Earned Care Package");
	level.dropzonefx = loadfx("misc/fx_ui_flagbase_" + game["axis"]);
	level.dropzones = createzones(level.numzones);
	level.dropzone = 0;
	level thread handlezones();
}

handlezones(){
	level endon("game_ended");
	level waittill("prematch_over");
	level thread monitorzones();
	level thread dropcrates(level.cratefreq);
	level.dropzonelabel = [];
	level.dropzonelabel[0] = &"Next Drop Zone in: 1:0";
	level.dropzonelabel[1] = &"Next Drop Zone in: 0:";
	level.dropzonelabel[2] = &"Next Drop Zone in: 0:0";
	level.dropzonetext = createserverfontstring("objective", 1.4);
	level.dropzonetext setgamemodeinfopoint();
	level.dropzonetext.hidewheninmenu = 1;
	level.dropzonetext.label = level.dropzonelabel[0];
	level.dropzonetext setvalue(0);
	handlefx();
	level thread clearhud();
	time = 60;
	for(;;){
		wait 1;
		time--;
		if(time == 0){
			time = 60;
			level.dropzonetext.label = level.dropzonelabel[0];
			level.dropzonetext setvalue(0);
			level.dropzone++;
			if(level.dropzone == level.dropzones.size){
				level.dropzone = 0;
			}
			playsoundonplayers("mp_suitcase_pickup");//no work :(
			handlefx();
		}else if(time > 9){
			level.dropzonetext.label = level.dropzonelabel[1];
			level.dropzonetext setvalue(time);
		}else{
			level.dropzonetext.label = level.dropzonelabel[2];
			level.dropzonetext setvalue(time);
		}
		//check zone players count, manage score accordingly, spawn crate if time to spawn crate.
		//update waypoints for team (contested, capture, defend)
	}
}

monitorzones(){
	level endon("game_ended");
	for(;;){
		foreach(player in level.players){
			if(!isdefined(player.inside)) player.inside = false;
			if(!isdefined(player.timeinside)) player.timeinside = 0;
			if(isalive(player)){
				if(distance2D(player.origin, level.dropzones[level.dropzone]) < 200){
					if(!player.inside) player iprintlnbold("Hold the Drop Zone!");
					player.inside = true;
					player.timeinside++;
				}else{
					if(player.inside) player iprintlnbold("Get to the Drop Zone!");
					player.inside = false;
					player.timeinside = 0;
				}
			}
		}
		wait 0.05;
	}
}

dropcrates(time){
	level endon("game_ended");
	for(;;){
		longestplayer = undefined;
		longest = 0;
		foreach(player in level.players){
			if(isdefined(player.timeinside) && isalive(player) && player.timeinside > longest){
				longest = player.timeinside;
				longestplayer = player;
			}
		}
		if(!isdefined(longestplayer)){
			iprintln("nobody");
			wait 0.5;
		}else{
			iprintln("should");
			level thread maps\mp\killstreaks\_supplydrop::heliDeliverCrate(level.dropzones[level.dropzone], "supplydrop_mp", longestplayer, longestplayer.team, 0, 0);
			foreach(player in level.players){
				player luinotifyevent(&"player_callout", 2, &"Earned Care Package", longestplayer.entnum);
			}
			wait time;
		}
	}
}

handlefx(){
	level.currentfx delete();
	tracestart = level.dropzones[level.dropzone] + vectorScale((0,0,1), 32);
	traceend = level.dropzones[level.dropzone] + vectorScale((0,0,-1), 32);
	trace = bullettrace(tracestart, traceend, 0, undefined);
	upangles = vectorToAngles(trace["normal"]);
	level.currentfx = spawnfx(level.dropzonefx, level.dropzones[level.dropzone], trace["position"], anglesToForward(upangles), anglesToRight(upangles));
	triggerfx(level.currentfx);
}

clearhud(){
	level waittill("game_ended");
	level.dropzonetext.alpha = 0;
}

createzones(num){
	bound = (level.spawnMaxs - level.mapCenter) * 0.9;
	mapnodes = getallnodes();
	candidates = [];
	index = 0;
	foreach(node in mapnodes){
		if(insidebounds(node.origin, bound)){
			if(bullettracepassed(node.origin, node.origin + (0,0,1000), false, undefined)){
				candidates[index] = node.origin;
				index++;
			}
		}
	}
	closestpoint = (0,0,0);
	closest = 999999;
	foreach(point in candidates){
		distance = distance2D(level.mapCenter, point);
		if(distance < closest){
			closest = distance;
			closestpoint = point;
		}
	}
	zones = [];
	zones[0] = closestpoint;
	for(i = 1; i < num; i++){
		furthestpoint = zones[i - 1];
		furthest = 0;
		foreach(point in candidates){
			distance = distance2D(zones[i - 1], point);
			if(distance > furthest){
				furthest = distance;
				furthestpoint = point;
			}
		}
		zones[i] = furthestpoint;
	}
	return zones;
}

insidebounds(origin, bounds){//can be replaced with just a distance2d check from the center when our brains work
	mins = level.mapCenter - bounds;
    maxs = level.mapCenter + bounds;
    if ( origin[0] > maxs[0] )
        return false;
    if ( origin[0] < mins[0] )
        return false;
    if ( origin[1] > maxs[1] )
        return false;
    if ( origin[1] < mins[1] )
        return false;
    return true;
}

onspawnplayerunified(){
	self.usingobj = undefined;
	maps/mp/gametypes/_spawning::onspawnplayer_unified();
}

onspawnplayer(predictedspawn){
	pixbeginevent("TDM:onSpawnPlayer");
	self.usingobj = undefined;
	spawnteam = self.pers["team"];
	if(level.ingraceperiod){
		spawnpoints = maps/mp/gametypes/_spawnlogic::getspawnpointarray(maps/mp/gametypes/_spawning::gettdmstartspawnname(spawnteam));
		if(!spawnpoints.size){
			spawnpoints = maps/mp/gametypes/_spawnlogic::getspawnpointarray(maps/mp/gametypes/_spawning::getteamstartspawnname(spawnteam, "mp_sab_spawn"));
		}
		if(!spawnpoints.size){
			spawnpoints = maps/mp/gametypes/_spawnlogic::getteamspawnpoints(spawnteam);
			spawnpoint = maps/mp/gametypes/_spawnlogic::getspawnpoint_nearteam(spawnpoints);
		}else{
			spawnpoint = maps/mp/gametypes/_spawnlogic::getspawnpoint_random(spawnpoints);
		}
	}else{
		spawnpoints = maps/mp/gametypes/_spawnlogic::getteamspawnpoints(spawnteam);
		spawnpoint = maps/mp/gametypes/_spawnlogic::getspawnpoint_nearteam(spawnpoints);
	}
	if(predictedspawn){
		self predictspawnpoint(spawnpoint.origin, spawnpoint.angles);
	}else{
		self spawn(spawnpoint.origin, spawnpoint.angles, "tdm");
	}
	pixendevent();
}