Action Command_SpawnBall(int client, int args) {
  char name[MAX_NAME_LENGTH];
  VerboseLog("ptspawnball called from client %d", client);
  if (client == 0) name = "CONSOLE";
  else GetClientName(client, name, sizeof(name));

  TagChatAllPlayers("{default}: Spawning the ball for practice...", name);
  TagChatAllPlayers("{pass_yellow}THE GAME IS {red}NOT {pass_yellow}STARTING!");
  TagChatAllPlayers("{pass_yellow}THE GAME IS {red}NOT {pass_yellow}STARTING!");
  TagChatAllPlayers("{pass_yellow}THE GAME IS {red}NOT {pass_yellow}STARTING!");
  bWaitingForBallSpawnToRestart = true;
  ServerCommand("mp_restartgame_immediate 1");
  return Plugin_Handled;
}