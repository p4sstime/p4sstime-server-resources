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
  arr_iClientSettings[client].iSummary =   GetCookieBool(client, ck_iSummary);
  GetAmmoCookie(client);
  GetImmunityCookie(client);
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
  switch (arr_iClientSettings[client].iSummary) {
    case 0: FormatEx(buffer, sizeof(buffer), "%s: %s", "Toggle chat round summary", "OFF");
    case 1: FormatEx(buffer, sizeof(buffer), "%s: %s", "Toggle chat round summary", "LONG");
    case 2: FormatEx(buffer, sizeof(buffer), "%s: %s", "Toggle chat round summary", "SHORT");
    case 3: FormatEx(buffer, sizeof(buffer), "%s: %s", "Toggle chat round summary", "MINIMAL");
  }
  mPassMenu.AddItem("summary", buffer);

  mPassMenu.Display(client, MENU_TIME_FOREVER);
}

int PassMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    char info[32], display[255];
    mPassMenu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
    if (StrEqual(info, "countdowncaption")) {
      arr_iClientSettings[param1].bCountdown = !arr_iClientSettings[param1].bCountdown;
      SetCookieBool(param1, ck_iCountdown, arr_iClientSettings[param1].bCountdown);
      ShowPassMenu(param1);
    }
    if (StrEqual(info, "jackpickuphud")) {
      arr_iClientSettings[param1].bJackHud = !arr_iClientSettings[param1].bJackHud;
      SetCookieBool(param1, ck_bJackHud, arr_iClientSettings[param1].bJackHud);
      ShowPassMenu(param1);
    }
    elif (StrEqual(info, "jackpickupchat")) {
      arr_iClientSettings[param1].bJackChat = !arr_iClientSettings[param1].bJackChat;
      SetCookieBool(param1, ck_bJackChat, arr_iClientSettings[param1].bJackChat);
      ShowPassMenu(param1);
    }
    elif (StrEqual(info, "jackpickupsound")) {
      arr_iClientSettings[param1].bJackSound = !arr_iClientSettings[param1].bJackSound;
      SetCookieBool(param1, ck_bJackSound, arr_iClientSettings[param1].bJackSound);
      ShowPassMenu(param1);
    }
    elif (StrEqual(info, "summary")) {
      ShowSummaryMenu(param1);
    }
  }
  return 0;  // just do this to get rid of warning
}

static const char g_sSummaryNames[][] = { "OFF", "LONG", "SHORT", "MINIMAL" };

static const char g_sSummaryStatuses[][] = {
  "Round summary: {cRed}Off {chat}· Long · Short · Minimal",
  "Round summary: Off · {cBlue}Long {chat}· Short · Minimal",
  "Round summary: Off · Long · {cBlue}Short {chat}· Minimal",
  "Round summary: Off · Long · Short · {cBlue}Minimal"
};

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
      CTagReply(param1, g_sSummaryStatuses[value]);
      SetCookieBool(param1, ck_iSummary, arr_iClientSettings[param1].iSummary);
      ShowSummaryMenu(param1);
    }
  }
  else if (action == MenuAction_End) {
    delete menu;
  }
  return 0;
}