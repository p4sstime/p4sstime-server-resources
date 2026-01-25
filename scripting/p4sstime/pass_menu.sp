// This file relates to all menu features for player-specific settings and will contain the functions for them
bool GetCookieBool(int client, Ck cookie) {
  c value[11];
  cookie.Get(client, value, sizeof(value));

  if (!value[0])
    return false;

  // if it's not empty, it's true unless explicitly "0"
  return !StrEqual(value, "0");
}

v SetCookieBool(int client, Ck cookie, bool state) {
  if (AreClientCookiesCached(client)) {
    c value[11];
    FormatEx(value, sizeof(value), "%d", state);
    cookie.Set(client, value);
  }
}

pub OnClientCookiesCached(int client) {
  arrbClientSettings[client].bCountdown = GetCookieBool(client, cookieCountdownCaption);
  arrbClientSettings[client].bJackHud = GetCookieBool(client, cookieJACKPickupHud);
  arrbClientSettings[client].bJackChat = GetCookieBool(client, cookieJACKPickupChat);
  arrbClientSettings[client].bJackSound = GetCookieBool(client, cookieJACKPickupSound);
  arrbClientSettings[client].iSummary = GetCookieBool(client, cookieSummary);
}

Action CMenu(int client, int args) {
  if (IsValidClient(client))
    ShowPassMenu(client);
  PH;
}

v ShowPassMenu(int client) {
  mPassMenu = new Menu(PassMenuHandler);
  mPassMenu.SetTitle("P4SS Menu");

  c buffer[2048];

  FormatEx(buffer, sizeof(buffer), "%s: %s", "JACK spawn timer captions", arrbClientSettings[client].bCountdown ? "ON" : "OFF");
  mPassMenu.AddItem("countdowncaption", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "JACK pickup HUD text", arrbClientSettings[client].bJackHud ? "ON" : "OFF");
  mPassMenu.AddItem("jackpickuphud", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "JACK pickup chat text", arrbClientSettings[client].bJackChat ? "ON" : "OFF");
  mPassMenu.AddItem("jackpickupchat", buffer);
  FormatEx(buffer, sizeof(buffer), "%s: %s", "JACK pickup sound", arrbClientSettings[client].bJackSound ? "ON" : "OFF");
  mPassMenu.AddItem("jackpickupsound", buffer);
  switch (arrbClientSettings[client].iSummary) {
    case 0: FormatEx(buffer, sizeof(buffer), "%s: %s", "Toggle chat round summary", "OFF");
    case 1: FormatEx(buffer, sizeof(buffer), "%s: %s", "Toggle chat round summary", "LONG");
    case 2: FormatEx(buffer, sizeof(buffer), "%s: %s", "Toggle chat round summary", "SHORT");
  }
  mPassMenu.AddItem("summary", buffer);

  mPassMenu.Display(client, MENU_TIME_FOREVER);
}

int PassMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    c info[32], display[255];
    mPassMenu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));
    if (StrEqual(info, "countdowncaption")) {
      arrbClientSettings[param1].bCountdown = !arrbClientSettings[param1].bCountdown;
      SetCookieBool(param1, cookieCountdownCaption, arrbClientSettings[param1].bCountdown);
      ShowPassMenu(param1);
    }
    if (StrEqual(info, "jackpickuphud")) {
      arrbClientSettings[param1].bJackHud = !arrbClientSettings[param1].bJackHud;
      SetCookieBool(param1, cookieJACKPickupHud, arrbClientSettings[param1].bJackHud);
      ShowPassMenu(param1);
    }
    elif (StrEqual(info, "jackpickupchat")) {
      arrbClientSettings[param1].bJackChat = !arrbClientSettings[param1].bJackChat;
      SetCookieBool(param1, cookieJACKPickupChat, arrbClientSettings[param1].bJackChat);
      ShowPassMenu(param1);
    }
    elif (StrEqual(info, "jackpickupsound")) {
      arrbClientSettings[param1].bJackSound = !arrbClientSettings[param1].bJackSound;
      SetCookieBool(param1, cookieJACKPickupSound, arrbClientSettings[param1].bJackSound);
      ShowPassMenu(param1);
    }
    elif (StrEqual(info, "summary")) {
      switch (arrbClientSettings[param1].iSummary) {
        case 0: arrbClientSettings[param1].iSummary = 1;
        case 1: arrbClientSettings[param1].iSummary = 2;
        case 2: arrbClientSettings[param1].iSummary = 0;
      }
      SetCookieBool(param1, cookieSummary, arrbClientSettings[param1].iSummary);
      ShowPassMenu(param1);
    }
  }
  return 0;  // just do this to get rid of warning
}