Action CSnapshot(int client, int args) {
  char team[4];
  TFTeam ballTeam = GetBallTeam();
  team = TFTeamToString(ballTeam);
  CTagReply(client, "Ball team: %s (%d)", team, ballTeam);
  PH;
}