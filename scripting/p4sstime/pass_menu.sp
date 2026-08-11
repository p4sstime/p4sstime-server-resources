// This file relates to all menu features for player-specific settings and will contain the functions for them

// Returns cookie, if empty sets default value %3
#define GET_BOOL_COOKIE(%1,%2,%3) \
  if (!GetBoolCookie(client, %1, %2)) %2 = %3;

public OnClientCookiesCached(int client) {
  GET_BOOL_COOKIE(ck_iCountdown, arr_iClientPrefs[client].bCountdown, true)
  GET_BOOL_COOKIE(ck_bJackHud,   arr_iClientPrefs[client].bJackHud,   true)
  GET_BOOL_COOKIE(ck_bJackChat,  arr_iClientPrefs[client].bJackChat,  true)
  GET_BOOL_COOKIE(ck_bJackSound, arr_iClientPrefs[client].bJackSound, true)
  if (!GetIntCookie(client, ck_iStats, arr_iClientPrefs[client].iStats))
    arr_iClientPrefs[client].iStats = 2;
  GET_BOOL_COOKIE(ck_bStatsSeparateLines, arr_iClientPrefs[client].bStatsSeparateLines, false)
  GET_BOOL_COOKIE(ck_bInfAmmo, arr_iClientPrefs[client].bInfAmmo, false)
  GET_BOOL_COOKIE(ck_bImmunity,    arr_iClientPrefs[client].bImmunity,    false)
  GET_BOOL_COOKIE(ck_bLegacyColors, arr_iClientPrefs[client].bLegacyColors, false)
  GET_BOOL_COOKIE(ck_bAirshotLog, arr_iClientPrefs[client].bAirshotLog, false)
  GetSpecFOVCookie(client);
  if (IsClientInGame(client) && TF2_GetClientTeam(client) == TFTeam_Spectator) ApplySpecFov(client);
}

Action CMenu(int client, int args) {
  if (IsValidClient(client))
    ShowPassMenu(client);
  return Plugin_Handled;
}

static const char g_sStatsNames[][] = { "OFF", "LONG", "SHORT", "MINIMAL" };

void ShowPassMenu(int client) {
  mPassMenu = new Menu(PassMenuHandler);
  mPassMenu.SetTitle("P4SS Menu");

  char buffer[256];

  FormatEx(buffer, sizeof(buffer), "%s: %s", "Jack spawn timer captions", arr_iClientPrefs[client].bCountdown ? "ON" : "OFF");
  mPassMenu.AddItem("countdowncaption", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "Jack pickup HUD text",      arr_iClientPrefs[client].bJackHud ? "ON" : "OFF");
  mPassMenu.AddItem("jackpickuphud", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "Jack pickup chat text",     arr_iClientPrefs[client].bJackChat ? "ON" : "OFF");
  mPassMenu.AddItem("jackpickupchat", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "Jack pickup sound",         arr_iClientPrefs[client].bJackSound ? "ON" : "OFF");
  mPassMenu.AddItem("jackpickupsound", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "Round stats format",        g_sStatsNames[arr_iClientPrefs[client].iStats]);
  mPassMenu.AddItem("stats", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "Immunity",           arr_iClientPrefs[client].bImmunity ? "ON" : "OFF");
  mPassMenu.AddItem("immunity", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "Infinite ammo",      arr_iClientPrefs[client].bInfAmmo ? "ON" : "OFF");
  mPassMenu.AddItem("infammo", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "Legacy colors",      arr_iClientPrefs[client].bLegacyColors ? "ON" : "OFF");
  mPassMenu.AddItem("legacycolors", buffer);

  mPassMenu.Display(client, MENU_TIME_FOREVER);
}

#define TOGGLE_SETTING(%1,%2,%3) \
  if (StrEqual(info, %1)) { \
    arr_iClientPrefs[param1].%2 = !arr_iClientPrefs[param1].%2; \
    SetBoolCookie(param1, %3, arr_iClientPrefs[param1].%2); \
    ShowPassMenu(param1); \
  }

int PassMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    char info[32], display[255];
    mPassMenu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
    TOGGLE_SETTING("countdowncaption", bCountdown, ck_iCountdown)
    TOGGLE_SETTING("jackpickuphud",    bJackHud,   ck_bJackHud)
    TOGGLE_SETTING("jackpickupchat",   bJackChat,  ck_bJackChat)
    TOGGLE_SETTING("jackpickupsound",  bJackSound, ck_bJackSound)
    TOGGLE_SETTING("immunity",         bImmunity,  ck_bImmunity)
    TOGGLE_SETTING("infammo",          bInfAmmo,   ck_bInfAmmo)
    TOGGLE_SETTING("legacycolors",     bLegacyColors, ck_bLegacyColors)
    elif (StrEqual(info, "stats")) {
      ShowStatsMenu(param1);
    }
  }
  return 0;  // just do this to get rid of warning
}

void ShowStatsPreview(int client) {
  char playerNameTeamFormatted[MAX_NAME_LENGTH + 7];
  FormatPlayerNameWithTeam(client, playerNameTeamFormatted);
  
  char stats[MAX_MESSAGE_LENGTH];
  BuildStatsString(stats, sizeof(stats), 3, 1, 2, 4, 0, 1, arr_iClientPrefs[client].iStats - 1);
  
  if (arr_iClientPrefs[client].bStatsSeparateLines) {
    char name[MAX_MESSAGE_LENGTH];
    Format(name, sizeof(name), "%s:", playerNameTeamFormatted);
    CTagChat(client, "%s", name);
    CNoTagChat(client, "%s", stats);
  }
  else {
    char combined[MAX_MESSAGE_LENGTH * 2];
    Format(combined, sizeof(combined), "%s: %s", playerNameTeamFormatted, stats);
    CTagChat(client, "%s", combined);
  }
}

void ShowStatsMenu(int client) {
  Menu statsMenu = new Menu(StatsMenuHandler);
  statsMenu.SetTitle("Round stats format");

  int current = arr_iClientPrefs[client].iStats;
  char key[4];
  char display[32];
  for (int i = 0; i < sizeof(g_sStatsNames); i++) {
    IntToString(i, key, sizeof(key));
    FormatEx(display, sizeof(display), i == current ? "%s <" : "%s", g_sStatsNames[i]);
    statsMenu.AddItem(key, display);
  }

  statsMenu.AddItem("", "", ITEMDRAW_SPACER);
  FormatEx(display, sizeof(display), "Separate lines: %s", arr_iClientPrefs[client].bStatsSeparateLines ? "ON" : "OFF");
  statsMenu.AddItem("separatelines", display);
  if (current != 0) {
    statsMenu.AddItem("preview", "Preview");
  }

  statsMenu.Display(client, MENU_TIME_FOREVER);
}

int StatsMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    char info[32];
    menu.GetItem(param2, info, sizeof(info));

    if (StrEqual(info, "preview")) {
      ShowStatsPreview(param1);
      ShowStatsMenu(param1);
    }
    else if (StrEqual(info, "separatelines")) {
      arr_iClientPrefs[param1].bStatsSeparateLines = !arr_iClientPrefs[param1].bStatsSeparateLines;
      SetBoolCookie(param1, ck_bStatsSeparateLines, arr_iClientPrefs[param1].bStatsSeparateLines);
      ShowStatsMenu(param1);
    }
    else {
      int value = StringToInt(info);
      arr_iClientPrefs[param1].iStats = value;
      SetIntCookie(param1, ck_iStats, arr_iClientPrefs[param1].iStats);
      ShowStatsMenu(param1);
    }
  }
  else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}