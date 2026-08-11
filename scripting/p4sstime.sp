#undef REQUIRE_PLUGIN
#include "include/updater.inc"
#include "include/morecolors.inc"
#define REQUIRE_PLUGIN

#include <tf2_stocks>
#include <sourcemod>
#include <sdkhooks>
#include <clientprefs>
#include <sdktools_functions>
//#include <p4sstime/trikz.sp>

#pragma semicolon 1 // required for logs.tf
#pragma newdecls required

#define VERSION "3.0.2"

// Macros
#define GD      GameData 

#define NOTIFY  FCVAR_NOTIFY

#define GENERIC ADMFLAG_GENERIC
#define CONFIG  ADMFLAG_CONFIG

#define HE   HookEvent
#define HCC  HookConVarChange
#define HEO  HookEntityOutput
#define CC   RegConsoleCmd
#define AC   RegAdminCmd
#define RCC  RegClientCookie
#define AddC CAddColor
#define CV   CreateConVar
#define EvI  GetEventInt
#define EvF  GetEventFloat
#define ACA  RegAdminCmdWithShort
#define CCA  RegConsoleCmdWithShort

#define elif else if

enum {
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
enum struct enuClientSettings {
  bool bCountdown;
  bool bJackHud;
  bool bJackChat;
  bool bJackSound;
  int  iStats;
  bool bStatsSeparateLines;
  bool bImmunity;
  bool bInfAmmo;
  bool bLegacyColors;
  bool bAirshotLog;
}

enum struct enuClientStats {
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

enuClientSettings arr_iClientPrefs[MAXPLAYERS + 1];
enuClientStats arr_iClientRoundStats[MAXPLAYERS + 1];

float fBluGoalPos[3], fRedGoalPos[3], fTopSpawnPos[3], fFreeBallPos[3], fFreeBallThrowerVec[3];

ConVar bFixStocks;
ConVar bFixRespawnBypass;
ConVar bFixBlur;
// CV trikzEnable, trikzProjCollide, trikzProjDev;
ConVar bFixJackCollision;
ConVar bChatEvents;
ConVar bWinstratKills;
ConVar bChatEventsFun;
ConVar bPractice;
ConVar bVerboseLogs;
ConVar bMedicSplash;
ConVar bMedicSplashPush;
ConVar bResupply;
ConVar fResupplyCooldown;
ConVar fResupplyDecayRate;
ConVar fResupplyDecayAddition;
ConVar fGoalRegeneration;

// int plyDirecter;
int ibFirstGrabCheck;
int entPassTarget = INVALID_ENT_REFERENCE;
int ibBallSpawnedLower;
int iRoundResetTick;
int iWinStratDistance;
int entDeathBomber;
int iBallPickedUpTick;
int iRedBallTime;
int iBluBallTime;
// i trikzProjCollideCurVal;
// i trikzProjCollideSave = 2;
Menu   mPassMenu;
bool   bWaitingForBallSpawnToRestart;
bool   bHalloweenMode;
bool   bBallSplashed;      // check if ball splashed for panacea checks
TFTeam eLastTickBallTeam;  // in effect, this is "last thrown ball team"
bool   arr_bPlyIsDead [MAXPLAYERS + 1];
bool   arr_bBlastJumpStatus [MAXPLAYERS + 1];  // true if blast jumping, false if has landed
bool   arr_bPanaceaCheck [MAXPLAYERS + 1];
bool   arr_bWinStratCheck [MAXPLAYERS + 1];
bool   arr_bDeathbombCheck [MAXPLAYERS + 1];
float  nextInstantResupplyTime[MAXPLAYERS + 1];
float  resupplyDecay[MAXPLAYERS + 1];

// Demoman blast resistance
bool  g_bDemoResistEnabled;
float g_fCurrentDemoResistValue[MAXPLAYERS + 1];
bool  g_bDemoResistApplied[MAXPLAYERS + 1];

// Demoman boots attributes
ConVar cvBootsChargeTurn;
ConVar cvBootsMaxHealth;
ConVar cvBootsKillRefill;
ConVar cvBootsMoveSpeed;
float  g_fCurrentBootsChargeTurn[MAXPLAYERS + 1];
float  g_fCurrentBootsMaxHealth[MAXPLAYERS + 1];
float  g_fCurrentBootsKillRefill[MAXPLAYERS + 1];
float  g_fCurrentBootsMoveSpeed[MAXPLAYERS + 1];
bool   g_bBootsAttributesApplied[MAXPLAYERS + 1];

// Buffered resupply
bool g_bResupplyDn[MAXPLAYERS + 1];
bool g_bResupplyUp[MAXPLAYERS + 1];

// Instant respawn
ConVar cvRespawnTime;
bool g_bInstantRespawnEnabled = true;

// Immunity & infinite ammo
bool g_bPendingHP[MAXPLAYERS + 1];

// Save/Load spawn
bool g_bSaveEnabled = true;

// Mirror spawnpoint system for side-aware resupply
ArrayList g_hMirrorSpawnPoints[2][2];  // [team][side] where team=0=RED,1=BLU and side=0=left,1=right MUST query AreMirrorSpawnPointsAvailable side-effects
int g_iCurrentSpawnIndex[2][2];  // [team][side] current spawnpoint index
float g_fMirrorPlaneX = 0.0;  // X coordinate of the middle plane
float g_fMirrorPlaneY = 0.0;  // Y coordinate of the middle plane

// FOV
ConVar cvFovMin;
ConVar cvFovMax;
bool g_bSteamOnline = true;
bool g_bBackupFOVDB;
bool g_bPlayerTracked[MAXPLAYERS + 1];
int  g_iPlayerFOV[MAXPLAYERS + 1];
int  g_iPlySpecFov[MAXPLAYERS + 1];
int  g_iPlyObserverMode[MAXPLAYERS + 1];
int  g_iPlyObserverTarget[MAXPLAYERS + 1];
// Direct hit tracking for airshot messages
bool  g_bTookDirectHit[MAXPLAYERS + 1];
bool  g_bDirectHitAirborne[MAXPLAYERS + 1];
int   g_iDirectHitAttacker[MAXPLAYERS + 1];
int   g_iDirectHitTick[MAXPLAYERS + 1];
float g_fDirectHitSpeed[MAXPLAYERS + 1];
float g_fDirectHitDistance[MAXPLAYERS + 1];
Cookie ck_iCountdown,
       ck_bJackHud,
       ck_bJackChat,
       ck_bJackSound,
       ck_iStats,
       ck_bStatsSeparateLines,
       ck_bImmunity,
       ck_bInfAmmo,
       ck_bLegacyColors,
       ck_iFov,
       ck_iSpecFov,
       ck_bAirshotLog;

// log variables
int   user1;
char  user1steamid[16];
char  user1team[12];
float user1position[3];
int   user2;
char  user2steamid[16];
char  user2team[12];
float user2position[3];

// stats menu variables
char moreurl[128];

Handle   tfPlayerForceRegenerateAndRespawn;
Handle   pointInRespawnRoom;
GameData gameData;

char chatEventBuffer[254];
// Utility functions for chat events
stock void ChatEvent(const char[] format, any ...) {
  if (bChatEvents.BoolValue) {
    VFormat(chatEventBuffer, sizeof(chatEventBuffer), format, 2);
    TagChatAll(chatEventBuffer);
  }
}

stock void ChatEventToClients(const char[] format, any ...) {
  if (bChatEvents.BoolValue) {
    VFormat(chatEventBuffer, sizeof(chatEventBuffer), format, 2);
    for (int x = 1; x < MaxClients + 1; x++) {
      if (!IsValidClient(x) || IsClientSourceTV(x)) continue;
      CTagChat(x, chatEventBuffer);
    }
  }
}

stock void SendCountdownToClients(int time) {
  for (int x = 1; x < MaxClients + 1; x++) {
    if (!IsValidClient(x) || !arr_iClientPrefs[x].bCountdown) continue;
    
    switch (time) {
      case 10: CTagChat(x, "{cGreen}10 seconds...");
      case 5:  CTagChat(x, "{cYellow}5 seconds...");
      case 4:  CTagChat(x, "{cYellow}4 seconds...");
      case 3:  CTagChat(x, "{cYellow}3 seconds...");
      case 2:  CTagChat(x, "{cRed}2 seconds...");
      case 1:  CTagChat(x, "{cRed}1 second...");
    }
  }
}

#define MRB(%1,%2) (StrEqual(sound, "Merasmus.RoundBegins%1seconds")) CTagChat(x, "%2%1 seconds...")
#define ARB(%1,%2) (StrEqual(sound, "Announcer.RoundBegins%1seconds")) CTagChat(x, "%2%1 seconds...")

stock void SendSoundCountdownToClients(const char[] sound) {
  for (int x = 1; x < MaxClients + 1; x++) {
    if (!IsValidClient(x) || !arr_iClientPrefs[x].bCountdown) continue;
    
    if ARB(10,cGreen);
    elif (StrEqual(sound, "Passtime.BallSpawn"))
      CTagChat(x, "{cGreen}Ball has spawned!");
    if (bHalloweenMode) {
      if MRB(5,{cYellow});
      elif MRB(4,{cYellow});
      elif MRB(3,{cYellow});
      elif MRB(2,{cRed});
      elif MRB(1,{cRed});
    }
    else {
      if ARB(5,{cYellow});
      elif ARB(4,{cYellow});
      elif ARB(3,{cYellow});
      elif ARB(2,{cRed});
      elif ARB(1,{cRed});
    }
  }
}

stock void ShowJackHud(int client) {
  if (arr_iClientPrefs[client].bJackHud) {
    SetHudTextParams(-1.0, 0.22, 3.0, 60, 179, 113, 255);
    ShowHudText(client, 1, "YOU HAVE THE JACK!");
  }
}

stock void HideJackHud(int client) {
  if (arr_iClientPrefs[client].bJackHud) {
    SetHudTextParams(-1.0, 0.22, 3.0, 60, 179, 113, 255);
    ShowHudText(client, 1, "");
  }
}

stock void PlayJackSound(int client) {
  if (arr_iClientPrefs[client].bJackSound) {
    ClientCommand(client, "playgamesound Passtime.BallSmack");
  }
}

stock void ShowJackChat(int client, const char[] message) {
  if (arr_iClientPrefs[client].bJackChat) {
    CTagChat(client, "%s%s", "{cGreen}", message);
  }
}

char logGameEventBuffer[1024];
stock void LogGameEvent(const char[] eventName, const char[] format, any ...) {
  VFormat(logGameEventBuffer, sizeof(logGameEventBuffer), format, 3);
  LogToGame("\"%N<%i><%s><%s>\" triggered \"%s\" %s", user1, GetClientUserId(user1), user1steamid, user1team, eventName, logGameEventBuffer);
}

stock void LogScoreEvent(int scorer, int points, bool panacea, bool winstrat, bool deathbomb, float dist, float speed) {
  SetLogInfo(scorer);
  LogGameEvent("pass_score", "(points \"%i\") (panacea \"%d\") (win strat \"%d\") (deathbomb \"%d\") (dist \"%.0f\") (speed \"%.0f\") (position \"%.0f %.0f %.0f\")",
              points, panacea, winstrat, deathbomb, dist, speed,
              user1position[0], user1position[1], user1position[2]);
}

stock void LogAssistEvent(int assistant) {
  char assistantName[MAX_NAME_LENGTH];
  GetClientName(assistant, assistantName, sizeof(assistantName));
  SetLogInfo(assistant);
  LogGameEvent("pass_score_assist", "(position \"%.0f %.0f %.0f\")",
              user1position[0], user1position[1], user1position[2]);
  arr_iClientRoundStats[assistant].iAssists++;
}

stock void HandleDeathbombScoring(int scorer, int points, float dist, float speed) {
  arr_bPanaceaCheck[scorer] = false;
  LogScoreEvent(entDeathBomber, points, arr_bPanaceaCheck[scorer], arr_bWinStratCheck[scorer], true, dist, speed);
  arr_iClientRoundStats[entDeathBomber].iScores++;
  arr_iClientRoundStats[entDeathBomber].iDeathbombs++;
  LogAssistEvent(scorer);
}

stock void HandleNormalScoring(int scorer, int points, bool panacea, bool winstrat, bool deathbomb, float dist, float speed, int assistant) {
  LogScoreEvent(scorer, points, panacea, winstrat, deathbomb, dist, speed);
  arr_iClientRoundStats[scorer].iScores++;
  
  if (assistant > 0) {
    LogAssistEvent(assistant);
  }
}

stock void ShowScoreMessage(int scorer, int assistant, bool panacea, bool winstrat, bool deathbomb, float dist, float speed) {
  char playerNameTeamFormatted[MAX_TEAMFORMAT_NAME_LENGTH], assistantNameTeamFormatted[MAX_TEAMFORMAT_NAME_LENGTH];
  char playerName[MAX_NAME_LENGTH], assistantName[MAX_NAME_LENGTH];
  GetClientName(scorer, playerName, sizeof(playerName));
  if (assistant > 0) {
    GetClientName(assistant, assistantName, sizeof(assistantName));
  }
  FormatPlayerNameWithTeam(scorer, playerNameTeamFormatted);
  
  if (panacea && TF2_GetPlayerClass(scorer) != TFClass_Medic) {
    ChatEvent("%s {cScore}scored a {cScore}Panacea{chat}!", playerNameTeamFormatted);
    TagChatSTV("%s scored a Panacea. t%d", playerName, STVTickCount());
  }
  elif (winstrat) {
    ChatEvent("%s {cScore}scored a {cScore}win strat{chat}!", playerNameTeamFormatted);
    TagChatSTV("%s scored a win strat. t%d", playerName, STVTickCount());
  }
  elif (deathbomb) {
    int deathBomber = entDeathBomber;
    char deathBomberName[MAX_NAME_LENGTH];
    GetClientName(deathBomber, deathBomberName, sizeof(deathBomberName));
    FormatPlayerNameWithTeam(deathBomber, playerNameTeamFormatted);
    ChatEvent("%s {cScore}scored a {cScore}deathbomb{chat}!", playerNameTeamFormatted);
    TagChatSTV("%s scored a deathbomb. t%d", deathBomberName, STVTickCount());
  }
  elif (speed > 1350) {
    ChatEvent("%s {cScore}scored {chat}at {cScore}%.0f hu/s{chat}!", playerNameTeamFormatted, speed);
    TagChatSTV("%s scored at %.0f hu/s. t%d", playerName, speed, STVTickCount());
  }
  elif (dist > 1600) {
    ChatEvent("%s {cScore}scored {chat}from a distance of %.0fhu!", playerNameTeamFormatted, dist);
    TagChatSTV("%s scored from distance of %.0fhu. t%d", playerName, dist, STVTickCount());
  }
  elif (assistant > 0) {
    FormatPlayerNameWithTeam(assistant, assistantNameTeamFormatted);
    ChatEvent("%s {cScore}scored {chat}with %s{chat}!", playerNameTeamFormatted, assistantNameTeamFormatted);
    TagChatSTV("%s scored with %s. t%d", playerName, assistantName, STVTickCount());
  }
  else {
    ChatEvent("%s {cScore}scored{chat}!", playerNameTeamFormatted);
    TagChatSTV("%s scored. t%d", playerName, STVTickCount());
  }
}

// Airshot direct hit tracking
void OnProjectileTouch(int entity, int other) {
  if (other < 1 || other > MaxClients || !IsClientInGame(other)) return;

  g_bTookDirectHit[other] = true;
  g_bDirectHitAirborne[other] = !(GetEntityFlags(other) & FL_ONGROUND);
  g_iDirectHitAttacker[other] = EntRefToEntIndex(GetEntPropEnt(entity, Prop_Data, "m_hOwnerEntity"));
  g_iDirectHitTick[other] = GetGameTickCount();

  float velocity[3];
  GetEntPropVector(other, Prop_Data, "m_vecAbsVelocity", velocity);
  g_fDirectHitSpeed[other] = GetVectorLength(velocity);

  int attacker = g_iDirectHitAttacker[other];
  if (attacker < 1 || attacker > MaxClients || !IsClientInGame(attacker)) {
    g_fDirectHitDistance[other] = 0.0;
    return;
  }

  float attPos[3], vicPos[3];
  GetClientAbsOrigin(attacker, attPos);
  GetClientAbsOrigin(other, vicPos);
  g_fDirectHitDistance[other] = GetVectorDistance(attPos, vicPos);

  char class[32];
  GetEntityClassname(entity, class, sizeof(class));
}

stock void ClearDirectHit(int client) {
  g_bTookDirectHit[client] = false;
  g_bDirectHitAirborne[client] = false;
  g_iDirectHitAttacker[client] = 0;
  g_iDirectHitTick[client] = 0;
  g_fDirectHitSpeed[client] = 0.0;
  g_fDirectHitDistance[client] = 0.0;
}

stock void ShowAirshotMessage(int victim, int attacker) {
  if (!bChatEvents.BoolValue) return;
  if (!IsValidClient(victim) || !IsValidClient(attacker)) return;
  if (victim == attacker) return;
  if (g_iDirectHitAttacker[victim] != attacker) return;
  if (g_iDirectHitTick[victim] != GetGameTickCount()) return;
  if (!g_bTookDirectHit[victim]) return;
  if (IsPlayerAlive(victim)) return;
  if (TF2_GetClientTeam(victim) == TF2_GetClientTeam(attacker)) return;

  float speed = g_fDirectHitSpeed[victim];
  float dist = g_fDirectHitDistance[victim];
  bool fast = speed > 1000.0;
  bool far = dist > 800.0;

  if (!fast && !far) {
    return;
  }

  char attackerName[MAX_TEAMFORMAT_NAME_LENGTH], victimName[MAX_TEAMFORMAT_NAME_LENGTH];
  FormatPlayerNameWithTeam(attacker, attackerName);
  FormatPlayerNameWithTeam(victim, victimName);

  if (fast && far) {
    ChatEvent("%s {cNeutral}airshot {chat}%s at {cNeutral}%.0f hu/s {chat}from {cNeutral}%.0fhu{chat}!", attackerName, victimName, speed, dist);
  } else if (fast) {
    ChatEvent("%s {cNeutral}airshot {chat}%s at {cNeutral}%.0f hu/s{chat}!", attackerName, victimName, speed);
  } else {
    ChatEvent("%s {cNeutral}airshot {chat}%s from {cNeutral}%.0fhu{chat}!", attackerName, victimName, dist);
  }

  char attackerNamePlain[MAX_NAME_LENGTH], victimNamePlain[MAX_NAME_LENGTH];
  GetClientName(attacker, attackerNamePlain, sizeof(attackerNamePlain));
  GetClientName(victim, victimNamePlain, sizeof(victimNamePlain));
}

stock void LogBallSpawn(const char[] spawnName, int caller) {
  char logMessage[64];
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

stock void LogCatapultEvent(const char[] catapultName, int ply) {
  SetLogInfo(ply);
  LogGameEvent(catapultName, "with the jack (position \"%.0f %.0f %.0f\")",
              user1position[0], user1position[1], user1position[2]);
  arr_iClientRoundStats[ply].iCatapults++;
}

stock void LogBallDamage(int victim, int attacker, int inflictor, float damage, int damagetype, const char[] classname) {
  LogToGame("passtime_ball took damage victim '%d' attacker '%d' inflictor '%d' damage '%.2f' damagetype '%d' inflictor classname '%s'", 
            victim, attacker, inflictor, damage, damagetype, classname);
}

stock void LogPassFree(int owner) {
  SetLogInfo(owner);
  LogGameEvent("pass_free", "(position \"%.0f %.0f %.0f\")",
              user1position[0], user1position[1], user1position[2]);
}

stock void LogPassBallBlocked(int blocker, int thrower) {
  SetLogInfo(blocker, thrower);
  LogGameEvent("pass_ball_blocked", "against \"%N<%i><%s><%s>\" (thrower_position \"%.0f %.0f %.0f\") (blocker_position \"%.0f %.0f %.0f\")",
              user2, GetClientUserId(user2), user2steamid, user2team,
              user1position[0], user1position[1], user1position[2],
              user2position[0], user2position[1], user2position[2]);
}

stock void LogPassCaught(int catcher, int thrower, bool intercept, bool save, bool handoff, float dist, float duration) {
  SetLogInfo(catcher, thrower);
  LogGameEvent("pass_pass_caught", "against \"%N<%i><%s><%s>\" (interception \"%i\") (save \"%i\") (handoff \"%i\") (dist \"%.3f\") (duration \"%.3f\") (thrower_position \"%.0f %.0f %.0f\") (catcher_position \"%.0f %.0f %.0f\")",
              user2, GetClientUserId(user2), user2steamid, user2team,
              intercept, save, handoff, dist, duration,
              user1position[0], user1position[1], user1position[2],
              user2position[0], user2position[1], user2position[2]);
}

stock void LogPassBallStolen(int thief, int victim, bool steal2save) {
  SetLogInfo(thief, victim);
  LogGameEvent("pass_ball_stolen", "against \"%N<%i><%s><%s>\" (steal defense \"%d\") (thief_position \"%.0f %.0f %.0f\") (victim_position \"%.0f %.0f %.0f\")",
              user2, GetClientUserId(user2), user2steamid, user2team,
              steal2save,
              user1position[0], user1position[1], user1position[2],
              user2position[0], user2position[1], user2position[2]);
}

// Modules (loaded here cause the methods above are dependent on them)
#include "p4sstime/stocks.sp"
#include "p4sstime/logs.sp"
#include "p4sstime/pass_menu.sp"
#include "p4sstime/practice.sp"
#include "p4sstime/anticheat.sp"
#include "p4sstime/attributes.sp"
#include "p4sstime/demoman.sp"
#include "p4sstime/fov.sp"
#include "p4sstime/warmup.sp"
#include "p4sstime/match.sp"
#include "p4sstime/convars.sp"
#include "p4sstime/stats_print.sp"
#include "p4sstime/f2stocks.sp"
#include "p4sstime/spawnball.sp"

public Plugin myinfo = {
  name        = "4v4 PASS Time Extension",
  author      = "https://discord.passtime.tf/",
  description = "The main plugin for 4v4 Competitive PASS Time.",
  version     = VERSION,
  url         = "https://github.com/p4sstime/p4sstime-server-resources/releases"
};

public void OnPluginStart() {
  gameData = new GameData("p4sstime"); // Load config

  // Initialize mirror spawnpoint arrays
  g_hMirrorSpawnPoints[0][0] = new ArrayList();  // RED left
  g_hMirrorSpawnPoints[0][1] = new ArrayList();  // RED right
  g_hMirrorSpawnPoints[1][0] = new ArrayList();  // BLU left
  g_hMirrorSpawnPoints[1][1] = new ArrayList();  // BLU right

  // Cookies
  ck_iCountdown =          RCC("p4ssClientCountdownCaption",  "p4sstime's client setting (1/0) for captions for JACK spawn timer", CookieAccess_Public);
  ck_bJackHud =            RCC("p4ssClientJACKPickupHudText", "p4sstime's client setting (1/0) for HUD text when picking up JACK", CookieAccess_Public);
  ck_bJackChat =           RCC("p4ssClientJACKPickupChatMsg", "p4sstime's client setting (1/0) for chat msg when picking up JACK", CookieAccess_Public);
  ck_bJackSound =          RCC("p4ssClientJACKPickupSound",   "p4sstime's client setting (1/0) for sound when picking up JACK",    CookieAccess_Public);
  ck_iStats =              RCC("p4ssClientStats",             "p4sstime's client setting (0/1/2) for EoR stats",                   CookieAccess_Public);
  ck_bStatsSeparateLines = RCC("p4ssClientStatsSeparateLines", "p4sstime's client setting for separating stats into 2 lines", CookieAccess_Public);
  ck_iFov =                RCC("p4ssClientFOV",               "p4sstime's client FOV setting",                                     CookieAccess_Public);
  ck_iSpecFov =            RCC("p4ssClientSpecFOV",           "p4sstime's spectator FOV setting",                                  CookieAccess_Public);
  ck_bAirshotLog =         RCC("p4ssClientAirshotLog",        "p4sstime's airshot log toggle",                                     CookieAccess_Public);
  ck_bImmunity =           RCC("p4ssClientImmunity",          "p4sstime's immunity setting",                                       CookieAccess_Public);
  ck_bInfAmmo =            RCC("p4ssClientInfiniteAmmo",      "p4sstime's infinite ammo setting",                                  CookieAccess_Public);
  ck_bLegacyColors =       RCC("p4ssClientLegacyColors",   "p4sstime's client setting for using legacy colors",                 CookieAccess_Public);

  // Client commands
  CC("sm_pt_stats",        CChatStats,       "Toggle end-of-round stats");
  CC("sm_pt_pickup_sound", CJackPickupSound, "Toggle JACK pickup sound");
  CC("sm_pt_pickup_hud",   CJackPickupHud,   "Toggle JACK pickup HUD text");
  CC("sm_pt_pickup_chat",  CJackPickupChat,  "Toggle JACK pickup chat message");
  CC("sm_pt_menu",         CMenu,            "Open the PASS Time menu");
  CC("sm_pt_countdown",    CChatCountdown,   "Toggle JACK spawn timer captions");
  CC("sm_fov",             CSetFOV,          "Set your field of view");
  CC("sm_spec_fov",        CSetSpecFOV,      "Set your spectator FOV");
  CC("+sm_resupply",       CResupDn,         "Instant buffered resupply in spawn");
  CC("-sm_resupply",       CResupUp);
  CC("+sm_pt_resupply",    CResupDn,         "Instant buffered resupply in spawn");
  CC("-sm_pt_resupply",    CResupUp);
  CC("+resupply",          CResupDn,         "Instant buffered resupply in spawn");
  CC("-resupply",          CResupUp);

  // Client commands with aliases
  CCA("sm_pt_suicide", "sm_pt_kill", CSuicide,   "Killbind with no cooldown");
  CCA("sm_immune",     "sm_i",       CImmune,    "Toggle immunity");
  CCA("sm_ammo",       "sm_a",       CInfAmmo,   "Toggle infinite ammo");
  CCA("sm_diceroll",   "sm_dice",    CDice,      "Select a random player from targets");
  CCA("sm_ready",      "sm_r",       CReady,     "Toggle your team's ready state");
  CCA("sm_team_name",  "sm_tn",      CTeamName,  "Rename your team");
  CCA("sm_save",       "sm_sv",      CSavepoint, "Save a spawn point");
  CCA("sm_load",       "sm_ld",      CLoadpoint, "Teleport to saved spawn");

  // Admin commands
  AC("sm_pt_spawnball",   CSpawnBall,        GENERIC, "Spawn the jack for pre-game practice.");
  AC("sm_pt_demoresist",  CToggleDemoResist, GENERIC, "Toggle demo blast vulnerability");

  // Admin commands with aliases
  ACA("sm_force_ready",    "sm_fr",   CForceReady,    GENERIC, "Set a team's ready status");
  ACA("sm_enable_respawn", "sm_resp", CToggleRespawn, GENERIC, "Toggle instant respawn");
  ACA("sm_setteam",        "sm_st",   CSetTeam,       GENERIC, "Set a client's team");
  ACA("sm_setclass",       "sm_sc",   CSetClass,      GENERIC, "Set a client's class");

  // Colors
  AddC("steamlightgreen", 0x9DC250); // #9DC250

  AddC("plugintag",       0x96BD63); // #96BD63
  AddC("warning",         0xECCD19); // #ECCD19
  AddC("error",           0xd64843); // #D64843

  AddC("chat",            0xBBBBBB); // #BBBBBB
  AddC("teamblu",         0x99CCFF); // #99CCFF
  AddC("teamred",         0xFF3F35); // #FF3F35
  
  AddC("cRed",            0xD64843); // #D64843
  AddC("cGreen",          0x3CB371); // #3CB371 (also used in ShowJackHud and HideJackHud, manually updated)
  AddC("cBlue",           0x438CD6); // #438CD6
  AddC("cTeal",           0x008B8B); // #00BCBC
  AddC("cMagenta",        0xA946C7); // #A946C7
  AddC("cOrange",         0xDD8125); // #DD8125
  AddC("cYellow",         0xECCD19); // #ECCD19
  
  // Legacy
  AddC("cOldRed",      0xFF0000); // #FF0000
  AddC("cOldGreen",    0x00FF00); // #00FF00
  AddC("cOldBlue",     0x0000FF); // #0000FF
  AddC("cOldCyan",     0x00FFFF); // #00FFFF
  AddC("cOldMagenta",  0xFF00FF); // #FF00FF
  AddC("cOldYellow",   0xFFFF00); // #FFFF00
  
  // Game event specific colors
  AddC("cScore",     0x3CB371); // #2bd501
  AddC("cAssist",    0x008B8B); // #48c0dc
  AddC("cBlock",     0xECCD19); // #ECCD19
  AddC("cNeutral",   0xDD8125); // #DD8125
  AddC("cIntercept", 0xA946C7); // #A946C7
  AddC("cSteal",     0xD64843); // #D64843
  
  // Legacy
  AddC("cOldScore",     0x30C433); // #30C433
  AddC("cOldAssist",    0x00FFFF); // #00FFFF
  AddC("cOldDefense",   0xFFFF00); // #FFFF00
  AddC("cOldNeutral",   0x5BD4B3); // #5BD4B3
  AddC("cOldIntercept", 0xFF00FF); // #FF00FF
  AddC("cOldSteal",     0xFF8000); // #FF8000

  // ConVars
  bFixStocks =             CV("sm_pt_stock_blocklist",                  "1",    "Disable equipping shotgun, stickies, and needles; the allowlist can't block stock weapons.",       NOTIFY);
  bFixRespawnBypass =      CV("sm_pt_block_instant_respawn",            "1",    "Disable switching classes while dead to respawn immediately.",                                     NOTIFY);
  bFixJackCollision =      CV("sm_pt_disable_jack_drop_item_collision", "1",    "Disable jack collision on ammo packs and weapons.",                                                NOTIFY);
  bFixBlur =               CV("sm_pt_disable_intercept_blur",           "1",    "Disable blurry screen overlay when intercepting or stealing.",                                     NOTIFY);
  bChatEvents =            CV("sm_pt_print_events",                     "1",    "Enable printing of passtime events to chat both during and after games. Does not affect logging.", NOTIFY);
  bChatEventsFun =         CV("sm_pt_print_events_fun",                 "0",    "If sm_pt_print_events is 1, enable printing additional fun stats.",                                NOTIFY);
  bWinstratKills =         CV("sm_pt_winstrat_kills",                   "0",    "Enable killing winstratters and printing \"tried to winstrat\" in chat.",                          NOTIFY);
  bVerboseLogs =           CV("sm_pt_logs_verbose",                     "0",    "Enable printing additional information to logs.");
  bMedicSplash =           CV("sm_pt_medic_can_splash",                 "1",    "Enable medic arrows neutralizing the jack.",                                                       NOTIFY);
  bMedicSplashPush =       CV("sm_pt_medic_splash_pushes_ball",         "1",    "If sm_pt_medic_can_splash is 1, enable crossbow push on the jack.",                                    NOTIFY);
  bResupply =              CV("sm_pt_resupply_enabled",                 "1",    "Enable instant resupply.",                                                                         NOTIFY);
  fResupplyCooldown =      CV("sm_pt_resupply_cooldown",                "0.5",  "Set the resupply cooldown duration in seconds (also used as max decay cap).",                      NOTIFY);
  fResupplyDecayRate =     CV("sm_pt_resupply_decay_rate",              "0.15", "Set the resupply decay rate (seconds of decay recovered per second).",                             NOTIFY);
  fResupplyDecayAddition = CV("sm_pt_resupply_decay_addition",          "0.2",  "Set the resupply decay addition per successful resupply.",                                         NOTIFY);
  fGoalRegeneration =      CV("sm_pt_goal_heal",                        "0",    "Set the amount of health regeneration every 500ms while in the goal zone.",                        NOTIFY);
  bPractice =              CV("sm_pt_practice",                         "0",    "Enable practice mode. When the round timer reaches 5 minutes, add 5 minutes to the timer.",        NOTIFY, true, 0.0, true, 1.0);
  cvRespawnTime =          CV("sm_pt_respawn_time",                     "0.0",  "Player respawn delay in seconds",                                                                 NOTIFY);

  // Demoman boots attribute ConVars
  cvBootsChargeTurn = CV("sm_pt_boots_charge_turn", "3.0",  "Charge turn control multiplier for Demoman boots",     NOTIFY);
  cvBootsMaxHealth =  CV("sm_pt_boots_max_health",  "25.0", "Max health additive bonus for Demoman boots",          NOTIFY);
  cvBootsKillRefill = CV("sm_pt_boots_kill_refill", "0.25", "Kill refills meter value for Demoman boots",           NOTIFY);
  cvBootsMoveSpeed =  CV("sm_pt_boots_move_speed",  "1.10", "Move speed bonus (shield required) for Demoman boots", NOTIFY);

  // FOV ConVars
  cvFovMin = CV("sm_pt_fov_min", "70",  "Minimum client field of view", _, true, 1.0, true, 175.0);
  cvFovMax = CV("sm_pt_fov_max", "120", "Maximum client field of view", _, true, 1.0, true, 175.0);

  // trikzEnable =      CC("sm_pt_trikz",                 "0", "Set 'trikz' mode. 1 adds friendly knockback for airshots, 2 adds friendly knockback for splash damage, 3 adds friendly knockback for everywhere", NOTIFY, true, 0.0, true, 3.0);
  // trikzProjCollide = CC("sm_pt_trikz_projcollide",     "2", "Manually set team projectile collision behavior when trikz is on. 2 always collides, 1 will cause your projectiles to phase through if you are too close (default game behavior), 0 will cause them to never collide.", 0, true, 0.0, true, 2.0);
  // trikzProjDev =     CC("sm_pt_trikz_projcollide_dev", "0", "DONOTUSE; This command is used solely by the plugin to change values. Changing this manually may cause issues.", FCVAR_HIDDEN, true, 0.0, true, 2.0);

  // Hook SDKHooks for already-connected clients on plugin load/reload
  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i)) {
      SDKHook(i, SDKHook_OnTakeDamage,     Hook_ImmunityOnTakeDamage);
      SDKHook(i, SDKHook_OnTakeDamagePost, Hook_ImmunityOnTakeDamagePost);
    }
  }

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
  AddCommandListener(OnSpecCommand, "spec_next");
  AddCommandListener(OnSpecCommand, "spec_prev");
  AddCommandListener(OnSpecCommand, "spec_mode");

  HCC(bPractice, Hook_OnPracticeModeChange);
  HCC(bResupply, Hook_OnAllowInstantResupplyChange);
  // HCC(trikzEnable, Hook_OnTrikzChange);
  // HCC(trikzProjCollide, Hook_OnProjCollideChange);
  // HCC(trikzProjDev, Hook_OnProjCollideDev);

  CreateTimer(0.5, GoalHealTimer, 0, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
  CreateTimer(0.05, Timer_CheckSpecFov, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
  /*for (i client = 1; client <= MaxClients; client++)
    if (IsClientInGame(client))
      OnClientPutInServer(client);*/
  for (int i = MaxClients; i > 0; --i) {
    if (!AreClientCookiesCached(i)) {
      continue;
    }
    OnClientCookiesCached(i);
  }

  char sMapNameBuffer[256];
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

  InitAttributeSDKCalls();
  PrintToServer("p4sstime v%s loaded", VERSION);
}

public void OnLibraryAdded(const char[] name) {
  // if (StrEqual(name, "updater"))
  // {
  //   Updater_AddPlugin(
  //     "https://raw.githubusercontent.com/p4sstime/p4sstime-server-resources/refs/heads/updater/updatefile.txt");
  // }
}

public Action GoalHealTimer(Handle timer) {
  // LogMessage("GoalHealTimer popped");
  if (fGoalRegeneration.FloatValue == 0.0) return Plugin_Continue;
  for (int client_idx = 1; client_idx < MaxClients + 1; client_idx++) {
    if (!IsValidClient(client_idx) || IsClientSourceTV(client_idx)) continue;
    float position[3];
    GetClientAbsOrigin(client_idx, position);

    TFTeam team = TF2_GetClientTeam(client_idx);
    if (team == TFTeam_Spectator || team == TFTeam_Unassigned) {
      continue;  // skip this player
    }
    int health = GetClientHealth(client_idx);
    int max_health = GetPlayerMaxHealthTF2(client_idx);

    if (health >= max_health) return Plugin_Continue;

    float distance_sqr, vertical_difference;
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

      SetEntityHealth(client_idx, min(health + fGoalRegeneration.IntValue, max_health));
    }
  }
  return Plugin_Continue;
}

public void OnMapInit(const char[] mapName) {
  if (StrContains(mapName, "stadium", false) != -1)  // stadium has much lower top spawner so do this to av false positive win strats
    iWinStratDistance = 150;
  else
    iWinStratDistance = 400;
}

public void OnMapStart() { // get goal locations
  int goal1 = FindEntityByClassname(-1, "func_passtime_goal");
  if (goal1 == -1) {
    PrintToServer("[p4sstime] Goal entity not found, is this a passtime map?");
    return;
  }
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

public void OnMapEnd() {
  ClearAttributeDefCache();
}

public void OnGameFrame() {
  int logic = GetOrFindPasstimeLogic();
  if (logic != INVALID_ENT_REFERENCE) {
    int jack = GetBall(logic);
    if (jack != INVALID_ENT_REFERENCE) {
      int carrier = GetBallCarrier(jack);

      // ball is loose
      if (carrier == INVALID_ENT_REFERENCE) {
        TFTeam ballTeam = view_as<TFTeam>(GetEntProp(jack, Prop_Send, "m_iTeamNum"));
        if (ballTeam != eLastTickBallTeam) {
          VerboseLog("Ball team changed from %d (%s) to %d (%s)", eLastTickBallTeam, TFTeamToString(eLastTickBallTeam), ballTeam, TFTeamToString(ballTeam));
          float ballPos[3];
          GetEntPropVector(jack, Prop_Send, "m_vecOrigin", ballPos);
          float distFromBluGoal = GetVectorDistance(ballPos, fBluGoalPos);
          float distFromRedGoal = GetVectorDistance(ballPos, fRedGoalPos);
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
}

  // Buffered resupply: while key is held and player enters spawn, auto-resupply
  if (bResupply.BoolValue) {
    for (int i = 1; i <= MaxClients; i++) {
      if (!IsClientInGame(i) || !IsPlayerAlive(i)) continue;

      // Update decay timers
      float decayRate = fResupplyDecayRate.FloatValue;
      float frameTime = GetTickInterval();
      float newCooldown = nextInstantResupplyTime[i] - frameTime;
      nextInstantResupplyTime[i] = newCooldown > 0.0 ? newCooldown : 0.0;
      float newDecay = resupplyDecay[i] - decayRate * frameTime;
      resupplyDecay[i] = newDecay > 0.0 ? newDecay : 0.0;

      if (g_bResupplyDn[i] && !g_bResupplyUp[i])
        BufferedResupply(i);

      if (!IsMatch() && arr_iClientPrefs[i].bInfAmmo && TF2_GetPlayerClass(i) != TFClass_Medic) {
        int wep = GetEntPropEnt(i, Prop_Send, "m_hActiveWeapon");
        if (wep != -1 && IsValidEntity(wep)) {
          SetEntProp(wep, Prop_Send, "m_iClip1", 19);
          SetAmmo(i, wep, 84);
        }
      }
    }
  }
}

public void OnEntityCreated(int eIndex, const char[] eClassname) {
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
    if (!SDKHookEx(eIndex, SDKHook_OnTakeDamage, PasstimeBallTookDamage)) {
      LogError("Could not hook passtime_ball. Splash detection will not work.");
    }

    VerboseLog("passtime_ball spawned \"%d\"", eIndex);
  }
  if (StrEqual(eClassname, "tf_projectile_rocket") || StrEqual(eClassname, "tf_projectile_pipe")) {
    SDKHookEx(eIndex, SDKHook_Touch, OnProjectileTouch);
  }

  if (bMedicSplash.BoolValue) {
    if (StrEqual(eClassname, "tf_projectile_healing_bolt")) {
      VerboseLog("tf_projectile_healing_bolt spawned.");
      SDKHookEx(eIndex, SDKHook_StartTouchPost, MedicArrowTouchedSomething);
    }
  }
}

Action PasstimeBallTookDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype) {
  TFTeam ballTeam = eLastTickBallTeam;
  char classname[128];
  GetEntityClassname(inflictor, classname, sizeof(classname));
  LogBallDamage(victim, attacker, inflictor, damage, damagetype, classname);
  TFTeam playerTeam = TF2_GetClientTeam(attacker);

  char playerName[MAX_NAME_LENGTH];
  GetClientName(attacker, playerName, sizeof(playerName));
  VerboseLog("passtime_ball damage debug: attacker '%s', attacker team: '%s' (indice '%d')", playerName, TFTeamToString(playerTeam), playerTeam);
  VerboseLog("passtime_ball damage debug: ballteam '%s' (indice '%d')", TFTeamToString(ballTeam), ballTeam);
  // so incredibly ugly
  VerboseLog("passtime_ball damage debug: playerWhoSplashed: %d, playerTeam: %s, ballTeam: %s", attacker, TFTeamToString(playerTeam), TFTeamToString(ballTeam));
  bBallSplashed = true;
  float fSplashedBallPos[3];
  GetEntPropVector(victim, Prop_Send, "m_vecOrigin", fSplashedBallPos);
  bool inGoalZone, expectedBallTeam;
  if (playerTeam == TFTeam_Blue) {
    VerboseLog("passtime_ball damage debug: player team is BLU, checking if in blu goal and if ball is red.");
    inGoalZone = EntInGoalZone(victim, TFTeam_Blue);
    expectedBallTeam = (ballTeam == TFTeam_Red);
  }
  else {
    VerboseLog("passtime_ball damage debug: player team is RED, checking if in red goal and if ball is blu.");
    inGoalZone = EntInGoalZone(victim, TFTeam_Red);
    expectedBallTeam = (ballTeam == TFTeam_Blue);
  }

  if (inGoalZone && expectedBallTeam) {
    VerboseLog("passtime_ball damage debug: successful splash");
    char playerNameTeam[MAX_TEAMFORMAT_NAME_LENGTH];
    char throwerNameTeam[MAX_TEAMFORMAT_NAME_LENGTH];
    GetClientName(attacker, playerName, sizeof(playerName));
    FormatPlayerNameWithTeam(attacker, playerNameTeam);
    int logic = GetOrFindPasstimeLogic();
    if (logic != INVALID_ENT_REFERENCE) {
        int jack = GetBall(logic);
        if (jack != INVALID_ENT_REFERENCE) {
            int prevCarrier = GetBallPrevCarrier(jack);
            if (prevCarrier != INVALID_ENT_REFERENCE) {
                FormatPlayerNameWithTeam(prevCarrier, throwerNameTeam);
                ChatEvent("%s {cNeutral}splashed %s{chat}!", playerNameTeam, throwerNameTeam);
                TagChatSTV("%s splashed %N. t%d", playerName, prevCarrier, STVTickCount());
            }
        }
    }

    SetLogInfo(attacker);
    LogGameEvent("pass_splash_defense", "(ball position \"%.0f %.0f %.0f\")",
                fSplashedBallPos[0], fSplashedBallPos[1], fSplashedBallPos[2]);
    arr_iClientRoundStats[attacker].iSplashes++;
  }

  return Plugin_Continue;
}

void MedicArrowTouchedSomething(int arrow, int other) {
  char classname[64];
  GetEntityClassname(other, classname, 64);
  int eiMedicAttacker = EntRefToEntIndex(GetEntPropEnt(arrow, Prop_Data, "m_hOwnerEntity"));
  if (StrEqual(classname, "passtime_ball")) {
    if (bMedicSplashPush.BoolValue) {
      // smart solution: damage the ball using the arrow's position relative to the jack's position
      float jackPosition[3], arrowPosition[3], damageForce[3];
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

    char medicAttackerNameTeamFmt[MAX_TEAMFORMAT_NAME_LENGTH];
    FormatPlayerNameWithTeam(eiMedicAttacker, medicAttackerNameTeamFmt);
    TagChatAll("%s {cBlock}directed {chat}the ball with an {cNeutral}arrow{chat}!", medicAttackerNameTeamFmt);
  }
  VerboseLog("medic arrow from %d touched %s i %d", eiMedicAttacker, classname, other);
}

Action ERoundReset(Event event, const char[] name, bool dontBroadcast) {
  for (int i = 0; i < MaxClients + 1; i++)
    ClearLocalStats(i);
  iRedBallTime = 0;
  iBluBallTime = 0;
  if (GetConVarInt(bPractice) == 1) {
    SetConVarInt(bPractice, 0);
    TagChatAll("Game started; practice mode disabled.");
  }
  bHalloweenMode = false;
  iRoundResetTick = GetGameTickCount();
  return Plugin_Handled;
}

Action EPregameCountdown(Event event, const char[] name, bool dontBroadcast) {
  int time = event.GetInt("time");
  SendCountdownToClients(time);
  return Plugin_Handled;
}

Action EMidgameCountdown(Event event, const char[] name, bool dontBroadcast) {
  // if it is halloween, announcer always says 10 seconds, but merasmus says 5-1
  // for pregame, announcer ALWAYS says start

  char sound[128];
  event.GetString("sound", sound, sizeof(sound));
  if (StrEqual(sound, "Passtime.Merasmus.Laugh"))  // if this occurs (which it does during halloween right after ball spawn), assume halloween
    bHalloweenMode = true;
  SendSoundCountdownToClients(sound);
  return Plugin_Handled;
}

Action EPlayersCanMove(Event event, const char[] name, bool dontBroadcast) {
  int offset = GameConfGetOffset(gameData, "CTFPlayer::m_bPasstimeBallSlippery");
  for (int x = 1; x < MaxClients + 1; x++) {
    if (!IsValidClient(x)) continue;

    // fix by Underscore; if ply goes AFK for long enough (even in pregame) they get attached a flag (m_bPasstimeBallSlippery) that causes teammates to be able to steal from them that doesn't go away. this makes it go away every time a round starts
    Address entity_address = GetEntityAddress(x);
    StoreToAddress(view_as<Address>(view_as<int>(entity_address) + offset), 0, NumberType_Int8, false);
  }

  return Plugin_Handled;
}

Action ETeamWin(Event event, const char[] name, bool dontBroadcast) {
  CreateTimer(0.5, Timer_DisplayStats);
  return Plugin_Handled;
}

int STVTickCount() {
  int tick;
  tick = GetGameTickCount() - iRoundResetTick;
  return tick;
}

bool IsValidClient(int client, bool blockbots = true) {
  if (client > 4096) client = EntRefToEntIndex(client);
  if (client <= 0 || client > MaxClients) return false;
  if (!IsClientInGame(client)) return false;
  if (blockbots && IsFakeClient(client)) return false;
  if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
  return true;
}

/*-------------------------------------------------- Player Events --------------------------------------------------*/
public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) {
  if (StrEqual(sArgs, "/more", false) || StrEqual(sArgs, ".more", false)) {
    CreateTimer(0.1, Timer_ShowMoreTF, client, TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Handled;
  }
  elif (StrEqual(sArgs, "/pass", false) || StrEqual(sArgs, "/p4ss", false) || StrEqual(sArgs, ".pass", false) || StrEqual(sArgs, ".p4ss", false)) {
    ShowPassMenu(client);
    return Plugin_Handled;
  }
  return Plugin_Continue;
}

bool TraceEntityFilterPlayer(int entity, int contentsMask)  { // taken from mgemod; just going to use this instead of isvalidclient for the below function 
  return entity > MaxClients || !entity;
}

float DistanceAboveGround(int victim) { // taken from mgemod 
  float vStart[3];
  float vEnd[3];
  float vAngles[3] = { 90.0, 0.0, 0.0 };
  GetClientAbsOrigin(victim, vStart);
  Handle trace = TR_TraceRayFilterEx(vStart, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer);

  float distance = -1.0;
  if (TR_DidHit(trace)) {
    TR_GetEndPosition(vEnd, trace);
    distance = GetVectorDistance(vStart, vEnd, false);
  }
  else LogError("trace error. victim %N(%d)", victim, victim);

  delete trace;
  return distance;
}

// Macro for changing blast jump statuses for clients
#define JUMP_HANDLER(%1,%2) \
  Action %1(Event event, const char[] name, bool dontBroadcast) { \
    int client = GetClientOfUserId(event.GetInt("userid")); \
    arr_bBlastJumpStatus[client] = %2; \
    return Plugin_Handled; \
  }

JUMP_HANDLER(ERocketJump, true)
JUMP_HANDLER(ERocketJumpLand, false)
JUMP_HANDLER(EPipeJump, true)
JUMP_HANDLER(EPipeJumpLand, false)

// the below function is dr underscore's fix. thanks!
public void TF2_OnConditionRemoved(int client, TFCond condition) {
  if (condition == TFCond_Ubercharged)
    TF2_RemoveCondition(client, TFCond_UberchargeFading);
}

Action EPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  arr_bPlyIsDead[client] = true;
  int target = EntRefToEntIndex(entPassTarget);
  if (client == target) {
    entDeathBomber = client;
    arr_bDeathbombCheck[entDeathBomber] = true;
  }

  // Instant respawn
  if (!IsMatch() && g_bInstantRespawnEnabled && cvRespawnTime.FloatValue <= 0.0) {
    RequestFrame(RespawnFrame, client);
  }

  return Plugin_Handled;
}

void RespawnFrame(any client) {
  if (!IsPlayerAlive(client)) TF2_RespawnPlayer(client);
}

public void OnClientDisconnect(int client) {
  ClearLocalStats(client);
  ClearDemoClientState(client);
  ClearFOVClientState(client);
  g_bResupplyDn[client] = false;
  g_bResupplyUp[client] = false;
  nextInstantResupplyTime[client] = 0.0;
  resupplyDecay[client] = 0.0;
}

/*-------------------------------------------------- PASS Events --------------------------------------------------*/
void EOOnSpawnBall(const char[] name, int caller, int activator, float delay) {
  char spawnName[24];

  int logic = GetOrFindPasstimeLogic();
  if (logic != INVALID_ENT_REFERENCE) {
    int jack = GetBall(logic);
    if (bFixJackCollision.BoolValue && jack != -1) SetEntityCollisionGroup(jack, 4);
  }
  ibBallSpawnedLower = 0;
  if (bWaitingForBallSpawnToRestart) {
    ServerCommand("mp_tournament_restart");
    bWaitingForBallSpawnToRestart = false;
  }
  GetEntPropString(caller, Prop_Data, "m_iName", spawnName, sizeof(spawnName));
  LogBallSpawn(spawnName, caller);
  ibFirstGrabCheck = true;
  bBallSplashed = false;
}

Action EPassFree(Event event, const char[] name, bool dontBroadcast) {
  int owner = event.GetInt("owner");
  TFTeam ownerTeam = TF2_GetClientTeam(owner);
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

  if (!arr_bPlyIsDead[owner]) {
    eLastTickBallTeam = ownerTeam;
  }

  arr_bDeathbombCheck[entDeathBomber] = false;  // if anyone at all throws the ball, the deathbomb is automatically false

  HideJackHud(owner);

  int logic = GetOrFindPasstimeLogic();
  if (logic != INVALID_ENT_REFERENCE) {
    int jack = GetBall(logic);
    if (jack != INVALID_ENT_REFERENCE) {
      GetEntPropVector(jack, Prop_Data, "m_vecAbsOrigin", fFreeBallPos);
    } else {
      fFreeBallPos[0] = 0;
      fFreeBallPos[1] = 0;
      fFreeBallPos[2] = 0;
    }
  }

  GetEntPropVector(owner,   Prop_Data, "m_vecAbsVelocity", fFreeBallThrowerVec);
  entPassTarget = GetEntProp(owner, Prop_Send, "m_hPasstimePassTarget");
  if (!(arr_bBlastJumpStatus[owner])) {
    arr_bPanaceaCheck[owner]  = false;
    arr_bWinStratCheck[owner] = false;
  }
  LogPassFree(owner);
  return Plugin_Handled;
}

// When an enemy player blocks a thrown ball without picking it up, via uber or rocket/sticky jumpers
Action EPassBallBlocked(Event event, const char[] name, bool dontBroadcast) {
  int blocker = event.GetInt("blocker");
  int thrower = event.GetInt("owner");
  arr_iClientRoundStats[blocker].iBlocks++;
  LogPassBallBlocked(blocker, thrower);
  user2 = 0;
  return Plugin_Handled;
}

// When a player gets a neutral ball.
Action EPassGet(Event event, const char[] name, bool dontBroadcast) {
  iBallPickedUpTick = GetGameTickCount();
  VerboseLog("Ball picked up - t%d", iBallPickedUpTick);
  int owner = event.GetInt("owner");
  float position[3];

  SetLogInfo(owner);
  LogToGame("\"%N<%i><%s><%s>\" triggered \"pass_get\" (firstcontact \"%i\") (position \"%.0f %.0f %.0f\")",
            user1, GetClientUserId(user1), user1steamid, user1team, ibFirstGrabCheck,
            user1position[0], user1position[1], user1position[2]);
  if (ibFirstGrabCheck && arr_bBlastJumpStatus[owner]) {
    arr_iClientRoundStats[owner].iFirstGrabs++;
    arr_bPanaceaCheck[owner] = true;
    GetClientAbsOrigin(owner, position);
    float distanceFromTopSpawner = GetVectorDistance(position, fTopSpawnPos, false);
    VerboseLog("Panacea check - Distance from top spawner: %.0f, Cutoff distance for winstrat: %i", distanceFromTopSpawner, iWinStratDistance);
    // may need to be changed
    if (distanceFromTopSpawner < iWinStratDistance)  {
      arr_bPanaceaCheck[owner]  = false;
      arr_bWinStratCheck[owner] = true;

      if (bWinstratKills.BoolValue) {
        arr_bWinStratCheck[owner] = false;
        // KILL winstratter
        SDKHooks_TakeDamage(owner, owner, owner, 500.0);
        char winstratterName[MAX_NAME_LENGTH];
        GetClientName(owner, winstratterName, sizeof(winstratterName));
        TagChatAll("{chat}%s {cScore}tried to {cScore}win strat.", winstratterName);
      }
    }
  }
  else {
    arr_bPanaceaCheck[owner]  = false;
    arr_bWinStratCheck[owner] = false;
  }
  ibFirstGrabCheck = false;

  ShowJackHud(owner);
  ShowJackChat(owner, "YOU HAVE THE JACK!");
  PlayJackSound(owner);

  return Plugin_Handled;
}

// When a player catches a ball thrown by another player.
Action EPassCaught(Handle event, const char[] name, bool dontBroadcast) {
  int thrower        = EvI(event, "passer");
  int catcher        = EvI(event, "catcher");
  if (!IsValidClient(thrower) || !IsValidClient(catcher)) return Plugin_Handled;
  float dist         = EvF(event, "dist");
  float duration     = EvF(event, "duration");
  int intercept      = false;
  int bSave          = false;
  int ibHandoffCheck = false;

  iBallPickedUpTick = GetGameTickCount();

  VerboseLog("Ball picked up - t%d", iBallPickedUpTick);

  char throwerName[MAX_NAME_LENGTH], catcherName[MAX_NAME_LENGTH];
  GetClientName(thrower, throwerName, sizeof(throwerName));
  GetClientName(catcher, catcherName, sizeof(catcherName));
  char throwerNameTeamFormat[MAX_TEAMFORMAT_NAME_LENGTH], catcherNameTeamFormat[MAX_TEAMFORMAT_NAME_LENGTH];
  FormatPlayerNameWithTeam(thrower, throwerNameTeamFormat);
  FormatPlayerNameWithTeam(catcher, catcherNameTeamFormat);

  if (TF2_GetClientTeam(thrower) == TFTeam_Spectator || TF2_GetClientTeam(catcher) == TFTeam_Spectator) return Plugin_Handled;

  if (bChatEventsFun.BoolValue && bChatEvents.BoolValue && IsTeam(thrower, catcher) && AtEnemyGoal(catcher)){
    ChatEvent("%s {cBlock}blocked *their teammate* %s %s{chat}!", catcherNameTeamFormat, throwerNameTeamFormat, "{chat}");
  }

  if (!IsTeam(thrower, catcher)) {
    intercept = true;
    if (AtTeamGoal(catcher)) {
      bSave = true;
      arr_iClientRoundStats[catcher].iSaves++;
      ChatEventToClients("%s {cBlock}blocked %s {chat}!", catcherNameTeamFormat, throwerNameTeamFormat);
      TagChatSTV("%s blocked %s . t%d", catcherName, throwerName, STVTickCount());
    }
    else {
      arr_iClientRoundStats[catcher].iIntercepts++;
      ChatEventToClients("%s {cIntercept}intercepted %s{chat}!", catcherNameTeamFormat, throwerNameTeamFormat);
      TagChatSTV("%s intercepted %s. t%d", catcherName, throwerName, STVTickCount());
    }
  }
  int target = EntRefToEntIndex(entPassTarget);
  // if on same team and catcher is not locked onto for a pass, also 200 units above ground at least (to ignore just normal non-lock passes)
  if (TF2_GetClientTeam(thrower) == TF2_GetClientTeam(catcher) && (target == INVALID_ENT_REFERENCE) && !(GetEntityFlags(catcher) & FL_ONGROUND) && DistanceAboveGround(catcher) > 200) {
    ChatEventToClients("%s {cAssist}handoff {chat}to %s{chat}!", throwerNameTeamFormat, catcherNameTeamFormat);
    TagChatSTV("%s handoff to %s. t%d", throwerName, catcherName, STVTickCount());
    ibHandoffCheck = true;
    arr_iClientRoundStats[thrower].iHandoffs++;
  }
  entPassTarget = INVALID_ENT_REFERENCE;
  LogPassCaught(catcher, thrower, intercept, bSave, ibHandoffCheck, dist, duration);
  user2 = 0;
  arr_bPanaceaCheck[thrower]  = false;
  arr_bPanaceaCheck[catcher]  = false;
  arr_bWinStratCheck[thrower] = false;
  arr_bWinStratCheck[catcher] = false;

  return Plugin_Handled;
}

// When a player melee steals the ball from another player.
Action EPassStolen(Event event, const char[] name, bool dontBroadcast) {
  int thief       = event.GetInt("attacker");
  int victim      = event.GetInt("victim");
  bool steal2save = false;

  iBallPickedUpTick = GetGameTickCount();
  VerboseLog("Ball picked up - t%d", iBallPickedUpTick);
  if (AtTeamGoal(thief)) {
    arr_iClientRoundStats[thief].iSteal2Saves++;
    steal2save = true;
  }

  LogPassBallStolen(thief, victim, steal2save);
  user2 = 0;
  arr_bPanaceaCheck[thief]   = false;
  arr_bPanaceaCheck[victim]  = false;
  arr_bWinStratCheck[thief]  = false;
  arr_bWinStratCheck[victim] = false;

  HideJackHud(victim);
  char thiefName[MAX_NAME_LENGTH], victimName[MAX_NAME_LENGTH];
  GetClientName(thief, thiefName, sizeof(thiefName));
  GetClientName(victim, victimName, sizeof(victimName));
  char thiefNameTeamFormat[MAX_TEAMFORMAT_NAME_LENGTH];
  char victimNameTeamFormat[MAX_TEAMFORMAT_NAME_LENGTH];
  FormatPlayerNameWithTeam(thief, thiefNameTeamFormat);
  FormatPlayerNameWithTeam(victim, victimNameTeamFormat);

  if (AtTeamGoal(thief)) {
    ChatEvent("%s {cSteal}defensively stole {chat}from %s{chat}!", thiefNameTeamFormat, victimNameTeamFormat);
    TagChatSTV("%s defensively stole from %s. t%d", thiefName, victimName, STVTickCount());
  }
  else {
    ChatEvent("%s {cSteal}stole {chat}from %s{chat}!", thiefNameTeamFormat, victimNameTeamFormat);
    TagChatSTV("%s stole from %s. t%d", thiefName, victimName, STVTickCount());
  }
  arr_iClientRoundStats[thief].iSteals++;
  return Plugin_Handled;
}

// When a player scores with the ball.
Action EPassScore(Event event, const char[] name, bool dontBroadcast) {
  int scorer    = event.GetInt("scorer");
  int points    = event.GetInt("points");
  int assistant = event.GetInt("assister");
  char playerName[MAX_NAME_LENGTH];
  eLastTickBallTeam = TFTeam_Unassigned;

  GetClientName(scorer, playerName, sizeof(playerName));

  if (ibBallSpawnedLower || bBallSplashed)
    arr_bPanaceaCheck[scorer] = false;

  float speed = GetVectorLength(fFreeBallThrowerVec, false);
  float dist = 0;

  int logic = GetOrFindPasstimeLogic();
  if (logic != INVALID_ENT_REFERENCE) {
    int jack = GetBall(logic);
    if (jack != INVALID_ENT_REFERENCE) {
      float fScoredBallPos[3];
      GetEntPropVector(jack, Prop_Send, "m_vecOrigin", fScoredBallPos);
      dist = GetVectorDistance(fFreeBallPos, fScoredBallPos, false);
    }
  }

  if (arr_bDeathbombCheck[entDeathBomber]) {
    HandleDeathbombScoring(scorer, points, dist, speed);
  }
  else {
    HandleNormalScoring(scorer, points, arr_bPanaceaCheck[scorer], arr_bWinStratCheck[scorer], arr_bDeathbombCheck[entDeathBomber], dist, speed, assistant);
  }

  if (arr_bPanaceaCheck[scorer] && TF2_GetPlayerClass(scorer) != TFClass_Medic)
    arr_iClientRoundStats[scorer].iPanaceas++;
  elif (arr_bWinStratCheck[scorer])
    arr_iClientRoundStats[scorer].iWinstrats++;

  ShowScoreMessage(scorer, assistant, arr_bPanaceaCheck[scorer], arr_bWinStratCheck[scorer], arr_bDeathbombCheck[entDeathBomber], dist, speed);
  arr_bPanaceaCheck[scorer]  = false;
  arr_bWinStratCheck[scorer] = false;  // reset these cuz its good idea

  return Plugin_Handled;
}

// Checks if a player is close enough to their team's goal to count as a goalie.
bool AtTeamGoal(int client) {
  int team = GetClientTeam(client);
  float position[3];
  GetClientAbsOrigin(client, position);

  if (team == view_as<int>(TFTeam_Blue)) {
    float distance = GetVectorDistance(position, fBluGoalPos, false);
    if (distance < GOALIE_DISTANCE) return true;
  }

  if (team == view_as<int>(TFTeam_Red)) {
    float distance = GetVectorDistance(position, fRedGoalPos, false);
    if (distance < GOALIE_DISTANCE) return true;
  }
  return false;
}

bool EntInGoalZone(int entIndex, TFTeam team) {
  float position[3];
  GetEntPropVector(entIndex, Prop_Send, "m_vecOrigin", position);
  return PosInGoalZone(position, team);
}

bool PosInGoalZone(float position[3], TFTeam team) {
  float dist = GetVectorDistance(position, (team == TFTeam_Red) ? fRedGoalPos : fBluGoalPos);
  return dist < GOALIE_DISTANCE;
}

// Checks if a player is close enough to the *enemy* team's goal to count as a blocker.
// For fun.
bool AtEnemyGoal(int client) {
  int team = GetClientTeam(client);
  float position[3];
  GetClientAbsOrigin(client, position);

  if (team == view_as<int>(TFTeam_Blue)) {
    float distance = GetVectorDistance(position, fRedGoalPos, false);
    if (distance < 100) return true;
  }

  if (team == view_as<int>(TFTeam_Red)) {
    float distance = GetVectorDistance(position, fBluGoalPos, false);
    if (distance < 100) return true;
  }
  return false;
}

void EOOnCatapult(const char[] output, int caller, int activator, float delay) {
  char catapultName[15];
  GetEntPropString(caller, Prop_Data, "m_iName", catapultName, sizeof(catapultName));
  if (!(
        StrEqual(catapultName, "red_catapult1") ||
        StrEqual(catapultName, "red_catapult2") ||
        StrEqual(catapultName, "blu_catapult1") ||
        StrEqual(catapultName, "blu_catapult2"))) return;

  int logic = GetOrFindPasstimeLogic();
  if (logic == INVALID_ENT_REFERENCE) return;

  int jack = GetBall(logic);
  if (jack == INVALID_ENT_REFERENCE) return;

  // must be the ball entity getting catapulted
  if (activator != jack) return;

  // sanity check: we should NOT have a carrier if being catapulted.
  int carrier = GetBallCarrier(jack);
  if (carrier != INVALID_ENT_REFERENCE) return;

  int prevCarrier = GetBallPrevCarrier(jack);
  if (prevCarrier != INVALID_ENT_REFERENCE) {
    LogCatapultEvent(catapultName, prevCarrier);
    TagChatSTV("%N triggered \"%s\" with the jack. t%d", prevCarrier, catapultName, STVTickCount());
  }
}

// outputString must be of size MAX_NAME_LENGTH + 7 or greater.
void FormatPlayerNameWithTeam(int player, char[] outputString) {
  char playerName[MAX_NAME_LENGTH];
  GetClientName(player, playerName, sizeof(playerName));
  if (TF2_GetClientTeam(player) == TFTeam_Blue) {
    Format(outputString, MAX_NAME_LENGTH + 7, "{teamblu}%s{chat}", playerName);
  }
  else {
    Format(outputString, MAX_NAME_LENGTH + 7, "{teamred}%s{chat}", playerName);
  }
}

// Utility function
stock void VerboseLog(const char[] format, any...) {
  if (bVerboseLogs.BoolValue) {
    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 2);
    LogMessage("[VERBOSE] %s", buffer);
  }
}

bool PointInRespawnRoom(int client, float origin[3], bool sameTeamOnly) {
  return SDKCall(pointInRespawnRoom, client, origin, sameTeamOnly);
}

void ForceRegenerateAndRespawn(int client) {
  SDKCall(tfPlayerForceRegenerateAndRespawn, client);
}
