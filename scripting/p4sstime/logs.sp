// This file relates to all logging features and will contain the functions for them
public void LogUploaded(bool success, const char[] logid, const char[] url) {
  if (!success) return;
  moreurl = "https://more.tf/log/";
  StrCat(moreurl, sizeof(moreurl), logid);
  TagChatGlobal("{pfgreen}Type /more or .more to view logs.");
}

void SetLogInfo(int p1, int p2 = 0) {
  user1 = p1;
  GetClientAbsOrigin(p1, user1position);
  GetClientAuthId(p1, AuthId_Steam3, user1steamid, sizeof(user1steamid));
  switch (GetClientTeam(p1)) {
    case 2:  user1team = "Red";
    case 3:  user1team = "Blue";
    default: user1team = "Spectator";
  }
  
  if (p2 == 0) return;

  user2 = p2;
  GetClientAbsOrigin(p2, user2position);
  GetClientAuthId(p2, AuthId_Steam3, user2steamid, sizeof(user2steamid));
  switch (GetClientTeam(p2)) {
    case 2:  user2team = "Red";
    case 3:  user2team = "Blue";
    default: user2team = "Spectator";
  }
}