#undef REQUIRE_PLUGIN
#include "include/updater.inc"
#include "include/morecolors.inc"
#define REQUIRE_PLUGIN

#include <tf2_stocks>
#include <sdkhooks>
//#include <dhooks>
#include <vector>
#include <clientprefs>
#include <sdktools_functions>

#pragma semicolon 1 // required for logs.tf
#pragma newdecls required

#define VERSION "3.0.0"

// Macros
#define CV ConVar
#define Ac Action
#define Han Handle
#define GD GameData 

// Utility functions for chat events
stock v ChatEvent(const char[] format, any ...) {
  if (bChatEvents.BoolValue) {
    int len = strlen(format) + 255;
    char[] MessageToChat = new char[len];
    VFormat(MessageToChat, len, format, 2);
    TagChatAllPlayers(MessageToChat);
  }
}

stock v ChatEventToClients(const char[] format, any ...) {
  if (bChatEvents.BoolValue) {
    int len = strlen(format) + 255;
    char[] MessageToChat = new char[len];
    VFormat(MessageToChat, len, format, 2);
    for (int x = 1; x < MaxClients + 1; x++) {
      if (!IsValidClient(x) || IsClientSourceTV(x)) continue;
      TagChatClient(x, MessageToChat);
    }
  }
}

stock v SendCountdownToClients(int time) {
  for (int x = 1; x < MaxClients + 1; x++) {
    if (!IsValidClient(x) || !arrbClientSettings[x].bCountdown) continue;
    
    switch (time) {
      case 10: TagChatClient(x, "{pass_red}10 seconds...");
      case 5:  TagChatClient(x, "{pass_yellow}5 seconds...");
      case 4:  TagChatClient(x, "{pass_yellow}4 seconds...");
      case 3:  TagChatClient(x, "{pass_yellow}3 seconds...");
      case 2:  TagChatClient(x, "{pass_green}2 seconds...");
      case 1:  TagChatClient(x, "{pass_green}1 second...");
    }
  }
}

stock v SendSoundCountdownToClients(const char[] sound) {
  for (int x = 1; x < MaxClients + 1; x++) {
    if (!IsValidClient(x) || !arrbClientSettings[x].bCountdown) continue;
    
    if (StrEqual(sound, "Announcer.RoundBegins10seconds"))
      TagChatClient(x, "{pass_red}10 seconds...");
    elif (StrEqual(sound, "Passtime.BallSpawn"))
      TagChatClient(x, "{pass_green}Ball has spawned!");
    if (bHalloweenMode) {
      if (StrEqual(sound, "Merasmus.RoundBegins5seconds"))
        TagChatClient(x, "{pass_yellow}5 seconds...");
      elif (StrEqual(sound, "Merasmus.RoundBegins4seconds"))
        TagChatClient(x, "{pass_yellow}4 seconds...");
      elif (StrEqual(sound, "Merasmus.RoundBegins3seconds"))
        TagChatClient(x, "{pass_yellow}3 seconds...");
      elif (StrEqual(sound, "Merasmus.RoundBegins2seconds"))
        TagChatClient(x, "{pass_green}2 seconds...");
      elif (StrEqual(sound, "Merasmus.RoundBegins1seconds"))
        TagChatClient(x, "{pass_green}1 second...");
    }
    else {
      if (StrEqual(sound, "Announcer.RoundBegins5seconds"))
        TagChatClient(x, "{pass_yellow}5 seconds...");
      elif (StrEqual(sound, "Announcer.RoundBegins4seconds"))
        TagChatClient(x, "{pass_yellow}4 seconds...");
      elif (StrEqual(sound, "Announcer.RoundBegins3seconds"))
        TagChatClient(x, "{pass_yellow}3 seconds...");
      elif (StrEqual(sound, "Announcer.RoundBegins2seconds"))
        TagChatClient(x, "{pass_green}2 seconds...");
      elif (StrEqual(sound, "Announcer.RoundBegins1seconds"))
        TagChatClient(x, "{pass_green}1 second...");
    }
  }
}

stock v ShowJackHud(int client) {
  if (arrbClientSettings[client].bJackHud) {
    SetHudTextParams(-1.0, 0.22, 3.0, 240, 0, 240, 255);
    ShowHudText(client, 1, "YOU HAVE THE JACK");
  }
}

stock v HideJackHud(int client) {
  if (arrbClientSettings[client].bJackHud) {
    SetHudTextParams(-1.0, 0.22, 3.0, 240, 0, 240, 255);
    ShowHudText(client, 1, "");
  }
}

stock v PlayJackSound(int client) {
  if (arrbClientSettings[client].bJackSound) {
    ClientCommand(client, "playgamesound Passtime.BallSmack");
  }
}

stock v ShowJackChat(int client, const char[] message) {
  if (arrbClientSettings[client].bJackChat) {
    TagChatClient(client, "%s%s", "{pass_green}", message);
  }
}

stock b IsFeatureEnabled(CV cvar) {
  return cvar.BoolValue;
}

stock v LogGameEvent(const char[] eventName, const char[] format, any ...) {
  int len = strlen(format) + 255;
  char[] MessageToLog = new char[len];
  VFormat(MessageToLog, len, format, 2);
  LogToGame("\"%s\" %s", eventName, MessageToLog);
}

stock v LogScoreEvent(int scorer, int points, bool panacea, bool winstrat, bool deathbomb, f dist) {
  SetLogInfo(scorer);
  LogGameEvent("pass_score", "(points \"%i\") (panacea \"%d\") (win strat \"%d\") (deathbomb \"%d\") (dist \"%.0f\") (position \"%.0f %.0f %.0f\")",
              points, panacea, winstrat, deathbomb, dist,
              user1position[0], user1position[1], user1position[2]);
}

stock v LogAssistEvent(int assistant) {
  c assistantName[MAX_NAME_LENGTH];
  GetClientName(assistant, assistantName, sizeof(assistantName));
  SetLogInfo(assistant);
  LogGameEvent("pass_score_assist", "(position \"%.0f %.0f %.0f\")",
              user1position[0], user1position[1], user1position[2]);
  arriClientRoundStats[assistant].iAssists++;
}

stock v HandleDeathbombScoring(int scorer, int points, f dist) {
  arrbPanaceaCheck[scorer] = false;
  LogScoreEvent(entDeathBomber, points, arrbPanaceaCheck[scorer], arrbWinStratCheck[scorer], true, dist);
  arriClientRoundStats[entDeathBomber].iScores++;
  arriClientRoundStats[entDeathBomber].iDeathbombs++;
  LogAssistEvent(scorer);
}

stock v HandleNormalScoring(int scorer, int points, bool panacea, bool winstrat, bool deathbomb, f dist, int assistant) {
  LogScoreEvent(scorer, points, panacea, winstrat, deathbomb, dist);
  arriClientRoundStats[scorer].iScores++;
  
  if (assistant > 0) {
    LogAssistEvent(assistant);
  }
}

stock v ShowScoreMessage(int scorer, int assistant, bool panacea, bool winstrat, bool deathbomb, f dist) {
  c playerNameTeamFormatted[MAX_TEAMFORMAT_NAME_LENGTH], assistantNameTeamFormatted[MAX_TEAMFORMAT_NAME_LENGTH];
  FormatPlayerNameWithTeam(scorer, playerNameTeamFormatted);
  
  if (panacea && TF2_GetPlayerClass(scorer) != TFClass_Medic) {
    ChatEvent("%s{pass_green} scored a {pass_green}Panacea!", playerNameTeamFormatted);
    TagChatSTV("%s scored a Panacea. t%d", playerName, STVTickCount());
  }
  elif (winstrat) {
    ChatEvent("%s{pass_green} scored a {pass_green}win strat!", playerNameTeamFormatted);
    TagChatSTV("%s scored a win strat. t%d", playerName, STVTickCount());
  }
  elif (deathbomb) {
    int deathBomber = entDeathBomber;
    c playerName[MAX_NAME_LENGTH];
    GetClientName(deathBomber, playerName, sizeof(playerName));
    FormatPlayerNameWithTeam(deathBomber, playerNameTeamFormatted);
    ChatEvent("%s{pass_green} scored a {pass_green}deathbomb!", playerNameTeamFormatted);
    TagChatSTV("%s scored a deathbomb. t%d", playerName, STVTickCount());
  }
  elif (dist > 1600) {
    ChatEvent("%s{pass_green} scored a goal from a distance of %.0fhu!", playerNameTeamFormatted, dist);
    TagChatSTV("%s scored a goal from distance of %.0fhu. t%d", playerName, dist, STVTickCount());
  }
  elif (assistant > 0) {
    FormatPlayerNameWithTeam(assistant, assistantNameTeamFormatted);
    ChatEvent("%s{pass_green} scored a goal {chat}assisted by %s!", playerNameTeamFormatted, assistantNameTeamFormatted);
    TagChatSTV("%s scored a goal assisted by %s. t%d", playerName, assistantName, STVTickCount());
  }
  else {
    ChatEvent("%s{pass_green} scored a goal!", playerNameTeamFormatted);
    TagChatSTV("%s scored a goal. t%d", playerName, STVTickCount());
  }
}

stock v LogBallSpawn(const char[] spawnName, int caller) {
  c logMessage[64];
  if (StrEqual(spawnName, "passtime_ball_spawn1")) {
    Format(logMessage, sizeof(logMessage), "passtime_ball spawned upper.");
    GetEntPropVector(caller, Prop_Send, "m_vecOrigin", fTopSpawnPos);
  }
  elif (StrEqual(spawnName, "passtime_ball_spawn2")) {
    Format(logMessage, sizeof(logMessage), "passtime_ball spawned lower.");
    ibBallSpawnedLower = 1;
  }
  elif (StrEqual(spawnName, "passtime_ball_spawn3")) {
    Format(logMessage, sizeof(logMessage), "passtime_ball spawned right.");
  }
  elif (StrEqual(spawnName, "passtime_ball_spawn4")) {
    Format(logMessage, sizeof(logMessage), "passtime_ball spawned left.");
  }
  else {
    return; // Unknown spawn name, don't log
  }
  
  LogToGame(logMessage);
  TagChatSTV("%s", logMessage);
}

stock v LogCatapultEvent(const char[] catapultName) {
  SetLogInfo(iPlyWhoGotJack);
  LogGameEvent("%s with the jack", catapultName, "(position \"%.0f %.0f %.0f\")",
              user1position[0], user1position[1], user1position[2]);
  arriClientRoundStats[iPlyWhoGotJack].iCatapults++;
}

stock v LogBallDamage(int victim, int attacker, int inflictor, f damage, int damagetype, const char[] classname) {
  LogToGame("passtime_ball took damage victim '%d' attacker '%d' inflictor '%d' damage '%.2f' damagetype '%d' inflictor classname '%s'", 
            victim, attacker, inflictor, damage, damagetype, classname);
}

stock v LogPassFree() {
  SetLogInfo(owner);
  LogGameEvent("pass_free", "(position \"%.0f %.0f %.0f\")",
              user1position[0], user1position[1], user1position[2]);
}

stock v LogPassBallBlocked(int blocker, int thrower) {
  SetLogInfo(blocker, thrower);
  LogGameEvent("pass_ball_blocked", "against \"%N<%i><%s><%s>\" (thrower_position \"%.0f %.0f %.0f\") (blocker_position \"%.0f %.0f %.0f\")",
              user2, GetClientUserId(user2), user2steamid, user2team,
              user1position[0], user1position[1], user1position[2],
              user2position[0], user2position[1], user2position[2]);
}

stock v LogPassCaught(int catcher, int thrower, bool intercept, bool save, bool handoff, f dist, f duration) {
  SetLogInfo(catcher, thrower);
  LogGameEvent("pass_pass_caught", "against \"%N<%i><%s><%s>\" (interception \"%i\") (save \"%i\") (handoff \"%i\") (dist \"%.3f\") (duration \"%.3f\") (thrower_position \"%.0f %.0f %.0f\") (catcher_position \"%.0f %.0f %.0f\")",
              user2, GetClientUserId(user2), user2steamid, user2team,
              intercept, save, handoff, dist, duration,
              user1position[0], user1position[1], user1position[2],
              user2position[0], user2position[1], user2position[2]);
}

stock v LogPassBallStolen(int thief, int victim, bool steal2save) {
  SetLogInfo(thief, victim);
  LogGameEvent("pass_ball_stolen", "against \"%N<%i><%s><%s>\" (steal defense \"%d\") (thief_position \"%.0f %.0f %.0f\") (victim_position \"%.0f %.0f %.0f\")",
              user2, GetClientUserId(user2), user2steamid, user2team,
              steal2save,
              user1position[0], user1position[1], user1position[2],
              user2position[0], user2position[1], user2position[2]);
}

#define NOTIFY FCVAR_NOTIFY

#define GENERIC ADMFLAG_GENERIC
#define CONFIG ADMFLAG_CONFIG

#define HE HookEvent
#define HCC HookConVarChange
#define HEO HookEntityOutput
#define RC RegConsoleCmd
#define RA RegAdminCmd
#define RCC RegClientCookie
#define AC CAddColor
#define CC CreateConVar
#define EvI GetEventInt
#define EvF GetEventFloat

#define PC return Plugin_Continue
#define PCh return Plugin_Changed
#define PH return Plugin_Handled
#define PS return Plugin_Stop

#define b bool
#define c char
#define e enum
#define f float
#define int int
#define s struct
#define t TFTeam
#define Ck Cookie
#define pub public
#define v void
#define es enum struct

#define elif else if

e {
  COLOR_FORMAT_LENGTH = 7,
  MAX_TEAMFORMAT_NAME_LENGTH = COLOR_FORMAT_LENGTH + MAX_NAME_LENGTH,
  MAX_ENTITIES = 4096,
  GOALIE_DISTANCE = 200,  // hu
  GOAL_HEAL_HEIGHT = 330 // hu
}

// Constants
#define GOAL_HEAL_RADIUS 500.0 // hu
#define GOAL_HEAL_RADIUS_SQR (GOAL_HEAL_RADIUS * GOAL_HEAL_RADIUS)  // hu

// e BallState
// {
// 	STATE_OUT_OF_PLAY,
// 	STATE_FREE,
// 	STATE_CARRIED
// };

// if anyone else was confused on wtf an enum struct was:
// read: https://wiki.alliedmods.net/SourcePawn_Transitional_Syntax#Enum_Structs
// basically: emulating a struct through an array. i.e. an array with named indices
// because SOURCEPAWN DOESN'T SUPPORT STRUCTS??
es enuClientSettings {
  b bCountdown;
  b bJackHud;
  b bJackChat;
  b bJackSound;
  int iSummary;
}

es enuClientStats {
  int iScores;
  int iAssists;
  int iSaves;
  int iIntercepts;
  int iSteals;
  int iSplashes;
  int iPanaceas;
  int iWinstrats;
  int iDeathbombs;
  int iHandoffs;
  int iFirstGrabs;
  int iCatapults;
  int iBlocks;
  int iSteal2Saves;
}

enuClientSettings arrbClientSettings[MAXPLAYERS + 1];
enuClientStats arriClientRoundStats[MAXPLAYERS + 1];

f fBluGoalPos[3], fRedGoalPos[3], fTopSpawnPos[3], fFreeBallPos[3];

CV bFixStocks;
CV bFixRespawnBypass;
CV bFixBlur;
// CV trikzEnable, trikzProjCollide, trikzProjDev;
CV bFixJackCollision;
CV bChatEvents;
CV bWinstratKills;
CV bChatEventsFun;
CV bPractice;
CV bVerboseLogs;
CV bMedicSplash;
CV bMedicSplashPush;
CV bResupply;
CV flResupplyCooldown;
CV flGoalRegeneration;

int iPlyWhoGotJack;
// int plyDirecter;
int ibFirstGrabCheck;
int entJack;
int entPassTarget;
int ibBallSpawnedLower;
int iRoundResetTick;
int iWinStratDistance;
int entDeathBomber;
int iBallPickedUpTick;
int iRedBallTime;
int iBluBallTime;
// i trikzProjCollideCurVal;
// i trikzProjCollideSave = 2;
Menu mPassMenu;
b bWaitingForBallSpawnToRestart;
b bRoundActive;
b bHalloweenMode;
b bBallLoose;         // Is the ball currently loose (is the passtime_ball entity on the map)?
b bBallSplashed;      // check if ball splashed for panacea checks
t eLastTickBallTeam;  // in effect, this is "last thrown ball team"
b arrbPlyIsDead [MAXPLAYERS + 1];
b arrbBlastJumpStatus [MAXPLAYERS + 1];  // true if blast jumping, false if has landed
b arrbPanaceaCheck [MAXPLAYERS + 1];
b arrbWinStratCheck [MAXPLAYERS + 1];
b arrbDeathbombCheck [MAXPLAYERS + 1];
f nextInstantResupplyTime[MAXPLAYERS + 1];
// b plyTakenDirectHit[MAXPLAYERS + 1];
Ck cookieCountdownCaption, cookieJACKPickupHud, cookieJACKPickupChat, cookieJACKPickupSound, cookieSummary;

// log variables
int user1;
c user1steamid[16];
c user1team[12];
f user1position[3];
int user2;
c user2steamid[16];
c user2team[12];
f user2position[3];

// stats menu variables
c moreurl[128];

Han tfPlayerForceRegenerateAndRespawn;
Han pointInRespawnRoom;
GD gameData;

pub Plugin myinfo = {
  name = "4v4 PASS Time Extension",
  author = "https://discord.passtime.tf/",
  description = "The main plugin for 4v4 Competitive PASS Time.",
  version = VERSION,
  url = "https://github.com/p4sstime/p4sstime-server-resources/releases"
};

pub v OnPluginStart() {
  GD = new GameData("p4sstime"); // Load config

  // Cookies
  cookieCountdownCaption = RCC("p4ssClientCountdownCaption",  "p4sstime's client setting (1/0) for captions for JACK spawn timer", CookieAccess_Public);
  cookieJACKPickupHud =    RCC("p4ssClientJACKPickupHudText", "p4sstime's client setting (1/0) for HUD text when picking up JACK", CookieAccess_Public);
  cookieJACKPickupChat =   RCC("p4ssClientJACKPickupChatMsg", "p4sstime's client setting (1/0) for chat msg when picking up JACK", CookieAccess_Public);
  cookieJACKPickupSound =  RCC("p4ssClientJACKPickupSound",   "p4sstime's client setting (1/0) for sound when picking up JACK",    CookieAccess_Public);
  cookieSummary =          RCC("p4ssClientSummary",           "p4sstime's client setting (0/1/2) for EoR summaries",               CookieAccess_Public);

  // Client commands
  RC("sm_pt_menu",         CMenu);
  RC("sm_pt_countdown",    CChatCountdown);
  RC("sm_pt_summary",      CChatSummary);
  RC("sm_pt_pickup_hud",   CJackPickupHud);
  RC("sm_pt_pickup_chat",  CJackPickupChat);
  RC("sm_pt_pickup_sound", CJackPickupSound);
  RC("sm_pt_suicide",      CSuicide);
  RC("sm_pt_kill",         CSuicide);
  RC("sm_pt_resupply",     CResupply);

  // Admin commands
  RA("sm_pt_snapshot",  CSnapshot,  GENERIC, "Take a snapshot of the plugin's current variable values.");
  RA("sm_pt_spawnball", CSpawnBall, GENERIC,  "Spawn the ball forcefully, by game starting and tournament restarting.");

  // Colors
  AC("plugin_tag",   0x96BD63); // #96BD63
  AC("warning",      0xECCD19); // #eccd19
  AC("error",        0xd64843); // #d64843

  AC("chat",         0xBBBBBB); // #bbbbbb
  AC("red_team",     0xD64843); // #d64843
  AC("blu_team",     0x438CD6); // #438cd6

  AC("pass_blue",    0x438CD6); // #438cd6
  AC("pass_green",   0x3CB371); // #3CB371
  AC("pass_teal",    0x008B8B); // #008B8B
  AC("pass_red",     0xD64843); // #d64843
  AC("pass_magenta", 0xA946C7); // #a946c7
  AC("pass_orange",  0xDD8125); // #dd8125
  AC("pass_yellow",  0xECCD19); // #eccd19

  // ConVars
  bFixStocks =          CC("sm_pt_fix_stocks",         "0",   "Disable equipping shotgun, stickies, and needles; the allowlist can't block stock weapons.",       NOTIFY);
  bFixRespawnBypass =   CC("sm_pt_fix_respawn_bypass", "0",   "Disable switching classes while dead to respawn immediately.",                                     NOTIFY);
  bFixJackCollision =   CC("sm_pt_fix_jack_collision", "1",   "Disable jack collision on ammo packs and weapons.",                                                NOTIFY);
  bFixBlur =            CC("sm_pt_fix_blur",           "0",   "Enable blurry screen overlay when intercepting or stealing.",                                      NOTIFY);
  bChatEvents =         CC("sm_pt_chat_events",        "0",   "Enable printing of passtime events to chat both during and after games. Does not affect logging.", NOTIFY);
  bChatEventsFun =      CC("sm_pt_chat_events_fun",    "0",   "If sm_pt_print_events is 1, enable printing additional fun stats.",                                NOTIFY);
  bWinstratKills =      CC("sm_pt_kill_winstrats",     "0",   "Enable killing winstratters and printing \"tried to winstrat\" in chat.",                          NOTIFY);
  bVerboseLogs =        CC("sm_pt_logs_verbose",       "0",   "Enable printing additional information to logs.");
  bMedicSplash =        CC("sm_pt_medic_splash",       "1",   "Enable medic arrows neutralizing the jack.",                                                       NOTIFY);
  bMedicSplashPush =    CC("sm_pt_medic_splash_push",  "1",   "If sm_pt_medic_splash is 1, enable crossbow push on the jack.",                                    NOTIFY);
  bResupply =           CC("sm_pt_resupply",           "0",   "Enable instant resupply.",                                                                         NOTIFY);
  flResupplyCooldown =  CC("sm_pt_resupply_cooldown",  "0.5", "Set the resupply cooldown duration in seconds.",                                                   NOTIFY);
  flGoalRegeneration =  CC("sm_pt_goal_regeneration",  "0",   "Set the amount of health regeneration every 500ms while in the goal zone.",                        NOTIFY);
  bPractice =           CC("sm_pt_practice",           "0",   "Enable practice mode. When the round timer reaches 5 minutes, add 5 minutes to the timer.",        NOTIFY, true, 0.0, true, 1.0);
  // trikzEnable =      CC("sm_pt_trikz",                 "0", "Set 'trikz' mode. 1 adds friendly knockback for airshots, 2 adds friendly knockback for splash damage, 3 adds friendly knockback for everywhere", NOTIFY, true, 0.0, true, 3.0);
  // trikzProjCollide = CC("sm_pt_trikz_projcollide",     "2", "Manually set team projectile collision behavior when trikz is on. 2 always collides, 1 will cause your projectiles to phase through if you are too close (default game behavior), 0 will cause them to never collide.", 0, true, 0.0, true, 2.0);
  // trikzProjDev =     CC("sm_pt_trikz_projcollide_dev", "0", "DONOTUSE; This command is used solely by the plugin to change values. Changing this manually may cause issues.", FCVAR_HIDDEN, true, 0.0, true, 2.0);

  // Hooks
  HE("player_spawn",                 EPlayerSpawn);
  HE("post_inventory_application",   EPlayerResup);
  HE("player_death",                 EPlayerDeath);
  HE("pass_get",                     EPassGet);
  HE("pass_free",                    EPassFree);
  HE("pass_ball_stolen",             EPassStolen);
  HE("pass_score",                   EPassScore);
  HE("pass_pass_caught",             EPassCaught);
  HE("pass_ball_blocked",            EPassBallBlocked);
  HE("rocket_jump",                  ERocketJump);
  HE("rocket_jump_landed",           ERocketJumpLand);
  HE("sticky_jump",                  EPipeJump);
  HE("sticky_jump_landed",           EPipeJumpLand);
  HE("teamplay_pre_round_time_left", EPregameCountdown);
  HE("teamplay_broadcast_audio",     EMidgameCountdown);
  HE("teamplay_round_active",        EPlayersCanMove);
  HE("teamplay_round_win",           ETeamWin);
  HE("stats_resetround",             ERoundReset);

  HEO("trigger_catapult",         "OnCatapulted", EOOnCatapult);
  HEO("info_passtime_ball_spawn", "OnSpawnBall",  EOOnSpawnBall);

  AddCommandListener(OnChangeClass, "joinclass");

  HCC(bPractice, Hook_OnPracticeModeChange);
  HCC(bResupply, Hook_OnAllowInstantResupplyChange);
  // HCC(trikzEnable, Hook_OnTrikzChange);
  // HCC(trikzProjCollide, Hook_OnProjCollideChange);
  // HCC(trikzProjDev, Hook_OnProjCollideDev);

  CreateTimer(0.5, GoalHealTimer, 0, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
  /*for (i client = 1; client <= MaxClients; client++)
    if (IsClientInGame(client))
      OnClientPutInServer(client);*/
  for (int i = MaxClients; i > 0; --i) {
    if (!AreClientCookiesCached(i)) {
      continue;
    }
    OnClientCookiesCached(i);
  }

  c sMapNameBuffer[256];
  GetCurrentMap(sMapNameBuffer, 256);
  VerboseLog("Current map buffer -> %s", sMapNameBuffer);
  // check if stadium is the current map in order to set the height lower
  // see OnMapInit
  // this is necessary as OnMapInit is not called when the plugin is ran
  if (StrContains(sMapNameBuffer, "stadium", false) != -1) {
    iWinStratDistance = 150;
  }
  else {
    iWinStratDistance = 400;
  }

  int jackIndex = FindEntityByClassname(-1, "passtime_ball");
  if (jackIndex != -1) entJack = jackIndex;

  if (LibraryExists("updater")) {
    OnLibraryAdded("updater");
  }

  // SDKHooks
  StartPrepSDKCall(SDKCall_Player);
  PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "CTFPlayer::ForceRegenerateAndRespawn");
  tfPlayerForceRegenerateAndRespawn = EndPrepSDKCall();
  if (tfPlayerForceRegenerateAndRespawn == null)
    LogError("Failed to find CTFPlayer::ForceRegenerateAndRespawn -- certain features may be non-functional");

  StartPrepSDKCall(SDKCall_Static);
  PrepSDKCall_SetFromConf(gameData, SDKConf_Signature, "PointInRespawnRoom");
  PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
  PrepSDKCall_AddParameter(SDKType_Vector,      SDKPass_ByRef);
  PrepSDKCall_AddParameter(SDKType_Bool,        SDKPass_ByValue);
  PrepSDKCall_SetReturnInfo(SDKType_Bool,       SDKPass_ByValue);
  pointInRespawnRoom = EndPrepSDKCall();
  if (pointInRespawnRoom == null)
    LogError("Failed to find PointInRespawnRoom -- certain features may be non-functional");
}

pub v OnLibraryAdded(const char[] name) {
  // if (StrEqual(name, "updater"))
  // {
  //   Updater_AddPlugin(
  //     "https://raw.githubusercontent.com/p4sstime/p4sstime-server-resources/refs/heads/updater/updatefile.txt");
  // }
}

// Modules
#include "p4sstime/stocks.sp"
#include "p4sstime/snapshot.sp"
#include "p4sstime/logs.sp"
#include "p4sstime/pass_menu.sp"
#include "p4sstime/practice.sp"
#include "p4sstime/anticheat.sp"
#include "p4sstime/convars.sp"
#include "p4sstime/stats_print.sp"
#include "p4sstime/f2stocks.sp"
#include "p4sstime/spawnball.sp"
//#include <p4sstime/trikz.sp>

pub Ac GoalHealTimer(Han timer) {
  // LogMessage("GoalHealTimer popped");
  if (flGoalRegeneration.FloatValue == 0.0) PC;
  for (int client_idx = 1; client_idx < MaxClients + 1; client_idx++) {
    if (!IsValidClient(client_idx) || IsClientSourceTV(client_idx)) continue;
    f position[3];
    GetClientAbsOrigin(client_idx, position);

    tteam = TF2_GetClientTeam(client_idx);
    if (team == TFTeam_Spectator || team == TFTeam_Unassigned) {
      continue;  // skip this player
    }
    int health = GetClientHealth(client_idx);
    int max_health = GetPlayerMaxHealthTF2(client_idx);

    if (health >= max_health) PC;

    f distance_sqr, vertical_difference;
    if (team == TFTeam_Red) {
      distance_sqr = GetVectorDistance(position, fRedGoalPos, true);
      vertical_difference = FloatAbs(fRedGoalPos[2] - position[2]);
    }
    else {
      distance_sqr = GetVectorDistance(position, fBluGoalPos, true);
      vertical_difference = FloatAbs(fBluGoalPos[2] - position[2]);
    }
    if (distance_sqr < GOAL_HEAL_RADIUS_SQR && vertical_difference < GOAL_HEAL_HEIGHT) {
      VerboseLog("player \"%d\": distance '%f' (max distance '%f'), vertical_difference '%f'", client_idx, distance_sqr, GOAL_HEAL_RADIUS_SQR, vertical_difference);

      SetEntityHealth(client_idx, min(health + flGoalRegeneration.IntValue, max_health));
    }
  }
  PC;
}

pub v OnMapInit(const char[] mapName) {
  if (StrContains(mapName, "stadium", false) != -1)  // stadium has much lower top spawner so do this to av false positive win strats
    iWinStratDistance = 150;
  else
    iWinStratDistance = 400;
}

pub v OnMapStart() { // get goal locations
  int goal1 = FindEntityByClassname(-1, "func_passtime_goal");
  int goal2 = FindEntityByClassname(goal1, "func_passtime_goal");
  int team1 = GetEntProp(goal1, Prop_Send, "m_iTeamNum");
  if (team1 == 2) {
    GetEntPropVector(goal1, Prop_Send, "m_vecOrigin", fBluGoalPos);
    GetEntPropVector(goal2, Prop_Send, "m_vecOrigin", fRedGoalPos);
  }
  else {
    GetEntPropVector(goal2, Prop_Send, "m_vecOrigin", fBluGoalPos);
    GetEntPropVector(goal1, Prop_Send, "m_vecOrigin", fRedGoalPos);
  }
}

pub v OnMapEnd() {
  entJack = 0;
}

pub v OnGameFrame() {
  if (bBallLoose) {
    tballTeam = GetBallTeam();
    if (ballTeam != eLastTickBallTeam) {
      VerboseLog("Ball team changed from %d (%s) to %d (%s)", eLastTickBallTeam, TFTeamToString(eLastTickBallTeam), ballTeam, TFTeamToString(ballTeam));
      f ballPos[3];
      GetEntPropVector(entJack, Prop_Send, "m_vecOrigin", ballPos);
      f distFromBluGoal = GetVectorDistance(ballPos, fBluGoalPos);
      f distFromRedGoal = GetVectorDistance(ballPos, fRedGoalPos);
      VerboseLog("Loose ball distance from goals: \"blu\" \"%.2f\" \"red\" \"%.2f\"", distFromBluGoal, distFromRedGoal);
      if (bChatEvents.BoolValue && bChatEventsFun.BoolValue) {
        if (distFromBluGoal <= 120) {
          ChatEvent("The ball went neutral %.2fhu {chat}from the goal!", distFromBluGoal - 20);
        }
        elif (distFromRedGoal <= 120) {
          ChatEvent("The ball went neutral %.2fhu {chat}from the goal!", distFromRedGoal - 20);
        }
      }
    }
    eLastTickBallTeam = ballTeam;
  }
}

pub v OnEntityCreated(int eIndex, const char[] eClassname) {
  // // wrap it around and double check cvar
  // // bad but avs an unnecessary string cmp
  // if (bVerboseLogs.BoolValue)
  // {
  //   if (StrEqual(eClassname, "tf_projectile_rocket"))
  //   {
  //     VerboseLog("tf_projectile_rocket spawned, i: %d", eIndex);
  //   }
  // }
  if (StrEqual(eClassname, "passtime_ball")) {
    VerboseLog("passtime_ball spawned i \"%d\"", eIndex);
    SetJack(eIndex);
  }
  if (bMedicSplash.BoolValue) {
    if (StrEqual(eClassname, "tf_projectile_healing_bolt")) {
      VerboseLog("tf_projectile_healing_bolt spawned.");
      SDKHookEx(eIndex, SDKHook_StartTouchPost, MedicArrowTouchedSomething);
    }
  }
}

Ac PasstimeBallTookDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype) {
  tballTeam = eLastTickBallTeam;
  c classname[128];
  GetEntityClassname(inflictor, classname, sizeof(classname));
  LogBallDamage(victim, attacker, inflictor, damage, damagetype, classname);
  tplayerTeam = TF2_GetClientTeam(attacker);

  c playerName[MAX_NAME_LENGTH];
  GetClientName(attacker, playerName, sizeof(playerName));
  VerboseLog("passtime_ball damage debug: attacker '%s', attacker team: '%s' (indice '%d')", playerName, TFTeamToString(playerTeam), playerTeam);
  VerboseLog("passtime_ball damage debug: ballteam '%s' (indice '%d')", TFTeamToString(ballTeam), ballTeam);
  // so incredibly ugly
  VerboseLog("passtime_ball damage debug: playerWhoSplashed: %d, playerTeam: %s, ballTeam: %s", attacker, TFTeamToString(playerTeam), TFTeamToString(ballTeam));
  bBallSplashed = true;
  switch (playerTeam) {
    case TFTeam_Blue: {
      VerboseLog("passtime_ball damage debug: player team is BLU, checking if in blu goal and if ball is red.");
      if (EntInBluGoalZone(entJack) && ballTeam == TFTeam_Red) {
        VerboseLog("passtime_ball damage debug: all successful, this is a successful splash");
        c playerNameTeam[MAX_TEAMFORMAT_NAME_LENGTH];
        GetClientName(attacker, playerName, sizeof(playerName));
        FormatPlayerNameWithTeam(attacker, playerNameTeam);
        ChatEvent("%s {blu_team}splashed the ball to save!", playerNameTeam);
        TagChatSTV("%s splashed the ball to save it. t%d", playerName, STVTickCount());
        arriClientRoundStats[attacker].iSplashes++;
      }
    }
    case TFTeam_Red: {
      VerboseLog("passtime_ball damage debug: player team is RED, checking if in red goal and if ball is blu.");

      if (EntInRedGoalZone(entJack) && ballTeam == TFTeam_Blue) {
        VerboseLog("passtime_ball damage debug: all successful, this is a successful splash");
        c playerNameTeam[MAX_TEAMFORMAT_NAME_LENGTH];
        GetClientName(attacker, playerName, sizeof(playerName));
        FormatPlayerNameWithTeam(attacker, playerNameTeam);
        ChatEvent("%s {blu_team}splashed the ball to save!", playerNameTeam);
        TagChatSTV("%s splashed the ball to save it. t%d", playerName, STVTickCount());
        arriClientRoundStats[attacker].iSplashes++;
      }
    }
  }

  PC;
}

v MedicArrowTouchedSomething(int arrow, int other) {
  c classname[64];
  GetEntityClassname(other, classname, 64);
  int eiMedicAttacker = EntRefToEntIndex(GetEntPropEnt(arrow, Prop_Data, "m_hOwnerEntity"));
  if (StrEqual(classname, "passtime_ball")) {
    if (bMedicSplashPush.BoolValue) {
      // smart solution: damage the ball using the arrow's position relative to the jack's position
      f jackPosition[3], arrowPosition[3], damageForce[3];
      GetEntPropVector(other, Prop_Send, "m_vecOrigin", jackPosition);
      GetEntPropVector(arrow, Prop_Send, "m_vecOrigin", arrowPosition);
      VerboseLog("JackPosition: '%.1f' '%.1f' '%.1f' arrowPosition '%.1f' '%.1f' '%.1f'", jackPosition[0], jackPosition[1], jackPosition[2], arrowPosition[0], arrowPosition[1], arrowPosition[2]);
      MakeVectorFromPoints(jackPosition, arrowPosition, damageForce);
      ScaleVector(damageForce, -10.0);
      VerboseLog("DamageForce: '%.1f' '%.1f' '%.1f'", damageForce[0], damageForce[1], damageForce[2]);

      SDKHooks_TakeDamage(
        other,            // victim (ball)
        arrow,            // inflictor (arrow)
        eiMedicAttacker,  // offender (medic)
        10.0,             // damage
        0, -1,            // weapon, damagetype (n/a)
        damageForce,      // force vector
        arrowPosition,    // origin vector
        false // should bypass hooks
      );
    }
    else {
      // dumb solution: simply neutral the ball by hitting it with 50 damage
      SDKHooks_TakeDamage(other, arrow, eiMedicAttacker, 50.0, -1, -1, NULL_VECTOR, NULL_VECTOR, false);
    }

    c medicAttackerNameTeamFmt[MAX_TEAMFORMAT_NAME_LENGTH];
    FormatPlayerNameWithTeam(eiMedicAttacker, medicAttackerNameTeamFmt);
    ChatEvent("%s%s directed the ball with an arrow!", medicAttackerNameTeamFmt, COLOR_MEDIC_SPLASH);
    // TagChatAllPlayers("%s directed the ball with an arrow!", MedicAttackerName);
  }
  VerboseLog("medic arrow from %d touched %s i %d", eiMedicAttacker, classname, other);
}

Ac ERoundReset(Event event, const char[] name, b dontBroadcast) {
  for (int i = 0; i < MaxClients + 1; i++)
    ClearLocalStats(i);
  iRedBallTime = 0;
  iBluBallTime = 0;
  bBallLoose = false;
  bRoundActive = false;
  if (GetCVInt(bPractice) == 1) {
    SetCVInt(bPractice, 0);
    TagChatGlobal("Game started; practice mode disabled.");
  }
  bHalloweenMode = false;
  iRoundResetTick = GetGameTickCount();
  PH;
}

Ac EPregameCountdown(Event event, const char[] name, b dontBroadcast) {
  int time = event.GetInt("time");
  SendCountdownToClients(time);
  PH;
}

Ac EMidgameCountdown(Event event, const char[] name, b dontBroadcast) {
  // if it is halloween, announcer always says 10 seconds, but merasmus says 5-1
  // for pregame, announcer ALWAYS says start

  c sound[128];
  event.GetString("sound", sizeof(sound));
  if (StrEqual(sound, "Passtime.Merasmus.Laugh"))  // if this occurs (which it does during halloween right after ball spawn), assume halloween
    bHalloweenMode = true;
  SendSoundCountdownToClients(sound);
  PH;
}

Ac EPlayersCanMove(Event event, const char[] name, b dontBroadcast) {
  int offset = GameConfGetOffset(gameData, "CTFPlayer::m_bPasstimeBallSlippery");
  for (int x = 1; x < MaxClients + 1; x++) {
    if (!IsValidClient(x)) continue;

    // fix by Underscore; if ply goes AFK for long enough (even in pregame) they get attached a flag (m_bPasstimeBallSlippery) that causes teammates to be able to steal from them that doesn't go away. this makes it go away every time a round starts
    Address entity_address = GetEntityAddress(x);
    StoreToAddress(view_as<Address>(view_as<int>(entity_address) + offset), 0, NumberType_Int8, false);
  }

  bRoundActive = true;
  PH;
}

Ac ETeamWin(Event event, const char[] name, b dontBroadcast) {
  if (!bChatEvents.BoolValue) PH;
  CreateTimer(0.5, Timer_DisplayStats);
  iPlyWhoGotJack = 0;  // reset this because it's a good idea. doesn't actually fix anything but this shouldn't carry over between rounds
  PH;
}

int STVTickCount() {
  int tick;
  tick = GetGameTickCount() - iRoundResetTick;
  return tick;
}

b IsValidClient(int client, b blockbots = true) {
  if (client > 4096) client = EntRefToEntIndex(client);
  if (client <= 0 || client > MaxClients) return false;
  if (!IsClientInGame(client)) return false;
  if (blockbots && IsFakeClient(client)) return false;
  if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
  return true;
}

/*-------------------------------------------------- Player Events --------------------------------------------------*/
pub Ac OnClientSayCommand(int client, const char[] command, const char[] sArgs) {
  if (StrEqual(sArgs, "/more", false) || StrEqual(sArgs, ".more", false)) {
    CreateTimer(0.1, Timer_ShowMoreTF, client, TIMER_FLAG_NO_MAPCHANGE);
    PH;
  }
  elif (StrEqual(sArgs, "/pass", false) || StrEqual(sArgs, "/p4ss", false) || StrEqual(sArgs, ".pass", false) || StrEqual(sArgs, ".p4ss", false)) {
    ShowPassMenu(client);
    PH;
  }
  PC;
}

b TraceEntityFilterPlayer(int entity, int contentsMask)  { // taken from mgemod; just going to use this instead of isvalidclient for the below function 
  return entity > MaxClients || !entity;
}

f DistanceAboveGround(int victim) { // taken from mgemod 
  f vStart[3];
  f vEnd[3];
  f vAngles[3] = { 90.0, 0.0, 0.0 };
  GetClientAbsOrigin(victim, vStart);
  Han trace = TR_TraceRayFilterEx(vStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);

  f distance = -1.0;
  if (TR_DidHit(trace)) {
    TR_GetEndPosition(vEnd, trace);
    distance = GetVectorDistance(vStart, vEnd, false);
  }
  else LogError("trace error. victim %N(%d)", victim, victim);

  delete trace;
  return distance;
}

Ac ERocketJump(Event event, const char[] name, b dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  arrbBlastJumpStatus[client] = true;
  PH;
}

Ac ERocketJumpLand(Event event, const char[] name, b dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  arrbBlastJumpStatus[client] = false;
  PH;
}

Ac EPipeJump(Event event, const char[] name, b dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  arrbBlastJumpStatus[client] = true;
  PH;
}

Ac EPipeJumpLand(Event event, const char[] name, b dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  arrbBlastJumpStatus[client] = false;
  PH;
}

// the below function is dr underscore's fix. thanks!
pub v TF2_OnConditionRemoved(int client, TFCond condition) {
  if (condition == TFCond_Ubercharged)
    TF2_RemoveCondition(client, TFCond_UberchargeFading);
}

Ac EPlayerDeath(Event event, const char[] name, b dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  arrbPlyIsDead[client] = true;
  if (client == entPassTarget) {
    entDeathBomber = client;
    arrbDeathbombCheck[entDeathBomber] = true;
  }
  PH;
}

pub v OnClientDisconnect(int client) {
  ClearLocalStats(client);
}

/*-------------------------------------------------- PASS Events --------------------------------------------------*/
v EOOnSpawnBall(const char[] name, int caller, int activator, f delay) {
  c spawnName[24];
  entJack = FindEntityByClassname(-1, "passtime_ball");

  bBallLoose = true;
  ibBallSpawnedLower = 0;
  if (!bFixJackCollision.BoolValue) SetEntityCollisionGroup(entJack, 4);
  if (bWaitingForBallSpawnToRestart) {
    ServerCommand("mp_tournament_restart");
    bWaitingForBallSpawnToRestart = false;
  }
  GetEntPropString(caller, Prop_Data, "m_iName", spawnName, sizeof(spawnName));
  LogBallSpawn(spawnName, caller);
  ibFirstGrabCheck = true;
  bBallSplashed = false;
}

Ac EPassFree(Event event, const char[] name, b dontBroadcast) {
  bBallLoose = true;
  int owner = event.GetInt("owner");
  townerTeam = TF2_GetClientTeam(owner);
  if (ownerTeam == TFTeam_Blue) {
    if (iBallPickedUpTick != 0) {
      iBluBallTime += GetGameTickCount() - iBallPickedUpTick;
    }
  }
  elif (ownerTeam == TFTeam_Red) {
    if (iBallPickedUpTick != 0) {
      iRedBallTime += GetGameTickCount() - iBallPickedUpTick;
    }
  }

  if (!arrbPlyIsDead[owner]) {
    eLastTickBallTeam = ownerTeam;
  }

  arrbDeathbombCheck[entDeathBomber] = false;  // if anyone at all throws the ball, the deathbomb is automatically false

  HideJackHud(owner);
  GetEntPropVector(entJack, Prop_Data, "m_vecAbsOrigin", fFreeBallPos);
  entPassTarget = EntRefToEntIndex(GetEntPropEnt(owner, Prop_Send, "m_hPasstimePassTarget"));
  if (!(arrbBlastJumpStatus[owner])) {
    arrbPanaceaCheck[owner]  = false;
    arrbWinStratCheck[owner] = false;
  }
  LogPassFree();
  PH;
}

// When an enemy player blocks a thrown ball without picking it up, via uber or rocket/sticky jumpers
Ac EPassBallBlocked(Event event, const char[] name, b dontBroadcast) {
  int blocker = event.GetInt("blocker");
  int thrower = event.GetInt("owner");
  arriClientRoundStats[blocker].iBlocks++;
  LogPassBallBlocked(blocker, thrower);
  user2 = 0;
  PH;
}

// When a player gets a neutral ball.
Ac EPassGet(Event event, const char[] name, b dontBroadcast) {
  bBallLoose = false;
  iBallPickedUpTick = GetGameTickCount();
  VerboseLog("Ball picked up - t%d", iBallPickedUpTick);
  iPlyWhoGotJack = event.GetInt("owner");
  f position[3];

  SetLogInfo(iPlyWhoGotJack);
  LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_get\" (firstcontact \"%i\") (position \"%.0f %.0f %.0f\")",
            user1, GetClientUserId(user1), user1steamid, user1team, ibFirstGrabCheck,
            user1position[0], user1position[1], user1position[2]);
  if (ibFirstGrabCheck && arrbBlastJumpStatus[iPlyWhoGotJack]) {
    arriClientRoundStats[iPlyWhoGotJack].iFirstGrabs++;
    arrbPanaceaCheck[iPlyWhoGotJack] = true;
    GetClientAbsOrigin(iPlyWhoGotJack, position);
    f distanceFromTopSpawner = GetVectorDistance(position, fTopSpawnPos, false);
    VerboseLog("Panacea check - Distance from top spawner: %.0f, Cutoff distance for winstrat: %i", distanceFromTopSpawner, iWinStratDistance);
    // may need to be changed 
    if (distanceFromTopSpawner < iWinStratDistance)  { 
      arrbPanaceaCheck[iPlyWhoGotJack]  = false;
      arrbWinStratCheck[iPlyWhoGotJack] = true;

      if (bWinstratKills.BoolValue) {
        arrbWinStratCheck[iPlyWhoGotJack] = false;
        // KILL winstratter
        SDKHooks_TakeDamage(iPlyWhoGotJack, iPlyWhoGotJack, iPlyWhoGotJack, 500.0);
        c winstratterName[MAX_NAME_LENGTH];
        GetClientName(iPlyWhoGotJack, winstratterName, sizeof(winstratterName));
        TagChatAllPlayers("{chat}%s %stried to {pass_green}win strat.", winstratterName, "{pass_green}");
      }
    }
  }
  else {
    arrbPanaceaCheck[iPlyWhoGotJack]  = false;
    arrbWinStratCheck[iPlyWhoGotJack] = false;
  }
  ibFirstGrabCheck = false;

  ShowJackHud(iPlyWhoGotJack);
  if (arrbClientSettings[iPlyWhoGotJack].iSummary)
    ShowJackChat(iPlyWhoGotJack, "YOU HAVE THE JACK!!!");
  PlayJackSound(iPlyWhoGotJack);

  PH;
}

// When a player catches a ball thrown by another player.
Ac EPassCaught(Han event, const char[] name, b dontBroadcast) {
  int thrower        = EvI(event, "passer");
  int catcher        = EvI(event, "catcher");
  f dist             = EvF(event, "dist");
  f duration         = EvF(event, "duration");
  int intercept      = false;
  int bSave          = false;
  int ibHandoffCheck = false;
  iPlyWhoGotJack     = catcher;
  bBallLoose         = false;

  iBallPickedUpTick = GetGameTickCount();

  VerboseLog("Ball picked up - t%d", iBallPickedUpTick);

  c throwerName[MAX_NAME_LENGTH], catcherName[MAX_NAME_LENGTH];
  GetClientName(thrower, throwerName, sizeof(throwerName));
  GetClientName(catcher, catcherName, sizeof(catcherName));
  c throwerNameTeamFormat[MAX_TEAMFORMAT_NAME_LENGTH], catcherNameTeamFormat[MAX_TEAMFORMAT_NAME_LENGTH];
  FormatPlayerNameWithTeam(thrower, throwerNameTeamFormat);
  FormatPlayerNameWithTeam(catcher, catcherNameTeamFormat);

  if (TF2_GetClientTeam(thrower) == TFTeam_Spectator || TF2_GetClientTeam(catcher) == TFTeam_Spectator) PH;

  if (bChatEventsFun.BoolValue && bChatEvents.BoolValue) {
    if (GetClientTeam(thrower) == GetClientTeam(catcher)) {
      if (PlayerInEnemyGoalieZone(catcher)) {
        ChatEvent("%s {pass_yellow}blocked *their teammate* %s %sfrom scoring!", catcherNameTeamFormat, throwerNameTeamFormat, "{chat}");
      }
    }
  }

  if (GetClientTeam(thrower) != GetClientTeam(catcher)) {
    intercept = true;
    if (PlayerInTeamGoalieZone(catcher)) {
      bSave = true;
      arriClientRoundStats[catcher].iSaves++;
      ChatEventToClients("%s {pass_yellow}blocked %s {chat}from scoring!", catcherNameTeamFormat, throwerNameTeamFormat);
      TagChatSTV("%s blocked %s from scoring. t%d", catcherName, throwerName, STVTickCount());
    }
    else {
      arriClientRoundStats[catcher].iIntercepts++;
      ChatEventToClients("%s {pass_magenta}intercepted %s!", catcherNameTeamFormat, throwerNameTeamFormat);
      TagChatSTV("%s intercepted %s. t%d", catcherName, throwerName, STVTickCount());
    }
  }
  // if on same team and catcher is not locked onto for a pass, also 200 units above ground at least (to ignore just normal non-lock passes)
  if (TF2_GetClientTeam(thrower) == TF2_GetClientTeam(catcher) && entPassTarget != catcher && !(GetEntityFlags(catcher) & FL_ONGROUND) && DistanceAboveGround(catcher) > 200) { 
    ChatEventToClients("%s {pass_yellow}handoff to %s!", throwerNameTeamFormat, catcherNameTeamFormat);
    TagChatSTV("%s handoff to %s. t%d", throwerName, catcherName, STVTickCount());
    ibHandoffCheck = true;
    arriClientRoundStats[thrower].iHandoffs++;
    entPassTarget = 0;
  }
  LogPassCaught(catcher, thrower, intercept, bSave, ibHandoffCheck, dist, duration);
  user2 = 0;
  arrbPanaceaCheck[thrower]  = false;
  arrbPanaceaCheck[catcher]  = false;
  arrbWinStratCheck[thrower] = false;
  arrbWinStratCheck[catcher] = false;

  PH;
}

// When a player melee steals the ball from another player.
Ac EPassStolen(Event event, const char[] name, b dontBroadcast) {
  int thief      = event.GetInt("attacker");
  int victim     = event.GetInt("victim");
  b steal2save   = false;
  iPlyWhoGotJack = thief;

  iBallPickedUpTick = GetGameTickCount();
  VerboseLog("Ball picked up - t%d", iBallPickedUpTick);
  if (PlayerInTeamGoalieZone(thief)) {
    arriClientRoundStats[thief].iSteal2Saves++;
    steal2save = true;
  }

  LogPassBallStolen(thief, victim, steal2save);
  user2 = 0;
  arrbPanaceaCheck[thief]   = false;
  arrbPanaceaCheck[victim]  = false;
  arrbWinStratCheck[thief]  = false;
  arrbWinStratCheck[victim] = false;

  HideJackHud(victim);
  c thiefName[MAX_NAME_LENGTH], victimName[MAX_NAME_LENGTH];
  GetClientName(thief, thiefName, sizeof(thiefName));
  GetClientName(victim, victimName, sizeof(victimName));
  c thiefNameTeamFormat[MAX_TEAMFORMAT_NAME_LENGTH];
  c victimNameTeamFormat[MAX_TEAMFORMAT_NAME_LENGTH];
  FormatPlayerNameWithTeam(thief, thiefNameTeamFormat);
  FormatPlayerNameWithTeam(victim, victimNameTeamFormat);

  if (PlayerInTeamGoalieZone(thief)) {
    ChatEvent("%s{pass_orange} defensively stole from{chat} %s!", thiefNameTeamFormat, victimNameTeamFormat);
    TagChatSTV("%s defensively stole from %s. t%d", thiefName, victimName, STVTickCount());
  }
  else {
    ChatEvent("%s{pass_orange} stole from{chat} %s!", thiefNameTeamFormat, victimNameTeamFormat);
    TagChatSTV("%s stole from %s. t%d", thiefName, victimName, STVTickCount());
  }
  arriClientRoundStats[thief].iSteals++;
  PH;
}

// When a player scores with the ball.
Ac EPassScore(Event event, const char[] name, b dontBroadcast) {
  int scorer    = event.GetInt("scorer");
  int points    = event.GetInt("points");
  int assistant = event.GetInt("assister");
  c playerName[MAX_NAME_LENGTH], assistantName[MAX_NAME_LENGTH];
  bBallLoose        = false;
  eLastTickBallTeam = TFTeam_Unassigned;

  GetClientName(scorer, playerName, sizeof(playerName));

  if (ibBallSpawnedLower || bBallSplashed)
    arrbPanaceaCheck[scorer] = false;

  f fScoredBallPos[3];
  GetEntPropVector(entJack, Prop_Send, "m_vecOrigin", fScoredBallPos);
  f dist = GetVectorDistance(fFreeBallPos, fScoredBallPos, false);

  if (arrbDeathbombCheck[entDeathBomber]) {
    HandleDeathbombScoring(scorer, points, dist);
  }
  else {
    HandleNormalScoring(scorer, points, arrbPanaceaCheck[scorer], arrbWinStratCheck[scorer], arrbDeathbombCheck[entDeathBomber], dist, assistant);
  }

  if (arrbPanaceaCheck[scorer] && TF2_GetPlayerClass(scorer) != TFClass_Medic)
    arriClientRoundStats[scorer].iPanaceas++;
  elif (arrbWinStratCheck[scorer])
    arriClientRoundStats[scorer].iWinstrats++;

  ShowScoreMessage(scorer, assistant, arrbPanaceaCheck[scorer], arrbWinStratCheck[scorer], arrbDeathbombCheck[entDeathBomber], dist);
  arrbPanaceaCheck[scorer]  = false;
  arrbWinStratCheck[scorer] = false;  // reset these cuz its good idea

  PH;
}

// Checks if a player is close enough to their team's goal to count as a goalie.
b PlayerInTeamGoalieZone(int client) {
  int team = GetClientTeam(client);
  f position[3];
  GetClientAbsOrigin(client, position);

  if (team == view_as<int>(TFTeam_Blue)) {
    f distance = GetVectorDistance(position, fBluGoalPos, false);
    if (distance < GOALIE_DISTANCE) return true;
  }

  if (team == view_as<int>(TFTeam_Red)) {
    f distance = GetVectorDistance(position, fRedGoalPos, false);
    if (distance < GOALIE_DISTANCE) return true;
  }
  return false;
}

b EntInRedGoalZone(int entIndex) {
  f position[3];
  GetEntPropVector(entIndex, Prop_Send, "m_vecOrigin", position);
  return PosInRedGoalZone(position);
}

b EntInBluGoalZone(int entIndex) {
  f position[3];
  GetEntPropVector(entIndex, Prop_Send, "m_vecOrigin", position);
  return PosInBluGoalZone(position);
}

b PosInRedGoalZone(f position[3]) {
  f dist = GetVectorDistance(position, fRedGoalPos);
  if (dist < GOALIE_DISTANCE) return true;
  return false;
}

b PosInBluGoalZone(f position[3]) {
  f dist = GetVectorDistance(position, fBluGoalPos);
  if (dist < GOALIE_DISTANCE) return true;
  return false;
}

// Checks if a player is close enough to the *enemy* team's goal to count as a blocker.
// For fun.
b PlayerInEnemyGoalieZone(int client) {
  int team = GetClientTeam(client);
  f position[3];
  GetClientAbsOrigin(client, position);

  if (team == view_as<int>(TFTeam_Blue)) {
    f distance = GetVectorDistance(position, fRedGoalPos, false);
    if (distance < 100) return true;
  }

  if (team == view_as<int>(TFTeam_Red)) {
    f distance = GetVectorDistance(position, fBluGoalPos, false);
    if (distance < 100) return true;
  }
  return false;
}

v EOOnCatapult(const char[] output, int caller, int activator, f delay) {
  c catapultName[15];
  GetEntPropString(caller, Prop_Data, "m_iName", catapultName, sizeof(catapultName));
  if (activator == entJack && iPlyWhoGotJack != 0) {
    if (StrEqual(catapultName, "red_catapult1") || StrEqual(catapultName, "red_catapult2") || StrEqual(catapultName, "blu_catapult1") || StrEqual(catapultName, "blu_catapult2") && IsClientConnected(iPlyWhoGotJack)) {
      LogCatapultEvent(catapultName);
    }
  }
  TagChatSTV("%N triggered \"%s\" with the jack. t%d", user1, catapultName, STVTickCount());
}

// outputString must be of size MAX_NAME_LENGTH + 7 or greater.
v FormatPlayerNameWithTeam(int player, char[] outputString) {
  c playerName[MAX_NAME_LENGTH];
  GetClientName(player, playerName, sizeof(playerName));
  if (TF2_GetClientTeam(player) == TFTeam_Blue) {
    Format(outputString, MAX_NAME_LENGTH + 7, "{blu_team}%s", playerName);
  }
  else {
    Format(outputString, MAX_NAME_LENGTH + 7, "{red_team}%s", playerName);
  }
}

// 0: TEAM_UNASSIGNED
// 1: spectator
// 2: TF_TEAM_RED
// 3: TF_TEAM_BLU
stock tGetBallTeam() {
  if (entJack == 0 || !IsValidEntity(entJack)) {
    LogStackTrace("Ball entity invalid, returning Unassigned");
    return TFTeam_Unassigned;
  }
  int team = GetEntProp(entJack, Prop_Send, "m_iTeamNum");
  switch (team) {
    case 0:  return TFTeam_Unassigned;
    case 1:  return TFTeam_Spectator;
    case 2:  return TFTeam_Red;
    case 3:  return TFTeam_Blue;
    default: return TFTeam_Unassigned;
  }
}

// Utility function
stock v VerboseLog(const char[] format, any...) {
  if (bVerboseLogs.BoolValue) {
    int len = strlen(format) + 255;
    // sensible value for max log size?
    char[] MessageToLog = new char[len];
    VFormat(MessageToLog, len, format, 2);
    LogMessage("[VERBOSE] %s", MessageToLog);
  }
}

v SetJack(int eIndex) {
  if (!SDKHookEx(eIndex, SDKHook_OnTakeDamage, PasstimeBallTookDamage)) {
    LogError("Could not hook passtime_ball. Splash detection will not work.");
  }
  entJack = eIndex;
}

b PointInRespawnRoom(int client, f origin[3], b sameTeamOnly) {
  return SDKCall(pointInRespawnRoom, client, origin, sameTeamOnly);
}

v ForceRegenerateAndRespawn(int client) {
  SDKCall(tfPlayerForceRegenerateAndRespawn, client);
}
