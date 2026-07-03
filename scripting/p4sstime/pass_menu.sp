// This file relates to all menu features for player-specific settings and will contain the functions for them
bool GetCookieBool(int client, Cookie cookie) {
  char value[11];
  cookie.Get(client, value, sizeof(value));

  if (!value[0])
    return false;

  // if it's not empty, it's true unless explicitly "0"
  return !StrEqual(value, "0");
}

void SetCookieBool(int client, Cookie cookie, bool state) {
  if (AreClientCookiesCached(client)) {
    char value[11];
    FormatEx(value, sizeof(value), "%d", state);
    cookie.Set(client, value);
  }
}

public OnClientCookiesCached(int client) {
  arr_iClientPrefs[client].bCountdown = GetCookieBool(client, ck_iCountdown);
  arr_iClientPrefs[client].bJackHud =   GetCookieBool(client, ck_bJackHud);
  arr_iClientPrefs[client].bJackChat =  GetCookieBool(client, ck_bJackChat);
  arr_iClientPrefs[client].bJackSound = GetCookieBool(client, ck_bJackSound);
  GetStatsCookie(client);
  GetAmmoCookie(client);
  GetImmunityCookie(client);
}

void GetStatsCookie(int client) {
  char value[2];
  GetClientCookie(client, ck_iStats, value, sizeof(value));
  if (strlen(value) == 0) return;
  arr_iClientPrefs[client].iStats = StringToInt(value);
}

void SetStatsCookie(int client) {
  if (!AreClientCookiesCached(client)) return;
  char value[2];
  IntToString(arr_iClientPrefs[client].iStats, value, sizeof(value));
  SetClientCookie(client, ck_iStats, value);
}

Action CMenu(int client, int args) {
  if (IsValidClient(client))
    ShowPassMenu(client);
  PH;
}

static const char g_sStatsNames[][] = { "OFF", "LONG", "SHORT", "MINIMAL" };

void ShowPassMenu(int client) {
  mPassMenu = new Menu(PassMenuHandler);
  mPassMenu.SetTitle("P4SS Menu");

  char buffer[2048];

  FormatEx(buffer, sizeof(buffer), "%s: %s", "JACK spawn timer captions", arr_iClientPrefs[client].bCountdown ? "ON" : "OFF");
  mPassMenu.AddItem("countdowncaption", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "JACK pickup HUD text",      arr_iClientPrefs[client].bJackHud ? "ON" : "OFF");
  mPassMenu.AddItem("jackpickuphud", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "JACK pickup chat text",     arr_iClientPrefs[client].bJackChat ? "ON" : "OFF");
  mPassMenu.AddItem("jackpickupchat", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "JACK pickup sound",         arr_iClientPrefs[client].bJackSound ? "ON" : "OFF");
  mPassMenu.AddItem("jackpickupsound", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "Round stats format",      g_sStatsNames[arr_iClientPrefs[client].iStats]);
  mPassMenu.AddItem("stats", buffer);

  mPassMenu.Display(client, MENU_TIME_FOREVER);
}

#define TOGGLE_SETTING(%1,%2,%3) \
  if (StrEqual(info, %1)) { \
    arr_iClientPrefs[param1].%2 = !arr_iClientPrefs[param1].%2; \
    SetCookieBool(param1, %3, arr_iClientPrefs[param1].%2); \
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
    elif (StrEqual(info, "stats")) {
      ShowStatsMenu(param1);
    }
  }
  return 0;  // just do this to get rid of warning
}

void ShowStatsPreview(int client) {
  char preview[256];
  BuildStatsString(preview, sizeof(preview), 3, 1, 2, 4, 0, 1, arr_iClientPrefs[client].iStats - 1);
  CTagReply(client, "Preview: %s", preview);
}

void ShowStatsMenu(int client) {
  Menu statsMenu = new Menu(StatsMenuHandler);
  statsMenu.SetTitle("Round Stats Settings");

  int current = arr_iClientPrefs[client].iStats;
  char key[4];
  char display[32];
  for (int i = 0; i < sizeof(g_sStatsNames); i++) {
    IntToString(i, key, sizeof(key));
    FormatEx(display, sizeof(display), i == current ? "%s <" : "%s", g_sStatsNames[i]);
    statsMenu.AddItem(key, display);
  }

  statsMenu.AddItem("", "", ITEMDRAW_SPACER);
  if (current != 0) {
    statsMenu.AddItem("preview", "Preview Current Format");
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
    else {
      int value = StringToInt(info);
      arr_iClientPrefs[param1].iStats = value;
      SetStatsCookie(param1);
      ShowStatsMenu(param1);
    }
  }
  else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}