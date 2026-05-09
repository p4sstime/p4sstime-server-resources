Action CSpawnBall(int client, int args) {
  char name[MAX_NAME_LENGTH];
  VerboseLog("ptspawnball called from client %d", client);
  if (client == 0) name = "CONSOLE";
  else GetClientName(client, name, sizeof(name));

  TagChatAllPlayers("{default}: Spawning the ball for practice...", name);
  TagChatAllPlayers("{pfyellow}THE GAME IS {red}NOT {pfyellow}STARTING!");
  TagChatAllPlayers("{pfyellow}THE GAME IS {red}NOT {pfyellow}STARTING!");
  TagChatAllPlayers("{pfyellow}THE GAME IS {red}NOT {pfyellow}STARTING!");
  bWaitingForBallSpawnToRestart = true;
  ServerCommand("mp_restartgame_immediate 1");
  PH;
}