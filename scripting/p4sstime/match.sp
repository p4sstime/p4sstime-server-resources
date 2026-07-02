// Match utility commands: force ready, team/class control, dice roll, ready, team name

bool  g_bIsTeamReady[2]     = { false, false };
float g_fUnreadyCooldown[2] = { -1.0, -1.0 };

// ====================================================================================================
// HELPERS
// ====================================================================================================

int ParseTeamIndex(const char[] team) {
  return StrEqual(team, "red") || StrEqual(team, "r")                            ? 0
       : StrEqual(team, "blu") || StrEqual(team, "blue") || StrEqual(team, "b") ? 1
                                                                                : -1;
}

TFTeam ParseTeam(const char[] team) {
  return StrEqual(team, "spectator") || StrEqual(team, "spec") || StrEqual(team, "s") ? TFTeam_Spectator
       : StrEqual(team, "red") || StrEqual(team, "r")                                 ? TFTeam_Red
       : StrEqual(team, "blue") || StrEqual(team, "blu") || StrEqual(team, "b")       ? TFTeam_Blue
                                                                                      : TFTeam_Unassigned;
}

TFClassType ParseClass(const char[] s) {
  if (StrEqual(s, "soldier") || StrEqual(s, "2"))                          return TFClass_Soldier;
  if (StrEqual(s, "demo") || StrEqual(s, "demoman") || StrEqual(s, "4"))  return TFClass_DemoMan;
  if (StrEqual(s, "med")  || StrEqual(s, "medic")   || StrEqual(s, "7"))  return TFClass_Medic;
  return TFClass_Unknown;
}

int FindTeamEntity(int teamNum) {
  int entity = -1;
  while ((entity = FindEntityByClassname(entity, "tf_team")) != -1) {
    if (GetEntProp(entity, Prop_Send, "m_iTeamNum") == teamNum) return entity;
  }
  return -1;
}

void TargetStringAlias(char[] target, int size) {
  if      (StrEqual(target, "@r",          false))                                         strcopy(target, size, "@red");
  elif    (StrEqual(target, "@blu", false) || StrEqual(target, "@b", false))               strcopy(target, size, "@blue");
  elif    (StrEqual(target, "@s",   false) || StrEqual(target, "@spectator", false))       strcopy(target, size, "@spec");
}

// ====================================================================================================
// COMMANDS
// ====================================================================================================

Action CForceReady(int client, int args) {
  if (IsMatch()) PC;
  if (args != 2) {
    ReplyToCommand(client, "[SM] Usage: sm_force_ready <red|blu> <0|1>");
    PH;
  }

  char teamArg[10];
  GetCmdArg(1, teamArg, sizeof(teamArg));
  int teamIndex = ParseTeamIndex(teamArg);
  int status    = GetCmdArgInt(2);

  if (teamIndex == -1) { ReplyToCommand(client, "[SM] Invalid team. Use 'red' or 'blu'."); PH; }
  if (status < 0 || status > 1) { ReplyToCommand(client, "[SM] Invalid status. Use 0 (not ready) or 1 (ready)."); PH; }

  GameRules_SetProp("m_bTeamReady", status, 1, teamIndex + 2);
  g_bIsTeamReady[teamIndex] = (status != 0);

  PH;
}

Action CSetTeam(int client, int args) {
  char targetArg[33], teamArg[5];
  GetCmdArg(1, targetArg, sizeof(targetArg));
  GetCmdArg(2, teamArg,   sizeof(teamArg));
  TFTeam team = ParseTeam(teamArg);

  if (args != 2 || team == TFTeam_Unassigned) {
    ReplyToCommand(client, "[SM] Usage: sm_setteam <#userid|name> <spec|red|blu>");
    PH;
  }

  int  targetList[MAXPLAYERS];
  char targetName[MAX_TARGET_LENGTH];
  bool tnIsMl;
  int  count = ProcessTargetString(targetArg, client, targetList, MAXPLAYERS, COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tnIsMl);
  bool changed = false;

  if (count == COMMAND_TARGET_NONE) PH;

  for (int n = 0; n < count; n++) {
    int t = targetList[n];
    if (!IsValidClient(t) || TF2_GetClientTeam(t) == team) continue;
    changed = true;
    ForcePlayerSuicide(t);
    TF2_ChangeClientTeam(t, team);
    if (team != TFTeam_Spectator) TF2_RespawnPlayer(t);
  }

  if (changed) {
    for (int n = 1; n <= MaxClients; n++)
      GameRules_SetProp("m_bTeamReady", 0, _, n);

    char teamName[5];
    GetTeamName(view_as<int>(team), teamName, sizeof(teamName));
    ReplyToCommand(client, "[SM] Switched %s to %s", targetName, teamName);
  }

  PH;
}

Action CSetClass(int client, int args) {
  if (args != 2) {
    ReplyToCommand(client, "[SM] Usage: sm_setclass <#userid|name> <soldier|demo|medic>");
    PH;
  }

  char classArg[16];
  GetCmdArg(2, classArg, sizeof(classArg));
  TFClassType tfclass = ParseClass(classArg);
  if (tfclass == TFClass_Unknown) {
    ReplyToCommand(client, "[SM] Invalid class. Use soldier, demo, or medic.");
    PH;
  }

  char targetArg[33];
  GetCmdArg(1, targetArg, sizeof(targetArg));

  int  targets[MAXPLAYERS];
  char targetName[MAX_TARGET_LENGTH];
  bool tnIsMl;
  int  count   = ProcessTargetString(targetArg, client, targets, MAXPLAYERS, COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tnIsMl);
  bool changed = false;

  if (count == COMMAND_TARGET_NONE) PH;

  for (int n = 0; n < count; n++) {
    int t = targets[n];
    if (t <= 0 || t > MaxClients || !IsClientInGame(t)) continue;
    if (TF2_GetClientTeam(t) == TFTeam_Spectator) continue;
    TF2_SetPlayerClass(t, tfclass);
    TF2_RespawnPlayer(t);
    ApplyBootsAttributes(t);
    changed = true;
  }

  if (changed) {
    char className[16];
    switch (tfclass) {
      case TFClass_Soldier: strcopy(className, sizeof(className), "Soldier");
      case TFClass_DemoMan: strcopy(className, sizeof(className), "Demoman");
      case TFClass_Medic:   strcopy(className, sizeof(className), "Medic");
      default:              strcopy(className, sizeof(className), "Unknown");
    }
    ReplyToCommand(client, "[SM] Set %s class to %s", targetName, className);
  }

  PH;
}

Action CDice(int client, int args) {
  if (args < 1) {
    TagChatClient(client, "Usage: sm_dice <\"custom\" | #userid | name | @team>");
    PH;
  }

  char customStrings[10][64];
  int  customCount      = 0;
  int  allTargets[MAXPLAYERS];
  int  totalTargetCount = 0;

  char fullCmd[256];
  GetCmdArgString(fullCmd, sizeof(fullCmd));

  char arguments[10][64];
  int  argCount = 0;
  int  pos      = 0;
  int  length   = strlen(fullCmd);

  while (pos < length && argCount < 10) {
    while (pos < length && (fullCmd[pos] == ' ' || fullCmd[pos] == '\t')) pos++;
    if (pos >= length) break;

    int argStart = pos;
    int argLen   = 0;

    if (fullCmd[pos] == '"') {
      pos++;
      argStart = pos;
      while (pos < length && fullCmd[pos] != '"') pos++;
      argLen = (pos < length) ? pos - argStart : length - argStart;
      if (pos < length) pos++;
    } else {
      while (pos < length && fullCmd[pos] != ' ' && fullCmd[pos] != '\t') pos++;
      argLen = pos - argStart;
    }

    if (argLen > 0 && argLen < sizeof(arguments[])) {
      for (int ci = 0; ci < argLen && ci < sizeof(arguments[]) - 1; ci++)
        arguments[argCount][ci] = fullCmd[argStart + ci];
      arguments[argCount][argLen] = '\0';
      argCount++;
    }
  }

  for (int ai = 0; ai < argCount; ai++) {
    char arg[64];
    strcopy(arg, sizeof(arg), arguments[ai]);

    bool isNumeric = true;
    for (int j = 0; j < strlen(arg); j++) {
      if (arg[j] < '0' || arg[j] > '9') { isNumeric = false; break; }
    }

    if (isNumeric || strlen(arg) <= 3) {
      strcopy(customStrings[customCount], sizeof(customStrings[]), arg);
      customCount++;
    } else {
      TargetStringAlias(arg, sizeof(arg));
      int  targets[MAXPLAYERS];
      char targetName[MAX_TARGET_LENGTH];
      bool tnIsMl;
      int  targetCount = ProcessTargetString(arg, client, targets, MAXPLAYERS, COMMAND_FILTER_CONNECTED, targetName, sizeof(targetName), tnIsMl);

      for (int n = 0; n < targetCount && totalTargetCount < MAXPLAYERS; n++) {
        bool already = false;
        for (int ex = 0; ex < totalTargetCount; ex++) {
          if (allTargets[ex] == targets[n]) { already = true; break; }
        }
        if (!already) allTargets[totalTargetCount++] = targets[n];
      }
    }
  }

  if (customCount > 0 && totalTargetCount == 0) {
    PrintToChatAll("Rolled %s", customStrings[GetRandomInt(0, customCount - 1)]);
  } elif (totalTargetCount > 0) {
    int  picked = allTargets[GetRandomInt(0, totalTargetCount - 1)];
    char pickedName[MAX_NAME_LENGTH];
    GetClientName(picked, pickedName, sizeof(pickedName));
    PrintToChatAll("%s was rolled!", pickedName);
  } elif (customCount > 0) {
    PrintToChatAll("Rolled %s", customStrings[GetRandomInt(0, customCount - 1)]);
  } else {
    TagChatClient(client, "No valid targets or options provided.");
  }

  PH;
}

Action CReady(int client, int args) {
  if (IsMatch()) { TagChatClient(client, "Ready command cannot be used during a game."); PH; }
  if (args != 0) { TagChatClient(client, "Usage: sm_ready"); PH; }

  TFTeam clientTeam = TF2_GetClientTeam(client);
  if (clientTeam != TFTeam_Red && clientTeam != TFTeam_Blue) {
    TagChatClient(client, "You must be on RED or BLU to use this command.");
    PH;
  }

  int  teamIndex          = (clientTeam == TFTeam_Red) ? 0 : 1;
  int  gameRulesOffset    = teamIndex + 2;
  bool currentReadyState  = view_as<bool>(GameRules_GetProp("m_bTeamReady", _, gameRulesOffset));
  bool newReadyState      = !currentReadyState;

  if (newReadyState) {
    g_fUnreadyCooldown[teamIndex] = -1.0;
  } else {
    float elapsed = GetGameTime() - g_fUnreadyCooldown[teamIndex];
    if (elapsed < 5.0) {
      TagChatClient(client, "Wait %.0f more second%s before unreadying.", 5.0 - elapsed, (5.0 - elapsed < 2.0) ? "" : "s");
      PH;
    }
    g_fUnreadyCooldown[teamIndex] = GetGameTime();
  }

  GameRules_SetProp("m_bTeamReady", newReadyState ? 1 : 0, 1, gameRulesOffset);
  g_bIsTeamReady[teamIndex] = newReadyState;

  ConVar cvRestart = FindConVar("mp_restartgame");

  if (newReadyState) {
    bool redReady = view_as<bool>(GameRules_GetProp("m_bTeamReady", _, 2));
    bool bluReady = view_as<bool>(GameRules_GetProp("m_bTeamReady", _, 3));
    if (redReady && bluReady) {
      GameRules_SetProp("m_bAwaitingReadyRestart", 0);
      if (cvRestart != null) cvRestart.SetInt(5);
    }
  } else {
    float restartTime = GameRules_GetPropFloat("m_fRestartRoundTime");
    if (restartTime > GetGameTime()) {
      GameRules_SetPropFloat("m_fRestartRoundTime", -1.0);
      GameRules_SetProp("m_bAwaitingReadyRestart", 1);
      if (cvRestart != null) cvRestart.SetInt(0);

      char teamName[4];
      strcopy(teamName, sizeof(teamName), (clientTeam == TFTeam_Red) ? "RED" : "BLU");
    }
  }

  char playerName[MAX_NAME_LENGTH];
  GetClientName(client, playerName, sizeof(playerName));
  switch (clientTeam) {
    case TFTeam_Red:  CPrintToChatAll("{teamred}%s {default}changed team state to {steamlightgreen}%s",  playerName, newReadyState ? "Ready" : "Not Ready");
    case TFTeam_Blue: CPrintToChatAll("{teamblu}%s {default}changed team state to {steamlightgreen}%s", playerName, newReadyState ? "Ready" : "Not Ready");
  }

  PH;
}

Action CTeamName(int client, int args) {
  if (IsMatch()) { TagChatClient(client, "Team rename can only be used during preround."); PH; }
  if (args != 1) { TagChatClient(client, "Usage: sm_team_name <new_name>"); PH; }

  TFTeam clientTeam = TF2_GetClientTeam(client);
  if (clientTeam != TFTeam_Red && clientTeam != TFTeam_Blue) {
    TagChatClient(client, "You must be on RED or BLU to use this command.");
    PH;
  }

  char newName[64];
  GetCmdArg(1, newName, sizeof(newName));

  if (strlen(newName) < 1) { TagChatClient(client, "Team name cannot be empty."); PH; }
  if (strlen(newName) > 5) { TagChatClient(client, "Team name cannot be longer than 5 characters."); PH; }

  int teamEntity = FindTeamEntity(view_as<int>(clientTeam));
  if (teamEntity == -1) { TagChatClient(client, "Could not find team entity."); PH; }

  SetEntPropString(teamEntity, Prop_Data, "m_szTeamname", newName);

  char playerName[MAX_NAME_LENGTH];
  GetClientName(client, playerName, sizeof(playerName));
  switch (clientTeam) {
    case TFTeam_Red:  CPrintToChatAll("{teamred}%s {default}changed team name to {steamlightgreen}%s",  playerName, newName);
    case TFTeam_Blue: CPrintToChatAll("{teamblu}%s {default}changed team name to {steamlightgreen}%s", playerName, newName);
  }

  PH;
}
