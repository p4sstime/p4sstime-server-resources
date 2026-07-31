// This file relates to all logging features and will contain the functions for them
public void LogUploaded(bool success, const char[] logid, const char[] url) {
  if (!success) return;
  moreurl = "https://more.tf/log/";
  StrCat(moreurl, sizeof(moreurl), logid);
  TagChatAll("Type {cScore}/more {chat}or {cScore}.more {chat}to view logs.");
}

void GetTeamNameString(int team, char[] buffer, int maxlen) {
  switch (team) {
    case 2:  strcopy(buffer, maxlen, "Red");
    case 3:  strcopy(buffer, maxlen, "Blue");
    default: strcopy(buffer, maxlen, "Spectator");
  }
}

void SetLogInfo(int p1, int p2 = 0) {
  user1 = p1;
  GetClientAbsOrigin(p1, user1position);
  GetClientAuthId(p1, AuthId_Steam3, user1steamid, sizeof(user1steamid));
  GetTeamNameString(GetClientTeam(p1), user1team, sizeof(user1team));
  
  if (p2 == 0) return;

  user2 = p2;
  GetClientAbsOrigin(p2, user2position);
  GetClientAuthId(p2, AuthId_Steam3, user2steamid, sizeof(user2steamid));
  GetTeamNameString(GetClientTeam(p2), user2team, sizeof(user2team));
}