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
  if (TF2_GetClientTeam(client) == TFTeam_Spectator) ApplySpecFov(client);
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

  char buffer[2048];

  FormatEx(buffer, sizeof(buffer), "%s: %s", "Jack spawn timer captions", arr_iClientPrefs[client].bCountdown ? "ON" : "OFF");
  mPassMenu.AddItem("countdowncaption", buffer);
  mPassMenu.AddItem("pickupcues", "Pickup cues");
  FormatEx(buffer, sizeof(buffer), "%s: %s", "Round stats format",        g_sStatsNames[arr_iClientPrefs[client].iStats]);
  mPassMenu.AddItem("stats", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "Immunity",           arr_iClientPrefs[client].bImmunity ? "ON" : "OFF");
  mPassMenu.AddItem("immunity", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "Infinite ammo",      arr_iClientPrefs[client].bInfAmmo ? "ON" : "OFF");
  mPassMenu.AddItem("infammo", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "Legacy colors",      arr_iClientPrefs[client].bLegacyColors ? "ON" : "OFF");
  mPassMenu.AddItem("legacycolors", buffer);

  if (mPassMenu.ItemCount <= 9) {
    mPassMenu.Pagination = MENU_NO_PAGINATION;
  }
  mPassMenu.ExitButton = true;

  mPassMenu.Display(client, MENU_TIME_FOREVER);
}

#define PREF(%1,%2,%3) \
  if (StrEqual(info, %1)) { \
    arr_iClientPrefs[client].%2 = !arr_iClientPrefs[client].%2; \
    SetBoolCookie(client, %3, arr_iClientPrefs[client].%2); \
    ShowPassMenu(client); \
  }

#define PREF_CALLBACK(%1,%2,%3,%4) \
  if (StrEqual(info, %1)) { \
    arr_iClientPrefs[client].%2 = !arr_iClientPrefs[client].%2; \
    SetBoolCookie(client, %3, arr_iClientPrefs[client].%2); \
    ShowPassMenu(client); \
    %4(client); \
  }

int PassMenuHandler(Menu menu, MenuAction action, int client, int position) {
  if (action == MenuAction_Select) {
    char info[32], display[255];
    mPassMenu.GetItem(position, info, sizeof(info), _, display, sizeof(display));
    PREF("countdowncaption",  bCountdown,    ck_iCountdown)
    PREF_CALLBACK("immunity", bImmunity,     ck_bImmunity, HandleWarmupToggle)
    PREF_CALLBACK("infammo",  bInfAmmo,      ck_bInfAmmo, HandleWarmupToggle)
    PREF("legacycolors",      bLegacyColors, ck_bLegacyColors)
    elif (StrEqual(info, "pickupcues")) {
      ShowPickupMenu(client);
    }
    elif (StrEqual(info, "stats")) {
      ShowStatsMenu(client);
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
  statsMenu.AddItem("", "", ITEMDRAW_SPACER);
  statsMenu.AddItem("back", "Back");

  statsMenu.ExitButton = false;
  statsMenu.Pagination = MENU_NO_PAGINATION;

  statsMenu.Display(client, MENU_TIME_FOREVER);
}

int StatsMenuHandler(Menu menu, MenuAction action, int client, int position) {
  if (action == MenuAction_Select) {
    char info[32];
    menu.GetItem(position, info, sizeof(info));

    if (StrEqual(info, "preview")) {
      ShowStatsPreview(client);
      ShowStatsMenu(client);
    }
    else if (StrEqual(info, "separatelines")) {
      arr_iClientPrefs[client].bStatsSeparateLines = !arr_iClientPrefs[client].bStatsSeparateLines;
      SetBoolCookie(client, ck_bStatsSeparateLines, arr_iClientPrefs[client].bStatsSeparateLines);
      ShowStatsMenu(client);
    }
    else if (StrEqual(info, "back")) {
      ShowPassMenu(client);
    }
    else {
      int value = StringToInt(info);
      arr_iClientPrefs[client].iStats = value;
      SetIntCookie(client, ck_iStats, arr_iClientPrefs[client].iStats);
      ShowStatsMenu(client);
    }
  }
  else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

void ShowPickupMenu(int client) {
  Menu pickupMenu = new Menu(PickupMenuHandler);
  pickupMenu.SetTitle("Pickup cues");

  char display[64];
  FormatEx(display, sizeof(display), "HUD text: %s", arr_iClientPrefs[client].bJackHud ? "ON" : "OFF");
  pickupMenu.AddItem("pickuphud", display);
  FormatEx(display, sizeof(display), "Chat message: %s", arr_iClientPrefs[client].bJackChat ? "ON" : "OFF");
  pickupMenu.AddItem("pickupchat", display);
  FormatEx(display, sizeof(display), "Sound: %s", arr_iClientPrefs[client].bJackSound ? "ON" : "OFF");
  pickupMenu.AddItem("pickupsound", display);

  pickupMenu.AddItem("", "", ITEMDRAW_SPACER);
  pickupMenu.AddItem("back", "Back");

  pickupMenu.ExitButton = false;
  pickupMenu.Pagination = MENU_NO_PAGINATION;

  pickupMenu.Display(client, MENU_TIME_FOREVER);
}

int PickupMenuHandler(Menu menu, MenuAction action, int client, int position) {
  if (action == MenuAction_Select) {
    char info[32];
    menu.GetItem(position, info, sizeof(info));

    if (StrEqual(info, "pickuphud")) {
      arr_iClientPrefs[client].bJackHud = !arr_iClientPrefs[client].bJackHud;
      SetBoolCookie(client, ck_bJackHud, arr_iClientPrefs[client].bJackHud);
      ShowPickupMenu(client);
    }
    elif (StrEqual(info, "pickupchat")) {
      arr_iClientPrefs[client].bJackChat = !arr_iClientPrefs[client].bJackChat;
      SetBoolCookie(client, ck_bJackChat, arr_iClientPrefs[client].bJackChat);
      ShowPickupMenu(client);
    }
    elif (StrEqual(info, "pickupsound")) {
      arr_iClientPrefs[client].bJackSound = !arr_iClientPrefs[client].bJackSound;
      SetBoolCookie(client, ck_bJackSound, arr_iClientPrefs[client].bJackSound);
      ShowPickupMenu(client);
    }
    elif (StrEqual(info, "back")) {
      ShowPassMenu(client);
    }
  }
  else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}

