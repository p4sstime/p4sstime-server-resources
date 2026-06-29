// Color config

#define COLOR_GOAL "{green}"
#define COLOR_ASSIST "{mintcream}"
#define COLOR_SAVE "{lightyellow}"
#define COLOR_INTERCEPT "{fuchsia}"
#define COLOR_STEAL "{orange}"
#define COLOR_SPLASH "{turquoise}"
#define COLOR_MEDIC_SPLASH "{mintcream}"

char gsTag[32]    = "{plugintag}[PASS]{chat}";
char gsTagSTV[32] = "{plugintag}[PASS-TV]{chat}";

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