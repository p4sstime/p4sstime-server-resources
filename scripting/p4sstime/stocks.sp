// Color config

char gsTag[32]    = "{plugintag}[PASS]{chat}";
char gsTagSTV[32] = "{plugintag}[PASS-TV]{chat}";

// Cookie helpers
void SetBoolCookie(int client, Cookie cookie, bool value) {
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
  ApplyLegacyColors(buffer, sizeof(buffer), client);
  CReplyToCommand(client, "%s %s", gsTag, buffer);
}

public void TagChatAll(const char[] format, any ...) {
  char buffer[254];

  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i)) {
      SetGlobalTransTarget(i);
      VFormat(buffer, sizeof(buffer), format, 2);
      char clientBuffer[254];
      strcopy(clientBuffer, sizeof(clientBuffer), buffer);
      ApplyLegacyColors(clientBuffer, sizeof(clientBuffer), i);
      CPrintToChat(i, "%s %s", gsTag, clientBuffer);
    }
  }
}

public void CTagChat(int client, const char[] format, any ...) {
  char buffer[254];
  VFormat(buffer, sizeof(buffer), format, 3);
  ApplyLegacyColors(buffer, sizeof(buffer), client);
  CPrintToChat(client, "%s %s", gsTag, buffer);
}

public void CNoTagChat(int client, const char[] format, any ...) {
  char buffer[254];
  VFormat(buffer, sizeof(buffer), format, 3);
  ApplyLegacyColors(buffer, sizeof(buffer), client);
  CPrintToChat(client, "%s", buffer);
}

public void TagChatSTV(const char[] format, any ...) {
  char buffer[254];
  VFormat(buffer, sizeof(buffer), format, 2);
  CPrintToSTV("%s %s", gsTagSTV, buffer);
}

public void ApplyLegacyColors(char[] buffer, int maxLength, int client) {
  if (client > 0 && arr_iClientPrefs[client].bLegacyColors) {
    ReplaceString(buffer, maxLength, "{cRed}",       "{cOldRed}");
    ReplaceString(buffer, maxLength, "{cGreen}",     "{cOldGreen}");
    ReplaceString(buffer, maxLength, "{cBlue}",      "{cOldBlue}");
    ReplaceString(buffer, maxLength, "{cTeal}",      "{cOldCyan}");
    ReplaceString(buffer, maxLength, "{cMagenta}",   "{cOldMagenta}");
    ReplaceString(buffer, maxLength, "{cOrange}",    "{cOldYellow}");
    ReplaceString(buffer, maxLength, "{cYellow}",    "{cOldYellow}");
    ReplaceString(buffer, maxLength, "{cScore}",     "{cOldScore}");
    ReplaceString(buffer, maxLength, "{cAssist}",    "{cOldAssist}");
    ReplaceString(buffer, maxLength, "{cBlock}",     "{cOldDefense}");
    ReplaceString(buffer, maxLength, "{cNeutral}",   "{cOldNeutral}");
    ReplaceString(buffer, maxLength, "{cIntercept}", "{cOldIntercept}");
    ReplaceString(buffer, maxLength, "{cSteal}",     "{cOldSteal}");
  }
}

public void DiffPrintToChatAll(const char[] format, any ...) {
  char buffer[254];
  VFormat(buffer, sizeof(buffer), format, 2);
  
  for (int i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i) && !IsFakeClient(i)) {
      char clientBuffer[254];
      strcopy(clientBuffer, sizeof(clientBuffer), buffer);
      ApplyLegacyColors(clientBuffer, sizeof(clientBuffer), i);
      CPrintToChat(i, "%s %s", gsTag, clientBuffer);
    }
  }
}

public bool IsTeam(int client1, int client2) {
  return GetClientTeam(client1) == GetClientTeam(client2);
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