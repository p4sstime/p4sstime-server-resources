// This file relates to all convars and will contain the functions for them

// Macro for creating bool settings handlers
#define CREATE_BOOL_SETTING(%1,%2,%3,%4)\
Action %1(int client, int args) {\
  bool value;\
  if (GetCmdArgIntEx(1, value)) {\
    arrbClientSettings[client].%2 = value;\
    SetCookieBool(client, %3, arrbClientSettings[client].%2);\
    CTagReply(client, "%4: %%s", arrbClientSettings[client].%2 ? "ON" : "OFF");\
  } else CTagReply(client, "Invalid argument, use either 1 or 0");\
  PH;\
}

Action EPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  arrbPlyIsDead[client] = false;
  RemoveStocks(client);
  if (TF2_GetPlayerClass(client) == TFClass_DemoMan) { QueryClientConVar(client, "m_filter", FilterCheck, false); }

  PH;
}

Action OnChangeClass(int client, const char[] strCommand, int args) {
  // class limits; demo = 1, med = 1, soldier = 3
  // essentially we just check every time someone changes class if the class change is possible. i dont like doing it this way but alternative is dhooks :vomit:
  char sChosenClass[12];
  bool demo = false;
  bool med = false;
  int solly = 0;
  GetCmdArg(1, sChosenClass, sizeof(sChosenClass));
  TFClassType class = TF2_GetClass(sChosenClass);
  tcurrentTeam = TF2_GetClientTeam(client);
  for (int x = 1; x < MaxClients + 1; x++) {
    if (!IsValidClient(x)) continue;
    if (TF2_GetClientTeam(x) == currentTeam) {
      TFClassType classcheck = TF2_GetPlayerClass(x);
      if (classcheck == TFClass_Soldier) solly++;
      elif (classcheck == TFClass_DemoMan) demo = true;
      elif (classcheck == TFClass_Medic) med = true;
    }
  }
  if (arrbPlyIsDead[client] == true && bFixRespawnBypass.BoolValue) {
    if (class == TFClass_Medic && med) PH;
    elif (class == TFClass_DemoMan && demo) PH;
    elif (class == TFClass_Soldier && solly > 2) PH;
    if (class != TFClass_Unknown && class != TFClass_Pyro && class != TFClass_Heavy && class != TFClass_Engineer && class != TFClass_Spy && class != TFClass_Sniper && class != TFClass_Scout) {
      SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", class);
      PrintCenterText(client, "Class when spawned will be %s.", sChosenClass);
    }
    PH;
  }
  PC;
}

pub v TF2_OnConditionAdded(int client, TFCond condition) {
  if (condition == TFCond_PasstimeInterception && !bFixBlur.BoolValue) {
    ClientCommand(client, "r_screenoverlay \"\"");
  }
  if (condition == TFCond_Charging && TF2_GetPlayerClass(client) == TFClass_DemoMan) {
    CreateTimer(0.1, MultiCheck, client);
  }
}

Action EPlayerResup(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  RemoveStocks(client);

  PH;
}

Action CSuicide(int client, int args) {
  if (bRoundActive) {
    ForcePlayerSuicide(client);
    CTagReply(client, "Committed suicide");
  }
  else {
    CTagReply(client, "Round is not active");
  }
  PH;
}

CREATE_BOOL_SETTING(CChatCountdown,  bCountdown,cookieCountdownCaption,"JACK spawn timer captions")
CREATE_BOOL_SETTING(CJackPickupHud,  bJackHud,  cookieJACKPickupHud,   "JACK pickup HUD text")
CREATE_BOOL_SETTING(CJackPickupChat, bJackChat, cookieJACKPickupChat,  "JACK pickup chat text")
CREATE_BOOL_SETTING(CJackPickupSound,bJackSound,cookieJACKPickupSound, "JACK pickup sound")

v Hook_OnAllowInstantResupplyChange(ConVar convar, const char[] oldValue, const char[] newValue) {
  if (!bResupply.BoolValue)
    return;

  if (tfPlayerForceRegenerateAndRespawn == null) {
    LogError("Cannot allow instant resupply due to missing CTFPlayer::ForceRegenerateAndRespawn function");
    bResupply.BoolValue = false;
    return;
  }

  if (pointInRespawnRoom == null) {
    LogError("Cannot allow instant resupply due to missing PointInRespawnRoom function");
    bResupply.BoolValue = false;
    return;
  }
}
Action CResupply(int client, int args) {
  if (!bResupply.BoolValue)
    PH;

  if (nextInstantResupplyTime[client] > GetGameTime())
    PH;

  if (!IsPlayerAlive(client))
    PH;

  float origin[3];
  GetClientAbsOrigin(client, origin);

  if (!PointInRespawnRoom(client, origin, false))
    PH;

  nextInstantResupplyTime[client] = GetGameTime() + flResupplyCooldown.FloatValue;
  ForceRegenerateAndRespawn(client);

  PH;
}

v RemoveStocks(int client) {
  if (bFixStocks.BoolValue) {
    TFClassType class = TF2_GetPlayerClass(client);
    int iWep;
    if (class == TFClass_DemoMan || class == TFClass_Soldier) iWep = GetPlayerWeaponSlot(client, 1);
    elif (class == TFClass_Medic) iWep = GetPlayerWeaponSlot(client, 0);

    if (iWep >= 0) {
      char classname[64];
      GetEntityClassname(iWep, classname, sizeof(classname));

      if (StrEqual(classname, "tf_weapon_shotgun_soldier")) {
        TagChatClient(client, "Shotgun equipped");
        TF2_RemoveWeaponSlot(client, 1);
      }
      
      if (StrEqual(classname, "tf_weapon_pipebomblauncher")) {
        TagChatClient(client, "Stickies equipped");
        TF2_RemoveWeaponSlot(client, 1);
      }

      if (StrEqual(classname, "tf_weapon_syringegun_medic")) {
        TagChatClient(client, "Syringe Gun equipped");
        TF2_RemoveWeaponSlot(client, 0);
      }
    }
  }
}