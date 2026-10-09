// Match timer: mercy score limit and overtime takeover of the round timer on pass_ maps.
// Ported from passtime_match_timer 1.0.4 (league.passtime.tf).

#define MATCH_BALL_DELAY 0.5

bool      g_bMatchGamemode;             // map is a pass_ map
int       g_iMatchScoreLimitOriginal = -1;
int       g_iMatchActiveTimer = -1;     // team_round_timer entity
bool      g_bMatchOvertime;
int       g_iMatchLastScoreRed = -1;
int       g_iMatchLastScoreBlu = -1;
int       g_iMatchWaitForBallTicks;
float     g_fMatchBallRespawnAt;
float     g_fMatchLastGoalTime;
bool      g_bMatchArmed;
Handle    g_hMatchDelayStart;
Handle    g_hMatchPoll;

ConVar cvMatchRestartGame;
ConVar cvMatchScoreLimit;
ConVar cvMatchTimerEnabled;
ConVar cvMatchTimerMercy;
ConVar cvMatchTimerEarlySeconds;
ConVar cvMatchTimerRoundtime;

// ====================================================================================================
// SETUP
// ====================================================================================================
void MatchTimerInit() {
  cvMatchRestartGame = FindConVar("mp_restartgame");
  cvMatchScoreLimit  = FindConVar("tf_passtime_scores_per_round");
  cvMatchRestartGame.AddChangeHook(Hook_OnMatchRestartGame);
  HE("teamplay_round_start",   EMatchRoundStart);
  HE("teamplay_restart_round", EMatchRoundStart);
  HE("teamplay_round_win",     EMatchRoundWin);
  AddCommandListener(OnMatchExec, "exec");
}

void MatchTimerMapStart() {
  g_hMatchDelayStart = null;
  g_hMatchPoll = null;
  g_iMatchScoreLimitOriginal = -1;
  g_iMatchActiveTimer = -1;
  g_bMatchOvertime = false;
  g_bMatchArmed = false;
  g_fMatchLastGoalTime = 0.0;
  g_iMatchLastScoreRed = -1;
  g_iMatchLastScoreBlu = -1;

  char mapname[64];
  GetCurrentMap(mapname, sizeof(mapname));
  g_bMatchGamemode = (StrContains(mapname, "pass_", true) == 0);
}

void MatchTimerSpawnPost(int entity) {
  g_iMatchActiveTimer = entity;
}

void MatchTimerGameFrame() {
  if (!g_bMatchArmed || g_iMatchActiveTimer == -1 || !IsValidEntity(g_iMatchActiveTimer)) return;
  if (g_bMatchOvertime) return;

  float remaining = GetTimerRemaining();
  if (remaining <= cvMatchTimerEarlySeconds.FloatValue) EnterOvertime(remaining);
}

// ====================================================================================================
// HOOKS
// ====================================================================================================
void Hook_OnMatchRestartGame(ConVar convar, const char[] oldValue, const char[] newValue) {
  MatchCaptureOriginals();

  if (cvMatchScoreLimit.IntValue != g_iMatchScoreLimitOriginal && cvMatchTimerEnabled.BoolValue && g_bMatchGamemode)
    cvMatchScoreLimit.SetInt(g_iMatchScoreLimitOriginal);

  if (g_bMatchGamemode && cvMatchTimerEnabled.BoolValue) MatchResetRoundState();
}

Action EMatchRoundStart(Event event, const char[] name, bool dontBroadcast) {
  if (!g_bMatchGamemode || !cvMatchTimerEnabled.BoolValue) return Plugin_Continue;

  MatchCaptureOriginals();
  MatchResetRoundState();
  g_iMatchWaitForBallTicks = 0;

  if (cvMatchScoreLimit.IntValue != g_iMatchScoreLimitOriginal) cvMatchScoreLimit.SetInt(g_iMatchScoreLimitOriginal);

  g_hMatchDelayStart = CreateTimer(0.5, WaitForBall, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
  return Plugin_Continue;
}

Action EMatchRoundWin(Event event, const char[] name, bool dontBroadcast) {
  MatchResetRoundState();
  return Plugin_Continue;
}

Action OnMatchExec(int client, const char[] command, int argc) {
  g_iMatchScoreLimitOriginal = -1;
  return Plugin_Continue;
}

// ====================================================================================================
// ROUND STATE
// ====================================================================================================
void MatchCaptureOriginals() {
  if (g_iMatchScoreLimitOriginal == -1) g_iMatchScoreLimitOriginal = cvMatchScoreLimit.IntValue;
}

void MatchResetRoundState() {
  delete g_hMatchDelayStart;
  delete g_hMatchPoll;
  g_bMatchOvertime = false;
  g_bMatchArmed = false;
  g_fMatchBallRespawnAt = 0.0;
  g_fMatchLastGoalTime = 0.0;
  g_iMatchLastScoreRed = -1;
  g_iMatchLastScoreBlu = -1;
}

Action WaitForBall(Handle timer) {
  if (FindEntityByClassname(-1, "passtime_ball") == -1) {
    g_iMatchWaitForBallTicks++;
    if (g_iMatchWaitForBallTicks >= 120) {
      PrintToServer("[p4sstime] Match timer gave up waiting for the ball to spawn.");
      g_hMatchDelayStart = null;
      return Plugin_Stop;
    }
    return Plugin_Continue;
  }

  if (g_iMatchActiveTimer != -1 && IsValidEntity(g_iMatchActiveTimer)) {
    AcceptEntityInput(g_iMatchActiveTimer, "Enable");
    if (cvMatchTimerRoundtime.IntValue >= 0) {
      SetVariantInt(cvMatchTimerRoundtime.IntValue);
      AcceptEntityInput(g_iMatchActiveTimer, "SetMaxTime");
      AcceptEntityInput(g_iMatchActiveTimer, "RestartTimer");
    }
  }

  PrintToServer("[p4sstime] Match timer running.");

  g_hMatchDelayStart = null;
  g_bMatchArmed = true;
  g_hMatchPoll = CreateTimer(0.2, PollTick, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
  return Plugin_Stop;
}

Action PollTick(Handle timer) {
  if (!g_bMatchOvertime) CheckScoreChange();
  else OvertimeTick();
  return Plugin_Continue;
}

// ====================================================================================================
// OVERTIME
// ====================================================================================================
void OvertimeTick() {
  int scoreRed = GetPasstimeCaptures(2);
  int scoreBlu = GetPasstimeCaptures(3);
  if (scoreRed != g_iMatchLastScoreRed || scoreBlu != g_iMatchLastScoreBlu) {
    g_iMatchLastScoreRed = scoreRed;
    g_iMatchLastScoreBlu = scoreBlu;
    g_fMatchBallRespawnAt = GetGameTime() + MATCH_BALL_DELAY;
  }

  if (g_fMatchBallRespawnAt == 0.0) return;
  if (GetGameTime() < g_fMatchBallRespawnAt) return;
  g_fMatchBallRespawnAt = 0.0;
  ForceBallRespawn();
}

void EnterOvertime(float remaining) {
  g_bMatchOvertime = true;
  PrintToServer("[p4sstime] Match timer overtime: took over the timer at %.2fs remaining (threshold %.2f, paused %d).",
    remaining, cvMatchTimerEarlySeconds.FloatValue, GetEntProp(g_iMatchActiveTimer, Prop_Send, "m_bTimerPaused"));
  DisableTimer();
  EmitGameSoundToAll("Game.Overtime");
  int scoreRed = GetPasstimeCaptures(2);
  int scoreBlu = GetPasstimeCaptures(3);
  NoteGoal(scoreRed, scoreBlu);
  ApplyMercyLimit(scoreRed, scoreBlu);

  if (g_fMatchBallRespawnAt == 0.0 && g_fMatchLastGoalTime > 0.0) {
    int logic = FindEntityByClassname(-1, "passtime_logic");
    if (logic != -1 && GetGameTime() - g_fMatchLastGoalTime < float(GetBallSpawnCountdown(logic)))
      g_fMatchBallRespawnAt = GetGameTime() + MATCH_BALL_DELAY;
  }
}

void DisableTimer() {
  if (g_iMatchActiveTimer == -1 || !IsValidEntity(g_iMatchActiveTimer)) return;
  AcceptEntityInput(g_iMatchActiveTimer, "Disable");
}

// ====================================================================================================
// SCORING
// ====================================================================================================
void CheckScoreChange() {
  int scoreRed = GetPasstimeCaptures(2);
  int scoreBlu = GetPasstimeCaptures(3);
  if (scoreRed == g_iMatchLastScoreRed && scoreBlu == g_iMatchLastScoreBlu) return;

  bool goal = (g_iMatchLastScoreRed != -1 || g_iMatchLastScoreBlu != -1);
  NoteGoal(scoreRed, scoreBlu);
  ApplyMercyLimit(scoreRed, scoreBlu);

  if (!goal || g_fMatchBallRespawnAt != 0.0) return;
  int logic = FindEntityByClassname(-1, "passtime_logic");
  if (logic == -1) return;
  float remaining = GetTimerRemaining();
  if (remaining > float(GetBallSpawnCountdown(logic))) return;

  g_fMatchBallRespawnAt = GetGameTime() + MATCH_BALL_DELAY;
}

void NoteGoal(int scoreRed, int scoreBlu) {
  if (g_iMatchLastScoreRed == -1 && g_iMatchLastScoreBlu == -1) return;
  if (scoreRed == g_iMatchLastScoreRed && scoreBlu == g_iMatchLastScoreBlu) return;
  g_fMatchLastGoalTime = GetGameTime();
}

void ApplyMercyLimit(int scoreRed, int scoreBlu) {
  g_iMatchLastScoreRed = scoreRed;
  g_iMatchLastScoreBlu = scoreBlu;

  int newLimit;
  if (g_bMatchOvertime) {
    int leading = (scoreRed > scoreBlu) ? scoreRed : scoreBlu;
    newLimit = leading + 1;
  } else {
    if (cvMatchTimerMercy.IntValue <= 0) {
      if (g_iMatchScoreLimitOriginal != -1 && cvMatchScoreLimit.IntValue != g_iMatchScoreLimitOriginal) cvMatchScoreLimit.SetInt(g_iMatchScoreLimitOriginal);
      return;
    }
    int lowest = (scoreRed < scoreBlu) ? scoreRed : scoreBlu;
    newLimit = lowest + cvMatchTimerMercy.IntValue;
  }
  if (newLimit < 1) newLimit = 1;

  if (newLimit != cvMatchScoreLimit.IntValue) cvMatchScoreLimit.SetInt(newLimit);
}

int GetPasstimeCaptures(int team) {
  int ent = GetTeamEntity(team);
  if (ent == -1) return 0;
  return GetEntProp(ent, Prop_Send, "m_nFlagCaptures");
}

// ====================================================================================================
// BALL / TIMER HELPERS
// ====================================================================================================
float GetTimerRemaining() {
  if (g_iMatchActiveTimer == -1 || !IsValidEntity(g_iMatchActiveTimer)) return -1.0;
  if (view_as<bool>(GetEntProp(g_iMatchActiveTimer, Prop_Send, "m_bTimerPaused")))
    return GetEntPropFloat(g_iMatchActiveTimer, Prop_Send, "m_flTimeRemaining");
  return GetEntPropFloat(g_iMatchActiveTimer, Prop_Send, "m_flTimerEndTime") - GetGameTime();
}

int GetBallSpawnCountdown(int logic) {
  if (!HasEntProp(logic, Prop_Data, "m_iBallSpawnCountdownSec")) return 10;
  return GetEntProp(logic, Prop_Data, "m_iBallSpawnCountdownSec");
}

void ForceBallRespawn() {
  int logic = FindEntityByClassname(-1, "passtime_logic");
  if (logic == -1) return;

  bool haveTimer = (g_iMatchActiveTimer != -1 && IsValidEntity(g_iMatchActiveTimer));
  float saved = 0.0;

  if (haveTimer) {
    saved = GetTimerRemaining();
    if (saved < 0.0) saved = 0.0;
    AcceptEntityInput(g_iMatchActiveTimer, "Enable");
    SetVariantInt(RoundToCeil(saved) + GetBallSpawnCountdown(logic) + 5);
    AcceptEntityInput(g_iMatchActiveTimer, "SetTime");
  }

  AcceptEntityInput(logic, "SpawnBall");

  if (!haveTimer) return;
  if (g_bMatchOvertime) {
    AcceptEntityInput(g_iMatchActiveTimer, "Disable");
  } else {
    SetVariantInt(RoundToCeil(saved));
    AcceptEntityInput(g_iMatchActiveTimer, "SetTime");
  }
}
