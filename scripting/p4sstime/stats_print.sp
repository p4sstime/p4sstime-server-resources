#if !defined BLU
  #define BLU true
  #define RED false
#endif

static int s_iPrintSeq[MAXPLAYERS + 1];

Action Timer_DelayedCPrint(Handle timer, DataPack dp) {
  dp.Reset();
  int client = dp.ReadCell();
  char line[MAX_MESSAGE_LENGTH];
  dp.ReadString(line, sizeof(line));
  if (IsValidClient(client)) CPrintToChat(client, line);
  PS;
}

Action Timer_DelayedConsolePrint(Handle timer, DataPack dp) {
  dp.Reset();
  int client = dp.ReadCell();
  char line[MAX_MESSAGE_LENGTH];
  dp.ReadString(line, sizeof(line));
  if (IsValidClient(client)) PrintToConsole(client, line);
  PS;
}

static const char sGoals[]      = "{cScore} goals %d";
static const char sAssists[]    = "{cAssist} assists %d";
static const char sSaves[]      = "{cBlock} saves %d";
static const char sIntercepts[] = "{cIntercept} intercepts %d";
static const char sSteals[]     = "{cSteal} steals %d";
static const char sSplashes[]   = "{cNeutral} splashes %d";

static const char sGoalsShort[]      = "{cScore} GLS %d";
static const char sAssistsShort[]    = "{cAssist} AST %d";
static const char sSavesShort[]      = "{cBlock} SAV %d";
static const char sInterceptsShort[] = "{cIntercept} INT %d";
static const char sStealsShort[]     = "{cSteal} STL %d";
static const char sSplashesShort[]   = "{cNeutral} SPL %d";

Action CChatSummary(int client, int args) {
  int value = 0;
  if (GetCmdArgIntEx(1, value)) {
    switch (value) {
      case 0: {
        arr_iClientSettings[client].iSummary = 0;
        CTagReply(client, "Round summary: {cRed}Off{chat} I Long I Short");
      }
      case 1: {
        arr_iClientSettings[client].iSummary = 1;
        CTagReply(client, "Round summary: Off I {cBlue}Short{chat} I Long");
      }
      case 2: {
        arr_iClientSettings[client].iSummary = 2;
        CTagReply(client, "Round summary: Off I Long I {cBlue}Short");
      }
    }
    SetCookieBool(client, cookieSummary, arr_iClientSettings[client].iSummary);
  }
  else
    CTagReply(client, "Invalid argument, use 0, 1, or 2");
  PH;
}

Action Timer_ShowMoreTF(Handle timer, any client) {
  if (!IsValidClient(client))
    PS;

  char num[3];
  Handle Kv = CreateKeyValues("data");
  IntToString(MOTDPANEL_TYPE_URL, num, sizeof(num));
  KvSetString(Kv, "title", "MoreTF");
  KvSetString(Kv, "type",  num);
  KvSetString(Kv, "msg",   moreurl);
  KvSetNum(Kv, "customsvr", 1);
  ShowVGUIPanel(client, "info", Kv);
  CloseHandle(Kv);

  PS;
}

// Clear all plugin stats for the specified client.
void ClearLocalStats(int client) {
  arr_bPlyIsDead[client]       = false;
  arr_bBlastJumpStatus[client] = false;
  arr_bPanaceaCheck[client]    = false;
  arr_bWinStratCheck[client]   = false;

  arr_iClientRoundStats[client].iScores =      0;
  arr_iClientRoundStats[client].iAssists =     0;
  arr_iClientRoundStats[client].iSaves =       0;
  arr_iClientRoundStats[client].iSplashes =    0;
  arr_iClientRoundStats[client].iIntercepts =  0;
  arr_iClientRoundStats[client].iSteals =      0;
  arr_iClientRoundStats[client].iPanaceas =    0;
  arr_iClientRoundStats[client].iWinstrats =   0;
  arr_iClientRoundStats[client].iDeathbombs =  0;
  arr_iClientRoundStats[client].iHandoffs =    0;
  arr_iClientRoundStats[client].iFirstGrabs =  0;
  arr_iClientRoundStats[client].iCatapults =   0;
  arr_iClientRoundStats[client].iBlocks =      0;
  arr_iClientRoundStats[client].iSteal2Saves = 0;
}

// this is really fucking sloppy but shrug
Action Timer_DisplayStats(Handle timer) {
  int redTeam[16], bluTeam[16];
  int redAmount, bluAmount = 0;
  // calculate possession time
  int totalPossessionTime = iBluBallTime + iRedBallTime;

#if defined(VERBOSE)
  LogToGame("BluBallTime: %d, RedBallTime: %d, totalPossessionTime = %d", iBluBallTime, iRedBallTime, totalPossessionTime);
#endif
  float bluBallPossessionPercent;
  float redBallPossessionPercent;

  if (iBluBallTime == 0)
    bluBallPossessionPercent = 0.0;
  else
    bluBallPossessionPercent = (float(iBluBallTime) / float(totalPossessionTime));

  if (iRedBallTime == 0)
    redBallPossessionPercent = 0.0;
  else
    redBallPossessionPercent = (float(iRedBallTime) / float(totalPossessionTime));

  // example values:
  // red% = 54.53% (0.5453) 5453
  // blu% = 45.47% (0.4547) 4547
  int redTest = RoundToFloor(redBallPossessionPercent * 10000);
  int bluTest = RoundToFloor(bluBallPossessionPercent * 10000);
  // clean it up for spectators so the value adds up to a clean 100%
  if (redTest + bluTest != 10000) {
    redBallPossessionPercent += 0.0001;
  }

  // for display
  redBallPossessionPercent *= 100;
  bluBallPossessionPercent *= 100;
  for (int x = 1; x < MaxClients + 1; x++) {
    if (!IsValidClient(x)) continue;

    if (TF2_GetClientTeam(x) == TFTeam_Red) {
      redTeam[redAmount] = x;
      redAmount++;
    }

    elif (TF2_GetClientTeam(x) == TFTeam_Blue) {
      bluTeam[bluAmount] = x;
      bluAmount++;
    }
  }
  // thanks rose! -lucy
  char arrStrRedTeamStats[MAXPLAYERS + 1][MAX_MESSAGE_LENGTH];
  char arrStrBluTeamStats[MAXPLAYERS + 1][MAX_MESSAGE_LENGTH];
  char arrStrRedSimpleStats[MAXPLAYERS + 1][MAX_MESSAGE_LENGTH];
  char arrStrBluSimpleStats[MAXPLAYERS + 1][MAX_MESSAGE_LENGTH];

  char arrStrConsoleStatsRed[MAXPLAYERS + 1][7][MAX_MESSAGE_LENGTH];
  char arrStrConsoleStatsBlu[MAXPLAYERS + 1][7][MAX_MESSAGE_LENGTH];

  GetTeamStatsArrStr(arrStrRedTeamStats, redTeam, redAmount);
  GetTeamStatsArrStr(arrStrBluTeamStats, bluTeam, bluAmount);

  GetTeamStatsArrStr(arrStrRedSimpleStats, redTeam, redAmount, true);
  GetTeamStatsArrStr(arrStrBluSimpleStats, bluTeam, bluAmount, true);

  GetConsoleStatsArrStr(arrStrConsoleStatsRed, redTeam, redAmount, RED);
  GetConsoleStatsArrStr(arrStrConsoleStatsBlu, bluTeam, bluAmount, BLU);

  for (int x = 1; x < MaxClients + 1; x++) {
    if (!IsValidClient(x)) continue;
    if (!arr_iClientSettings[x].iSummary) continue;

    LogToGame("Printing for client: %d", x);

    s_iPrintSeq[x] = 0;

    bool isStv = IsClientSourceTV(x);
    bool shouldPrintBluFirst = (TF2_GetClientTeam(x) == TFTeam_Red);

    // smelly!
    if (arr_iClientSettings[x].iSummary == 1) {
      if (shouldPrintBluFirst) {
        CPrintMultiline(x, arrStrBluSimpleStats, sizeof(arrStrBluSimpleStats));
        CPrintMultiline(x, arrStrRedSimpleStats, sizeof(arrStrRedSimpleStats));
      }
      else {
        CPrintMultiline(x, arrStrRedSimpleStats, sizeof(arrStrRedSimpleStats));
        CPrintMultiline(x, arrStrBluSimpleStats, sizeof(arrStrBluSimpleStats));
      }
    }
    else {
      if (shouldPrintBluFirst) {
        CPrintMultiline(x, arrStrBluTeamStats, sizeof(arrStrBluTeamStats));
        CPrintMultiline(x, arrStrRedTeamStats, sizeof(arrStrRedTeamStats));
      }
      else {
        CPrintMultiline(x, arrStrRedTeamStats, sizeof(arrStrRedTeamStats));
        CPrintMultiline(x, arrStrBluTeamStats, sizeof(arrStrBluTeamStats));
      }
    }
  
    TagChatClient(x, "Possession: {teamred}RED %.1f%%{chat}, {teamblu}BLU %.1f%%", redBallPossessionPercent, bluBallPossessionPercent);
    if (isStv) {
      TagChatSTV("BLU possession time in ticks: %d", iRedBallTime);
      TagChatSTV("RED possession time in ticks: %d", iBluBallTime);
    }
    else {
      Print3DMultilineToConsole(x, arrStrConsoleStatsBlu, sizeof(arrStrConsoleStatsBlu), sizeof(arrStrConsoleStatsBlu[]));
      Print3DMultilineToConsole(x, arrStrConsoleStatsRed, sizeof(arrStrConsoleStatsRed), sizeof(arrStrConsoleStatsRed[]));
    }
  }

  for (int i = 0; i < MaxClients + 1; i++)
    ClearLocalStats(i);

  PS;
}

void GetTeamStatsArrStr(char buf[MAXPLAYERS + 1][MAX_MESSAGE_LENGTH], int[] teamMembers, int length, bool isSimple = false) {
  for (int i = 0; i < length; i++) {
    char playerNameTeamFormatted[MAX_NAME_LENGTH + 7];
    FormatPlayerNameWithTeam(teamMembers[i], playerNameTeamFormatted);
    char stats[MAX_MESSAGE_LENGTH];
    AssembleColoredStatsString(stats, sizeof(stats), teamMembers[i], isSimple);
    char out[MAX_MESSAGE_LENGTH];
    Format(out, sizeof(out), "%s %s:%s", gsTag, playerNameTeamFormatted, stats);
    buf[i] = out;
  }
}

// awkward indentation as "%d" takes up two spaces but it ends up being effectively single digit
static const char consoleFormatBlank[]    = "//                                                                        //";
static const char consoleFormatTitleBlu[] = "//   BLU | %s";
static const char consoleFormatTitleRed[] = "//   RED | %s";
static const char consoleFormat1[]        = "//   %d goals, %d assists, %d saves, %d intercepts, %d steals //";
static const char consoleFormat2[]        = "//   %d Panaceas, %d win strats, %d deathbombs, %d handoffs //";
static const char consoleFormat3[]        = "//   %d first grabs, %d catapults, %d blocks, %d steal2saves //";
static const char consoleFormat4[]        = "//   %d splash saves //";

// a player takes up 7 lines
// this is a sad amount of arguments
// three dimensional array structure:
// dimension 1: a player
// dimension 2: their stat strings

void GetConsoleStatsArrStr(char buf[MAXPLAYERS + 1][7][MAX_MESSAGE_LENGTH], int[] teamMembers, int teamAmount, bool isBlu) {
  for (int i = 0; i < teamAmount; i++) {
    char playerName[MAX_NAME_LENGTH];
    int player = teamMembers[i];
    enuClientStats stats;
    stats = arr_iClientRoundStats[player];
    GetClientName(player, playerName, sizeof(playerName));
    Format(buf[i][0], MAX_MESSAGE_LENGTH, consoleFormatBlank);
    if (isBlu) {
      Format(buf[i][1], MAX_MESSAGE_LENGTH, consoleFormatTitleBlu, playerName);
    }
    else {
      Format(buf[i][1], MAX_MESSAGE_LENGTH, consoleFormatTitleRed, playerName);
    }
    Format(buf[i][2], MAX_MESSAGE_LENGTH, consoleFormat1, stats.iScores, stats.iAssists, stats.iSaves, stats.iIntercepts, stats.iSteals);
    Format(buf[i][3], MAX_MESSAGE_LENGTH, consoleFormat2, stats.iPanaceas, stats.iWinstrats, stats.iDeathbombs, stats.iHandoffs);
    Format(buf[i][4], MAX_MESSAGE_LENGTH, consoleFormat3, stats.iFirstGrabs, stats.iCatapults, stats.iBlocks, stats.iSteal2Saves);
    Format(buf[i][5], MAX_MESSAGE_LENGTH, consoleFormat4, stats.iSplashes);
    Format(buf[i][6], MAX_MESSAGE_LENGTH, consoleFormatBlank);
  }
}

void CPrintMultiline(int client, char[][] lines, int len) {
  for (int i = 0; i < len; i++) {
    if (!StrEqual(lines[i], "")) {
      DataPack dp = new DataPack();
      dp.WriteCell(client);
      dp.WriteString(lines[i]);
      CreateTimer(s_iPrintSeq[client]++ * 0.05, Timer_DelayedCPrint, dp, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
    }
  }
}

void Print3DMultilineToConsole(int client, char[][][] lines, int length, int height) {
  for (int i = 0; i < length; i++) {
    for (int j = 0; j < height; j++) {
      if (!StrEqual(lines[i][j], "")) {
        DataPack dp = new DataPack();
        dp.WriteCell(client);
        dp.WriteString(lines[i][j]);
        CreateTimer(s_iPrintSeq[client]++ * 0.05, Timer_DelayedConsolePrint, dp, TIMER_FLAG_NO_MAPCHANGE | TIMER_DATA_HNDL_CLOSE);
      }
    }
  }
}

/**
 * @param simplified whether to use the simplified 3 letter abbreviations (true) or long names (false)
 */
static void AssembleColoredStatsString(char[] buf, int maxLength, int client, bool simplified = false) {
  VerboseLog("Assembling stats for client: %d", client);
  char buffer_sGoals[48];
  char buffer_sAssists[48];
  char buffer_sSaves[48];
  char buffer_sIntercepts[48];
  char buffer_sSteals[48];
  char buffer_sSplashes[48];
  if (simplified) {
    Format(buffer_sGoals,      sizeof(buffer_sGoals),      sGoalsShort,      arr_iClientRoundStats[client].iScores);
    Format(buffer_sAssists,    sizeof(buffer_sAssists),    sAssistsShort,    arr_iClientRoundStats[client].iAssists);
    Format(buffer_sSaves,      sizeof(buffer_sSaves),      sSavesShort,      arr_iClientRoundStats[client].iSaves);
    Format(buffer_sIntercepts, sizeof(buffer_sIntercepts), sInterceptsShort, arr_iClientRoundStats[client].iIntercepts);
    Format(buffer_sSteals,     sizeof(buffer_sSteals),     sStealsShort,     arr_iClientRoundStats[client].iSteals);
    Format(buffer_sSplashes,   sizeof(buffer_sSplashes),   sSplashesShort,   arr_iClientRoundStats[client].iSplashes);
  }
  else {
    Format(buffer_sGoals,      sizeof(buffer_sGoals),      sGoals,           arr_iClientRoundStats[client].iScores);
    Format(buffer_sAssists,    sizeof(buffer_sAssists),    sAssists,         arr_iClientRoundStats[client].iAssists);
    Format(buffer_sSaves,      sizeof(buffer_sSaves),      sSaves,           arr_iClientRoundStats[client].iSaves);
    Format(buffer_sIntercepts, sizeof(buffer_sIntercepts), sIntercepts,      arr_iClientRoundStats[client].iIntercepts);
    Format(buffer_sSteals,     sizeof(buffer_sSteals),     sSteals,          arr_iClientRoundStats[client].iSteals);
    Format(buffer_sSplashes,   sizeof(buffer_sSplashes),   sSplashes,        arr_iClientRoundStats[client].iSplashes);
  }

  Format(buf, maxLength, "%s,%s,%s,%s,%s,%s", buffer_sGoals, buffer_sAssists, buffer_sSaves, buffer_sIntercepts, buffer_sSteals, buffer_sSplashes);
}
