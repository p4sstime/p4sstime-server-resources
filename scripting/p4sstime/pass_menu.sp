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
  arr_iClientSettings[client].bCountdown = GetCookieBool(client, ck_iCountdown);
  arr_iClientSettings[client].bJackHud =   GetCookieBool(client, ck_bJackHud);
  arr_iClientSettings[client].bJackChat =  GetCookieBool(client, ck_bJackChat);
  arr_iClientSettings[client].bJackSound = GetCookieBool(client, ck_bJackSound);
  GetSummaryCookie(client);
  GetAmmoCookie(client);
  GetImmunityCookie(client);
}

void GetSummaryCookie(int client) {
  char value[2];
  GetClientCookie(client, ck_iSummary, value, sizeof(value));
  if (strlen(value) == 0) return;
  arr_iClientSettings[client].iSummary = StringToInt(value);
}

void SetSummaryCookie(int client) {
  if (!AreClientCookiesCached(client)) return;
  char value[2];
  IntToString(arr_iClientSettings[client].iSummary, value, sizeof(value));
  SetClientCookie(client, ck_iSummary, value);
}

Action CMenu(int client, int args) {
  if (IsValidClient(client))
    ShowPassMenu(client);
  PH;
}

void ShowPassMenu(int client) {
  mPassMenu = new Menu(PassMenuHandler);
  mPassMenu.SetTitle("P4SS Menu");

  char buffer[2048];

  FormatEx(buffer, sizeof(buffer), "%s: %s", "JACK spawn timer captions", arr_iClientSettings[client].bCountdown ? "ON" : "OFF");
  mPassMenu.AddItem("countdowncaption", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "JACK pickup HUD text", arr_iClientSettings[client].bJackHud ? "ON" : "OFF");
  mPassMenu.AddItem("jackpickuphud", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "JACK pickup chat text", arr_iClientSettings[client].bJackChat ? "ON" : "OFF");
  mPassMenu.AddItem("jackpickupchat", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "JACK pickup sound", arr_iClientSettings[client].bJackSound ? "ON" : "OFF");
  mPassMenu.AddItem("jackpickupsound", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "Toggle chat round summary", g_sSummaryNames[arr_iClientSettings[client].iSummary]);
  mPassMenu.AddItem("summary", buffer);

  mPassMenu.Display(client, MENU_TIME_FOREVER);
}

#define TOGGLE_SETTING(%1,%2,%3) \
  if (StrEqual(info, %1)) { \
    arr_iClientSettings[param1].%2 = !arr_iClientSettings[param1].%2; \
    SetCookieBool(param1, %3, arr_iClientSettings[param1].%2); \
    ShowPassMenu(param1); \
  }

int PassMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    char info[32], display[255];
    mPassMenu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
    TOGGLE_SETTING("countdowncaption", bCountdown, ck_iCountdown)
    TOGGLE_SETTING("jackpickuphud", bJackHud, ck_bJackHud)
    TOGGLE_SETTING("jackpickupchat", bJackChat, ck_bJackChat)
    TOGGLE_SETTING("jackpickupsound", bJackSound, ck_bJackSound)
    elif (StrEqual(info, "summary")) {
      ShowSummaryMenu(param1);
    }
  }
  return 0;  // just do this to get rid of warning
}

static const char g_sSummaryNames[][] = { "OFF", "LONG", "SHORT", "MINIMAL" };

void ShowSummaryPreview(int client) {
  char preview[256];
  BuildStatsString(preview, sizeof(preview), 3, 1, 2, 4, 0, 1, arr_iClientSettings[client].iSummary - 1);
  CTagReply(client, "Preview: %s", preview);
}

void ShowSummaryMenu(int client) {
  Menu summaryMenu = new Menu(SummaryMenuHandler);
  summaryMenu.SetTitle("Round Summary Settings");

  int current = arr_iClientSettings[client].iSummary;
  char key[4];
  char display[32];
  for (int i = 0; i < sizeof(g_sSummaryNames); i++) {
    IntToString(i, key, sizeof(key));
    FormatEx(display, sizeof(display), i == current ? "%s <" : "%s", g_sSummaryNames[i]);
    summaryMenu.AddItem(key, display);
  }

  summaryMenu.AddItem("", "", ITEMDRAW_SPACER);
  if (current != 0) {
    summaryMenu.AddItem("preview", "Preview Current Format");
  }

  summaryMenu.Display(client, MENU_TIME_FOREVER);
}

int SummaryMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    char info[32];
    menu.GetItem(param2, info, sizeof(info));

    if (StrEqual(info, "preview")) {
      ShowSummaryPreview(param1);
      ShowSummaryMenu(param1);
    }
    else {
      int value = StringToInt(info);
      arr_iClientSettings[param1].iSummary = value;
      SetSummaryCookie(param1);
      ShowSummaryMenu(param1);
    }
  }
  else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}