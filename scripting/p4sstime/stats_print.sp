#if !defined BLU
  #define BLU true
  #define RED false
#endif

static const char sGoals[]      = "{pass_green} goals %d";
static const char sAssists[]    = "{pass_green} assists %d";
static const char sSaves[]      = "{pass_yellow} saves %d";
static const char sIntercepts[] = "{pass_red} intercepts %d";
static const char sSteals[]     = "{pass_orange} steals %d";
static const char sSplashes[]   = "{pass_blue} splashes %d";

static const char sGoalsShort[]      = "{pass_green} GLS %d";
static const char sAssistsShort[]    = "{pass_green} AST %d";
static const char sSavesShort[]      = "{pass_yellow} SAV %d";
static const char sInterceptsShort[] = "{pass_red} INT %d";
static const char sStealsShort[]     = "{pass_orange} STL %d";
static const char sSplashesShort[]   = "{pass_blue} SPL %d";

Action Command_ChatSummary(int client, int args) {
  int value = 0;
  if (GetCmdArgIntEx(1, value)) {
    switch (value) {
      case 0: {
        arrbJackAcqSettings[client].iSummary = 0;
        CTagReply(client, "Round summary: {pass_blue}Off{chat}|{darkgray}Long{chat}|{darkgray}Short{chat}");
      }
      case 1: {
        arrbJackAcqSettings[client].iSummary = 1;
        CTagReply(client, "Round summary: {darkgray}Off{chat}|{pass_blue}Long{chat}|{darkgray}Short{chat}");
      }
      case 2: {
        arrbJackAcqSettings[client].iSummary = 2;
        CTagReply(client, "Round summary: {darkgray}Off{chat}|{darkgray}Long{chat}|{pass_blue}Short{chat}");
      }
    }
    SetCookieBool(client, cookieSummary, arrbJackAcqSettings[client].iSummary);
  }
  else
    CTagReply(client, "Invalid argument, use 0, 1, or 2");
  return Plugin_Handled;
}

Action Timer_ShowMoreTF(Handle timer, any client) {
  if (!IsValidClient(client))
    return Plugin_Stop;

  char   num[3];
  Handle Kv = CreateKeyValues("data");
  IntToString(MOTDPANEL_TYPE_URL, num, sizeof(num));
  KvSetString(Kv, "title", "MoreTF");
  KvSetString(Kv, "type",  num);
  KvSetString(Kv, "msg",   moreurl);
  KvSetNum(Kv, "customsvr", 1);
  ShowVGUIPanel(client, "info", Kv);
  CloseHandle(Kv);

  return Plugin_Stop;
}

// Clear all plugin stats for the specified client.
void ClearLocalStats(int client) {
  arrbPlyIsDead[client]       = false;
  arrbBlastJumpStatus[client] = false;
  arrbPanaceaCheck[client]    = false;
  arrbWinStratCheck[client]   = false;

  arriPlyRoundPassStats[client].iScores      = 0;
  arriPlyRoundPassStats[client].iAssists     = 0;
  arriPlyRoundPassStats[client].iSaves       = 0;
  arriPlyRoundPassStats[client].iSplashSaves = 0;
  arriPlyRoundPassStats[client].iIntercepts  = 0;
  arriPlyRoundPassStats[client].iSteals      = 0;
  arriPlyRoundPassStats[client].iPanaceas    = 0;
  arriPlyRoundPassStats[client].iWinStrats   = 0;
  arriPlyRoundPassStats[client].iDeathbombs  = 0;
  arriPlyRoundPassStats[client].iHandoffs    = 0;
  arriPlyRoundPassStats[client].iFirstGrabs  = 0;
  arriPlyRoundPassStats[client].iCatapults   = 0;
  arriPlyRoundPassStats[client].iBlocks      = 0;
  arriPlyRoundPassStats[client].iSteal2Saves = 0;
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

    else if (TF2_GetClientTeam(x) == TFTeam_Blue) {
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
    if (arrbJackAcqSettings[x].iSummary) continue;

    LogToGame("Printing for client: %d", x);

    bool isStv               = IsClientSourceTV(x);
    bool shouldPrintBluFirst = (TF2_GetClientTeam(x) == TFTeam_Red);

    // smelly!
    if (arrbJackAcqSettings[x].iSummary == 2) {
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
  
    TagChatClient(x, "{red_team}RED {pass_green}possession: %.1f%%, {blu_team}BLU {pass_green}possession: %.1f%%", redBallPossessionPercent, bluBallPossessionPercent);
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

  return Plugin_Stop;
}

void GetTeamStatsArrStr(char buf[MAXPLAYERS + 1][MAX_MESSAGE_LENGTH], int[] teamMembers, int len, bool isSimple = false) {
  for (int i = 0; i < len; i++) {
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
static const char consoleFormat1[]        = "//   %d goals, %d assists, %d saves, %d intercepts, %d steals                  //";
static const char consoleFormat2[]        = "//   %d Panaceas, %d win strats, %d deathbombs, %d handoffs                   //";
static const char consoleFormat3[]        = "//   %d first grabs, %d catapults, %d blocks, %d steal2saves                  //";
static const char consoleFormat4[]        = "//   %d splash saves                                                       //";

// a player takes up 7 lines
// this is a sad amount of arguments
// three dimensional array structure:
// dimension 1: a player
// dimension 2: their stat strings

void              GetConsoleStatsArrStr(char buf[MAXPLAYERS + 1][7][MAX_MESSAGE_LENGTH], int[] teamMembers, int teamAmount, bool isBlu) {
  for (int i = 0; i < teamAmount; i++) {
    char         playerName[MAX_NAME_LENGTH];
    int          player = teamMembers[i];
    enuiPlyStats stats;
    stats = arriPlyRoundPassStats[player];
    GetClientName(player, playerName, sizeof(playerName));
    Format(buf[i][0], MAX_MESSAGE_LENGTH, consoleFormatBlank);
    if (isBlu) {
      Format(buf[i][1], MAX_MESSAGE_LENGTH, consoleFormatTitleBlu, playerName);
    }
    else {
      Format(buf[i][1], MAX_MESSAGE_LENGTH, consoleFormatTitleRed, playerName);
    }
    Format(buf[i][2], MAX_MESSAGE_LENGTH, consoleFormat1, stats.iScores, stats.iAssists, stats.iSaves, stats.iIntercepts, stats.iSteals);
    Format(buf[i][3], MAX_MESSAGE_LENGTH, consoleFormat2, stats.iPanaceas, stats.iWinStrats, stats.iDeathbombs, stats.iHandoffs);
    Format(buf[i][4], MAX_MESSAGE_LENGTH, consoleFormat3, stats.iFirstGrabs, stats.iCatapults, stats.iBlocks, stats.iSteal2Saves);
    Format(buf[i][5], MAX_MESSAGE_LENGTH, consoleFormat4, stats.iSplashSaves);
    Format(buf[i][6], MAX_MESSAGE_LENGTH, consoleFormatBlank);
  }
}

void CPrintMultiline(int client, char[][] lines, int len) {
  for (int i = 0; i < len; i++) {
    if (!StrEqual(lines[i], "")) {
      CPrintToChat(client, lines[i]);
    }
  }
  return;
}

void Print3DMultilineToConsole(int client, char[][][] lines, int length, int height) {
  for (int i = 0; i < length; i++) {
    for (int j = 0; j < height; j++) {
      if (!StrEqual(lines[i][j], "")) {
        PrintToConsole(client, lines[i][j]);
      }
    }
  }
}

/**
 * @param simplified whether to use the simplified 3 letter abbreviations (true) or long names (false)
 */
static void
  AssembleColoredStatsString(char[] buf, int maxLength, int client, bool simplified = false) {
  VerboseLog("Assembling stats for client: %d", client);
  char sGoals[48];
  char sAssists[48];
  char sSaves[48];
  char sIntercepts[48];
  char sSteals[48];
  char sSplashes[48];
  if (simplified) {
    Format(sGoals,      sizeof(sGoals),      sGoalsShort,      arriPlyRoundPassStats[client].iScores);
    Format(sAssists,    sizeof(sAssists),    sAssistsShort,    arriPlyRoundPassStats[client].iAssists);
    Format(sSaves,      sizeof(sSaves),      sSavesShort,      arriPlyRoundPassStats[client].iSaves);
    Format(sIntercepts, sizeof(sIntercepts), sInterceptsShort, arriPlyRoundPassStats[client].iIntercepts);
    Format(sSteals,     sizeof(sSteals),     sStealsShort,     arriPlyRoundPassStats[client].iSteals);
    Format(sSplashes,   sizeof(sSplashes),   sSplashesShort,   arriPlyRoundPassStats[client].iSplashSaves);
  }
  else {
    Format(sGoals,      sizeof(sGoals),      sGoals,        arriPlyRoundPassStats[client].iScores);
    Format(sAssists,    sizeof(sAssists),    sAssists,      arriPlyRoundPassStats[client].iAssists);
    Format(sSaves,      sizeof(sSaves),      sSaves,        arriPlyRoundPassStats[client].iSaves);
    Format(sIntercepts, sizeof(sIntercepts), sIntercepts,   arriPlyRoundPassStats[client].iIntercepts);
    Format(sSteals,     sizeof(sSteals),     sSteals,       arriPlyRoundPassStats[client].iSteals);
    Format(sSplashes,   sizeof(sSplashes),   sSplashes,     arriPlyRoundPassStats[client].iSplashSaves);
  }

  Format(buf, maxLength, "%s,%s,%s,%s,%s,%s", sGoals, sAssists, sSaves, sIntercepts, sSteals, sSplashes);
}
