// This file relates to all convars and will contain the functions for them

// Macro for creating bool settings handlers
#define CREATE_BOOL_SETTING(%1,%2,%3,%4)\
Action %1(int client, int args) {\
  bool value;\
  if (GetCmdArgIntEx(1, value)) {\
    arr_iClientPrefs[client].%2 = value;\
    SetBoolCookie(client, %3, arr_iClientPrefs[client].%2);\
    CTagReply(client, "%4: %%s", arr_iClientPrefs[client].%2 ? "ON" : "OFF");\
  } else CTagReply(client, "Invalid argument, use either 1 or 0");\
  return Plugin_Handled;\
}

Action EPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  arr_bPlyIsDead[client] = false;
  RemoveStocks(client);
  ApplyDemoResistance(client);
  ApplyBootsAttributes(client);
  RestoreFOV(client);
  if (TF2_GetPlayerClass(client) == TFClass_DemoMan) { QueryClientConVar(client, "m_filter", FilterCheck, false); }

  return Plugin_Handled;
}

Action OnChangeClass(int client, const char[] strCommand, int args) {
  // class limits; demo = 1, med = 1, soldier = 3
  // essentially we just check every time someone changes class if the class change is possible. i dont like doing it this way but alternative is dhooks :vomit:
  char    sChosenClass[12];
  bool demo = false;
  bool med = false;
  int  solly = 0;
  GetCmdArg(1, sChosenClass, sizeof(sChosenClass));
  TFClassType class = TF2_GetClass(sChosenClass);
  TFTeam currentTeam = TF2_GetClientTeam(client);
  for (int x = 1; x < MaxClients + 1; x++) {
    if (!IsValidClient(x)) continue;
    if (TF2_GetClientTeam(x) == currentTeam) {
      TFClassType classcheck = TF2_GetPlayerClass(x);
      if (classcheck == TFClass_Soldier) solly++;
      elif (classcheck == TFClass_DemoMan) demo = true;
      elif (classcheck == TFClass_Medic) med = true;
    }
  }
  if (arr_bPlyIsDead[client] == true && bFixRespawnBypass.BoolValue) {
    if (class == TFClass_Medic && med) return Plugin_Handled;
    elif (class == TFClass_DemoMan && demo) return Plugin_Handled;
    elif (class == TFClass_Soldier && solly > 2) return Plugin_Handled;
    if (class != TFClass_Unknown && class != TFClass_Pyro && class != TFClass_Heavy && class != TFClass_Engineer && class != TFClass_Spy && class != TFClass_Sniper && class != TFClass_Scout) {
      SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", class);
      PrintCenterText(client, "Class when spawned will be %s.", sChosenClass);
    }
    return Plugin_Handled;
  }
  return Plugin_Continue;
}

public void TF2_OnConditionAdded(int client, TFCond condition) {
  if (condition == TFCond_PasstimeInterception && bFixBlur.BoolValue) {
    ClientCommand(client, "r_screenoverlay \"\"");
  }
  if (condition == TFCond_Charging && TF2_GetPlayerClass(client) == TFClass_DemoMan) {
    CreateTimer(0.1, MultiCheck, client);
  }
}

Action EPlayerResup(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  RemoveStocks(client);
  ApplyDemoResistance(client);
  ApplyBootsAttributes(client);

  return Plugin_Handled;
}

Action CSuicide(int client, int args) {
  ForcePlayerSuicide(client);
  return Plugin_Handled;
}

CREATE_BOOL_SETTING(CChatCountdown,   bCountdown, ck_iCountdown, "JACK spawn timer captions")
CREATE_BOOL_SETTING(CJackPickupHud,   bJackHud,   ck_bJackHud,   "JACK pickup HUD text")
CREATE_BOOL_SETTING(CJackPickupChat,  bJackChat,  ck_bJackChat,  "JACK pickup chat text")
CREATE_BOOL_SETTING(CJackPickupSound, bJackSound, ck_bJackSound, "JACK pickup sound")

void Hook_OnAllowInstantResupplyChange(ConVar convar, const char[] oldValue, const char[] newValue) {
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

Action CResupDn(int client, int args) {
  if (!bResupply.BoolValue) {
    PrintToConsole(client, "[PASS] +resupply is disabled.");
    return Plugin_Handled;
  }
  if (!IsClientInGame(client)) return Plugin_Handled;

  g_bResupplyDn[client] = true;
  g_bResupplyUp[client] = false;

  BufferedResupply(client);
  return Plugin_Handled;
}

Action CResupUp(int client, int args) {
  if (!IsClientInGame(client)) return Plugin_Handled;
  g_bResupplyDn[client] = false;
  return Plugin_Handled;
}

void BufferedResupply(int client) {
  if (!bResupply.BoolValue) return;
  if (!g_bResupplyDn[client] || g_bResupplyUp[client]) return;
  if (!IsPlayerAlive(client)) return;

  // Check if cooldown is active (blocked input)
  if (nextInstantResupplyTime[client] > 0.0) return;

  float origin[3];
  GetClientAbsOrigin(client, origin);
  if (!PointInRespawnRoom(client, origin, false)) return;

  // SUCCESSFUL input: apply decay-based cooldown
  float maxDecay = fResupplyCooldown.FloatValue;
  float decayAddition = fResupplyDecayAddition.FloatValue;

  // 1. Current decay determines the cooldown applied to this click
  nextInstantResupplyTime[client] = resupplyDecay[client] < maxDecay ? resupplyDecay[client] : maxDecay;

  // 2. Add decay penalty for subsequent presses
  float newDecay = resupplyDecay[client] + decayAddition;
  resupplyDecay[client] = newDecay < maxDecay ? newDecay : maxDecay;

  // Try to use side-aware spawnpoint selection if mirror system is available
  if (AreMirrorSpawnPointsAvailable()) {
    TFTeam clientTeam = TF2_GetClientTeam(client);
    int teamIndex = (clientTeam == TFTeam_Red) ? 0 : 1;

    if (teamIndex == 0 || teamIndex == 1) {
      float playerOrigin[3];
      GetClientAbsOrigin(client, playerOrigin);

      int currentSide = (playerOrigin[0] < g_fMirrorPlaneX) ? 0 : 1;
      int targetSide = (currentSide == 0) ? 1 : 0;

      ArrayList targetSpawns = g_hMirrorSpawnPoints[teamIndex][targetSide];

      if (targetSpawns.Length > 0) {
        int spawnIndex = g_iCurrentSpawnIndex[teamIndex][targetSide];
        int spawnEntity = targetSpawns.Get(spawnIndex);

        g_iCurrentSpawnIndex[teamIndex][targetSide] = (spawnIndex + 1) % targetSpawns.Length;

        if (IsValidEntity(spawnEntity)) {
          float spawnOrigin[3], spawnAngles[3];
          GetEntPropVector(spawnEntity, Prop_Data, "m_vecOrigin", spawnOrigin);
          GetEntPropVector(spawnEntity, Prop_Data, "m_angRotation", spawnAngles);

          TF2_RespawnPlayer(client);
          TeleportEntity(client, spawnOrigin, spawnAngles, {0.0, 0.0, 0.0});
          ApplyBootsAttributes(client);
          g_bResupplyUp[client] = true;
          return;
        }
      }
    }
  }

  // Fallback to default resupply
  ForceRegenerateAndRespawn(client);
  ApplyBootsAttributes(client);
  g_bResupplyUp[client] = true;
}

void RemoveStocks(int client) {
  if (bFixStocks.BoolValue) {
    TFClassType class = TF2_GetPlayerClass(client);
    int iWep;
    if (class == TFClass_DemoMan || class == TFClass_Soldier) iWep = GetPlayerWeaponSlot(client, 1);
    elif (class == TFClass_Medic) iWep = GetPlayerWeaponSlot(client, 0);

    if (iWep >= 0) {
      char classname[64];
      GetEntityClassname(iWep, classname, sizeof(classname));

      static char blockedWeapons[3][32] = {
        "tf_weapon_shotgun_soldier",
        "tf_weapon_pipebomblauncher",
        "tf_weapon_syringegun_medic"
      };
      static char messages[3][32] = {
        "Shotgun equipped",
        "Stickies equipped",
        "Syringe Gun equipped"
      };

      for (int i = 0; i < sizeof(blockedWeapons); i++) {
        if (StrEqual(classname, blockedWeapons[i])) {
          CTagChat(client, messages[i]);
          TF2_RemoveWeaponSlot(client, (class == TFClass_Medic) ? 0 : 1);
          break;
        }
      }
    }
  }
}

bool AreMirrorSpawnPointsAvailable() {
    for (int i = 0; i < 2; i++) {
        int count = 0;
        for (int j = 0; j < 2; j++) {
            int length = g_hMirrorSpawnPoints[i][j].Length;
            count += length;

            for (int k = 0; k < length; k++) {
                // spawn point entity is invalid now. recalc
                if (EntRefToEntIndex(g_hMirrorSpawnPoints[i][j].Get(k)) == INVALID_ENT_REFERENCE)
                    return FindSpawnPointsAndAnalyzeMirror();
            }
        }

        // no left or right spawn points at all. recalc
        if (count == 0) return FindSpawnPointsAndAnalyzeMirror();
    }

    return true;
}

bool FindSpawnPointsAndAnalyzeMirror() {
    ArrayList spawns[2];
    spawns[0] = new ArrayList();
    spawns[1] = new ArrayList();

    int entity = -1;
    while ((entity = FindEntityByClassname(entity, "info_player_teamspawn")) != -1) {
        TFTeam team = view_as<TFTeam>(GetEntProp(entity, Prop_Send, "m_iTeamNum"));
        if (team == TFTeam_Red) {
            spawns[0].Push(entity);
        } else if (team == TFTeam_Blue) {
            spawns[1].Push(entity);
        }
    }

    bool value = AnalyzeMirrorSpawnpoints(spawns);

    delete spawns[1];
    delete spawns[0];

    return value;
}

// Analyze spawnpoints for mirror system - determine left/right split based on coordinates
bool AnalyzeMirrorSpawnpoints(ArrayList spawns[2]) {
  g_hMirrorSpawnPoints[0][0].Clear();
  g_hMirrorSpawnPoints[0][1].Clear();
  g_hMirrorSpawnPoints[1][0].Clear();
  g_hMirrorSpawnPoints[1][1].Clear();

  g_iCurrentSpawnIndex[0][0] = 0;
  g_iCurrentSpawnIndex[0][1] = 0;
  g_iCurrentSpawnIndex[1][0] = 0;
  g_iCurrentSpawnIndex[1][1] = 0;

  int totalSpawns = spawns[0].Length + spawns[1].Length;
  if (totalSpawns < 2) return false;

  float totalX = 0.0, totalY = 0.0;
  int count = 0;

  for (int team = 0; team < 2; team++) {
    int spawnCount = spawns[team].Length;
    for (int j = 0; j < spawnCount; j++) {
      int entity = spawns[team].Get(j);
      float origin[3];
      GetEntPropVector(entity, Prop_Data, "m_vecOrigin", origin);
      totalX += origin[0];
      totalY += origin[1];
      count++;
    }
  }

  g_fMirrorPlaneX = totalX / count;
  g_fMirrorPlaneY = totalY / count;

  for (int team = 0; team < 2; team++) {
    int spawnCount = spawns[team].Length;
    for (int j = 0; j < spawnCount; j++) {
      int entity = spawns[team].Get(j);
      float origin[3];
      GetEntPropVector(entity, Prop_Data, "m_vecOrigin", origin);

      int side = (origin[0] < g_fMirrorPlaneX) ? 0 : 1;
      g_hMirrorSpawnPoints[team][side].Push(entity);
    }
  }

  return true;
}
