Action CSnapshot(int client, int args) {
  c team[4];
  tballTeam = GetBallTeam();
  team = TFTeamToString(ballTeam);
  CTagReply(client, "Ball team: %s (%d)", team, ballTeam);
  PH;
}