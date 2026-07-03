// This file relates to all logging features and will contain the functions for them
public void LogUploaded(bool success, const char[] logid, const char[] url) {
  if (!success) return;
  moreurl = "https://more.tf/log/";
  StrCat(moreurl, sizeof(moreurl), logid);
  TagChatGlobal("Type {cScore}/more {chat}or {cScore}.more {chat}to view logs.");
}

char[] GetTeamNameString(int team) {
  switch (team) {
    case 2:  return "Red";
    case 3:  return "Blue";
    default: return "Spectator";
  }
}

void SetLogInfo(int p1, int p2 = 0) {
  user1 = p1;
  GetClientAbsOrigin(p1, user1position);
  GetClientAuthId(p1, AuthId_Steam3, user1steamid, sizeof(user1steamid));
  user1team = GetTeamNameString(GetClientTeam(p1));
  
  if (p2 == 0) return;

  user2 = p2;
  GetClientAbsOrigin(p2, user2position);
  GetClientAuthId(p2, AuthId_Steam3, user2steamid, sizeof(user2steamid));
  user2team = GetTeamNameString(GetClientTeam(p2));
}