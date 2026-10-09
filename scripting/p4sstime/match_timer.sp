// Match timer: mercy score limit and overtime takeover of the round timer on pass_ maps.
// Ported from passtime_match_timer 1.0.4 (league.passtime.tf).

#define MATCH_BALL_DELAY          0.5
#define MATCH_WAIT_INTERVAL       0.5
#define MATCH_WAIT_MAX_TICKS      120
#define MATCH_POLL_INTERVAL       0.2
#define MATCH_RESPAWN_TIMER_PAD   5
#define MATCH_UNSET_SCORE         -1

bool    g_bMatchGamemode;                 // map is a pass_ map
int     g_iMatchTimerRef = INVALID_ENT_REFERENCE;
int     g_iMatchScoreLimitOriginal = MATCH_UNSET_SCORE;
bool    g_bMatchOvertime;
bool    g_bMatchArmed;
int     g_iMatchLastScoreRed = MATCH_UNSET_SCORE;
int     g_iMatchLastScoreBlu = MATCH_UNSET_SCORE;
int     g_iMatchWaitTicks;
float   g_fMatchBallRespawnAt;
float   g_fMatchLastGoalTime;
Handle  g_hMatchDelayStart;
Handle  g_hMatchPoll;

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
  HCC(cvMatchRestartGame, Hook_OnMatchRestartGame);
  HE("teamplay_round_start",   EMatchRoundStart);
  HE("teamplay_restart_round", EMatchRoundStart);
  HE("teamplay_round_win",     EMatchRoundWin);
  AddCommandListener(OnMatchExec, "exec");
}

void MatchTimerMapStart() {
  g_hMatchDelayStart = null;
  g_hMatchPoll = null;
  g_iMatchTimerRef = INVALID_ENT_REFERENCE;
  g_iMatchScoreLimitOriginal = MATCH_UNSET_SCORE;
  ClearRoundState();

  char mapname[64];
  GetCurrentMap(mapname, sizeof(mapname));
  g_bMatchGamemode = (StrContains(mapname, "pass_", true) == 0);
}

void MatchTimerSpawnPost(int entity) {
  g_iMatchTimerRef = EntIndexToEntRef(entity);
}

void MatchTimerGameFrame() {
  if (!g_bMatchArmed || g_bMatchOvertime || !HasMatchTimer()) return;

  float remaining = GetTimerRemaining();
  if (remaining <= cvMatchTimerEarlySeconds.FloatValue) EnterOvertime(remaining);
}

// ====================================================================================================
// HOOKS
// ====================================================================================================
void Hook_OnMatchRestartGame(ConVar convar, const char[] oldValue, const char[] newValue) {
  MatchCaptureOriginals();
  if (!IsMatchTimerActive()) return;

  RestoreScoreLimit();
  ResetRoundState();
}

Action EMatchRoundStart(Event event, const char[] name, bool dontBroadcast) {
  if (!IsMatchTimerActive()) return Plugin_Continue;

  MatchCaptureOriginals();
  ResetRoundState();
  g_iMatchWaitTicks = 0;
  RestoreScoreLimit();

  g_hMatchDelayStart = CreateTimer(MATCH_WAIT_INTERVAL, WaitForBall, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
  return Plugin_Continue;
}

Action EMatchRoundWin(Event event, const char[] name, bool dontBroadcast) {
  ResetRoundState();
  return Plugin_Continue;
}

Action OnMatchExec(int client, const char[] command, int argc) {
  g_iMatchScoreLimitOriginal = MATCH_UNSET_SCORE;
  return Plugin_Continue;
}

// ====================================================================================================
// ROUND STATE
// ====================================================================================================
bool IsMatchTimerActive() {
  return g_bMatchGamemode && cvMatchTimerEnabled.BoolValue;
}

void MatchCaptureOriginals() {
  if (g_iMatchScoreLimitOriginal == MATCH_UNSET_SCORE) g_iMatchScoreLimitOriginal = cvMatchScoreLimit.IntValue;
}

void SetScoreLimit(int limit) {
  if (limit != cvMatchScoreLimit.IntValue) cvMatchScoreLimit.SetInt(limit);
}

void RestoreScoreLimit() {
  if (g_iMatchScoreLimitOriginal != MATCH_UNSET_SCORE) SetScoreLimit(g_iMatchScoreLimitOriginal);
}

void ClearRoundState() {
  g_bMatchOvertime = false;
  g_bMatchArmed = false;
  g_fMatchBallRespawnAt = 0.0;
  g_fMatchLastGoalTime = 0.0;
  g_iMatchLastScoreRed = MATCH_UNSET_SCORE;
  g_iMatchLastScoreBlu = MATCH_UNSET_SCORE;
}

void ResetRoundState() {
  delete g_hMatchDelayStart;
  delete g_hMatchPoll;
  ClearRoundState();
}

Action WaitForBall(Handle timer) {
  if (FindEntityByClassname(-1, "passtime_ball") == INVALID_ENT_REFERENCE) {
    g_iMatchWaitTicks++;
    if (g_iMatchWaitTicks >= MATCH_WAIT_MAX_TICKS) {
      VerboseLog("Match timer gave up waiting for the ball to spawn.");
      g_hMatchDelayStart = null;
      return Plugin_Stop;
    }
    return Plugin_Continue;
  }

  if (HasMatchTimer()) {
    MatchTimerInput("Enable");
    if (cvMatchTimerRoundtime.IntValue >= 0) {
      SetVariantInt(cvMatchTimerRoundtime.IntValue);
      MatchTimerInput("SetMaxTime");
      MatchTimerInput("RestartTimer");
    }
  }

  VerboseLog("Match timer running.");

  g_hMatchDelayStart = null;
  g_bMatchArmed = true;
  g_hMatchPoll = CreateTimer(MATCH_POLL_INTERVAL, PollTick, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
  return Plugin_Stop;
}

Action PollTick(Handle timer) {
  if (g_bMatchOvertime) OvertimeTick();
  else CheckScoreChange();
  return Plugin_Continue;
}

// ====================================================================================================
// OVERTIME
// ====================================================================================================
void OvertimeTick() {
  int scoreRed, scoreBlu;
  GetMatchScores(scoreRed, scoreBlu);
  if (scoreRed != g_iMatchLastScoreRed || scoreBlu != g_iMatchLastScoreBlu) {
    g_iMatchLastScoreRed = scoreRed;
    g_iMatchLastScoreBlu = scoreBlu;
    ScheduleBallRespawn();
  }

  if (g_fMatchBallRespawnAt == 0.0 || GetGameTime() < g_fMatchBallRespawnAt) return;
  g_fMatchBallRespawnAt = 0.0;
  ForceBallRespawn();
}

void EnterOvertime(float remaining) {
  g_bMatchOvertime = true;
  VerboseLog("Match timer overtime: took over the timer at %.2fs remaining (threshold %.2f, paused %d).",
    remaining, cvMatchTimerEarlySeconds.FloatValue, GetEntProp(GetMatchTimer(), Prop_Send, "m_bTimerPaused"));
  MatchTimerInput("Disable");
  EmitGameSoundToAll("Game.Overtime");

  int scoreRed, scoreBlu;
  GetMatchScores(scoreRed, scoreBlu);
  NoteGoal(scoreRed, scoreBlu);
  ApplyMercyLimit(scoreRed, scoreBlu);

  if (g_fMatchBallRespawnAt == 0.0 && g_fMatchLastGoalTime > 0.0) {
    int logic = GetOrFindPasstimeLogic();
    if (logic != INVALID_ENT_REFERENCE && GetGameTime() - g_fMatchLastGoalTime < float(GetBallSpawnCountdown(logic)))
      ScheduleBallRespawn();
  }
}

// ====================================================================================================
// SCORING
// ====================================================================================================
void CheckScoreChange() {
  int scoreRed, scoreBlu;
  GetMatchScores(scoreRed, scoreBlu);
  if (scoreRed == g_iMatchLastScoreRed && scoreBlu == g_iMatchLastScoreBlu) return;

  bool goal = (g_iMatchLastScoreRed != MATCH_UNSET_SCORE || g_iMatchLastScoreBlu != MATCH_UNSET_SCORE);
  NoteGoal(scoreRed, scoreBlu);
  ApplyMercyLimit(scoreRed, scoreBlu);

  if (!goal || g_fMatchBallRespawnAt != 0.0) return;
  int logic = GetOrFindPasstimeLogic();
  if (logic == INVALID_ENT_REFERENCE) return;
  if (GetTimerRemaining() > float(GetBallSpawnCountdown(logic))) return;

  ScheduleBallRespawn();
}

void NoteGoal(int scoreRed, int scoreBlu) {
  if (g_iMatchLastScoreRed == MATCH_UNSET_SCORE && g_iMatchLastScoreBlu == MATCH_UNSET_SCORE) return;
  if (scoreRed == g_iMatchLastScoreRed && scoreBlu == g_iMatchLastScoreBlu) return;
  g_fMatchLastGoalTime = GetGameTime();
}

void ApplyMercyLimit(int scoreRed, int scoreBlu) {
  g_iMatchLastScoreRed = scoreRed;
  g_iMatchLastScoreBlu = scoreBlu;

  if (g_bMatchOvertime) {
    SetScoreLimit(max(scoreRed, scoreBlu) + 1);
    return;
  }

  if (cvMatchTimerMercy.IntValue <= 0) {
    RestoreScoreLimit();
    return;
  }
  SetScoreLimit(max(1, min(scoreRed, scoreBlu) + cvMatchTimerMercy.IntValue));
}

int GetTeamCaptures(TFTeam team) {
  int entity = FindTeamEntity(view_as<int>(team));
  if (entity == INVALID_ENT_REFERENCE) return 0;
  return GetEntProp(entity, Prop_Send, "m_nFlagCaptures");
}

void GetMatchScores(int &scoreRed, int &scoreBlu) {
  scoreRed = GetTeamCaptures(TFTeam_Red);
  scoreBlu = GetTeamCaptures(TFTeam_Blue);
}

// ====================================================================================================
// TIMER AND BALL HELPERS
// ====================================================================================================
int GetMatchTimer() {
  return EntRefToEntIndex(g_iMatchTimerRef);
}

bool HasMatchTimer() {
  return GetMatchTimer() != INVALID_ENT_REFERENCE;
}

void MatchTimerInput(const char[] input) {
  int timer = GetMatchTimer();
  if (timer != INVALID_ENT_REFERENCE) AcceptEntityInput(timer, input);
}

void SetMatchTimerSeconds(int seconds) {
  SetVariantInt(seconds);
  MatchTimerInput("SetTime");
}

float GetTimerRemaining() {
  int timer = GetMatchTimer();
  if (timer == INVALID_ENT_REFERENCE) return -1.0;
  if (view_as<bool>(GetEntProp(timer, Prop_Send, "m_bTimerPaused")))
    return GetEntPropFloat(timer, Prop_Send, "m_flTimeRemaining");
  return GetEntPropFloat(timer, Prop_Send, "m_flTimerEndTime") - GetGameTime();
}

int GetBallSpawnCountdown(int logic) {
  if (!HasEntProp(logic, Prop_Data, "m_iBallSpawnCountdownSec")) return 10;
  return GetEntProp(logic, Prop_Data, "m_iBallSpawnCountdownSec");
}

void ScheduleBallRespawn() {
  g_fMatchBallRespawnAt = GetGameTime() + MATCH_BALL_DELAY;
}

void ForceBallRespawn() {
  int logic = GetOrFindPasstimeLogic();
  if (logic == INVALID_ENT_REFERENCE) return;

  bool haveTimer = HasMatchTimer();
  float saved = 0.0;

  if (haveTimer) {
    saved = GetTimerRemaining();
    if (saved < 0.0) saved = 0.0;
    MatchTimerInput("Enable");
    SetMatchTimerSeconds(RoundToCeil(saved) + GetBallSpawnCountdown(logic) + MATCH_RESPAWN_TIMER_PAD);
  }

  AcceptEntityInput(logic, "SpawnBall");

  if (!haveTimer) return;
  if (g_bMatchOvertime) MatchTimerInput("Disable");
  else SetMatchTimerSeconds(RoundToCeil(saved));
}
