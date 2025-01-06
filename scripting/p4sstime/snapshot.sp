Action Command_GamestateSnapshot(int client, int args)
{
  char   team[4];
  TFTeam ballTeam = GetBallTeam();
  team            = TFTeamToString(ballTeam);
  ReplyToCommand(client, "[PASS] Ball team: %s (%d)", team, ballTeam);
  return Plugin_Handled;
}