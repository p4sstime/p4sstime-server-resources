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
  arr_iClientSettings[client].bCountdown = GetCookieBool(client, cookieCountdownCaption);
  arr_iClientSettings[client].bJackHud = GetCookieBool(client, cookieJACKPickupHud);
  arr_iClientSettings[client].bJackChat = GetCookieBool(client, cookieJACKPickupChat);
  arr_iClientSettings[client].bJackSound = GetCookieBool(client, cookieJACKPickupSound);
  arr_iClientSettings[client].iSummary = GetCookieBool(client, cookieSummary);
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
      SetCookieBool(param1, cookieCountdownCaption, arr_iClientSettings[param1].bCountdown);
      ShowPassMenu(param1);
    }
    if (StrEqual(info, "jackpickuphud")) {
      arr_iClientSettings[param1].bJackHud = !arr_iClientSettings[param1].bJackHud;
      SetCookieBool(param1, cookieJACKPickupHud, arr_iClientSettings[param1].bJackHud);
      ShowPassMenu(param1);
    }
    elif (StrEqual(info, "jackpickupchat")) {
      arr_iClientSettings[param1].bJackChat = !arr_iClientSettings[param1].bJackChat;
      SetCookieBool(param1, cookieJACKPickupChat, arr_iClientSettings[param1].bJackChat);
      ShowPassMenu(param1);
    }
    elif (StrEqual(info, "jackpickupsound")) {
      arr_iClientSettings[param1].bJackSound = !arr_iClientSettings[param1].bJackSound;
      SetCookieBool(param1, cookieJACKPickupSound, arr_iClientSettings[param1].bJackSound);
      ShowPassMenu(param1);
    }
    elif (StrEqual(info, "summary")) {
      switch (arr_iClientSettings[param1].iSummary) {
        case 0: arr_iClientSettings[param1].iSummary = 1;
        case 1: arr_iClientSettings[param1].iSummary = 2;
        case 2: arr_iClientSettings[param1].iSummary = 0;
      }
      SetCookieBool(param1, cookieSummary, arr_iClientSettings[param1].iSummary);
      ShowPassMenu(param1);
    }
  }
  return 0;  // just do this to get rid of warning
}