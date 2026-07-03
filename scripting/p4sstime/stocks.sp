// Color config

char gsTag[32]    = "{plugintag}[PASS]{chat}";
char gsTagSTV[32] = "{plugintag}[PASS-TV]{chat}";

// Cookie helpers
void SetBoolCookie(int client, Cookie cookie, bool value) {
  if (!AreClientCookiesCached(client)) return;
  char sValue[2];
  IntToString(value ? 1 : 0, sValue, sizeof(sValue));
  SetClientCookie(client, cookie, sValue);
}

bool GetBoolCookie(int client, Cookie cookie, bool& value) {
  char sValue[2];
  GetClientCookie(client, cookie, sValue, sizeof(sValue));
  if (strlen(sValue) == 0) return false;
  value = (StringToInt(sValue) != 0);
  return true;
}

void SetIntCookie(int client, Cookie cookie, int value) {
  if (!AreClientCookiesCached(client)) return;
  char sValue[2];
  IntToString(value, sValue, sizeof(sValue));
  SetClientCookie(client, cookie, sValue);
}

bool GetIntCookie(int client, Cookie cookie, int& value) {
  char sValue[2];
  GetClientCookie(client, cookie, sValue, sizeof(sValue));
  if (strlen(sValue) == 0) return false;
  value = StringToInt(sValue);
  return true;
}

public void CTagReply(int client, const char[] format, any ...) {
  char buffer[254];
  VFormat(buffer, sizeof(buffer), format, 3);
  CReplyToCommand(client, "%s %s", gsTag, buffer);
}

public void TagChatGlobal(const char[] format, any ...) {
  char buffer[254];

  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i)) {
      SetGlobalTransTarget(i);
      VFormat(buffer, sizeof(buffer), format, 2);
      CPrintToChat(i, "%s %s", gsTag, buffer);
    }
  }
}

public void TagChatAllPlayers(const char[] format, any ...) {
  char buffer[254];

  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i) && !IsClientSourceTV(i)) {
      SetGlobalTransTarget(i);
      VFormat(buffer, sizeof(buffer), format, 2);
      CPrintToChat(i, "%s %s", gsTag, buffer);
    }
  }
}

public void TagChatClient(int client, const char[] format, any ...) {
  char buffer[254];
  VFormat(buffer, sizeof(buffer), format, 3);
  CPrintToChat(client, "%s %s", gsTag, buffer);
}

public void TagChatSTV(const char[] format, any ...) {
  char buffer[254];
  VFormat(buffer, sizeof(buffer), format, 2);
  CPrintToSTV("%s %s", gsTagSTV, buffer);
}

void TagFormat(char[] buffer, int maxlen, const char[] format, any ...) {
  char msg[254];
  VFormat(msg, sizeof(msg), format, 4);
  Format(buffer, maxlen, "%s %s", gsTag, msg);
}

stock char[] TFTeamToString(TFTeam input) {
  char string[4];
  switch (input) {
    case TFTeam_Blue: {
      string = "BLU";
    }
    case TFTeam_Red: {
      string = "RED";
    }
    case TFTeam_Spectator: {
      string = "SPC";
    }
    case TFTeam_Unassigned: {
      string = "UNA";
    }
  }
  return string;
}

stock float fmin(float x, float y) {
  if (x <= y) return x;
  else return y;
}
stock int min(int x, int y) {
  if (x <= y) return x;
  else return y;
}
stock int GetPlayerMaxHealthTF2(int client) {
  return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
}

void RegAdminCmdWithShort(const char[] name, const char[] shortName, ConCmd handler, int flags, const char[] description) {
  RegAdminCmd(name,      handler, flags, description);
  RegAdminCmd(shortName, handler, flags, description);
}

void RegConsoleCmdWithShort(const char[] name, const char[] shortName, ConCmd handler, const char[] description) {
  RegConsoleCmd(name,      handler, description);
  RegConsoleCmd(shortName, handler, description);
}